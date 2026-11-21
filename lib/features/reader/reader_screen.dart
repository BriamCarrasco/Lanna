// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/comic/comic_archive.dart';
import '../../data/epub/epub_book.dart';
import '../../data/library/book_metadata.dart';
import '../../data/library/folder_access.dart';
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import '../../data/storage/random_source.dart';
import '../../l10n/l10n.dart';
import '../stats/reading_tracker.dart';
import 'comic/comic_engine_view.dart';
import 'epub_view_factory.dart';
import 'native/book_source.dart';
import 'pdf/pdf_engine_view.dart';
import 'reader_engine.dart';
import 'reader_prepare.dart';
import 'reader_settings_provider.dart';
import 'reader_theme.dart';
import 'widgets/appearance_panel.dart';
import 'widgets/page_curl.dart';
import 'widgets/reader_bar_button.dart';
import 'widgets/reader_scrubber.dart';
import 'widgets/reader_transitions.dart';
import 'widgets/search_panel.dart';
import 'widgets/toc_drawer.dart';

@visibleForTesting
const Key readerIncomingKey = ValueKey('reader-incoming');

@visibleForTesting
int foldFor(int logical, {required bool rtl}) => rtl ? -logical : logical;

@visibleForTesting
int turnForTravel(double travel, {required bool rtl}) {
  final forward = rtl ? travel > 0 : travel < 0;
  return forward ? 1 : -1;
}

@visibleForTesting
int turnForEdge({required bool leading, required bool rtl}) =>
    leading == rtl ? 1 : -1;

@visibleForTesting
Offset selectionToolbarOrigin({
  required Rect selection,
  required Size viewport,
  required Size toolbar,
}) {
  final maxLeft = math.max(8.0, viewport.width - toolbar.width - 8);
  final left = (selection.center.dx - toolbar.width / 2).clamp(8.0, maxLeft);
  var top = selection.top - toolbar.height - 10;
  if (top < 60) {
    final maxTop = math.max(60.0, viewport.height - toolbar.height - 50);
    top = (selection.bottom + 10).clamp(60.0, maxTop);
  }
  return Offset(left, top);
}

const _highlightColors = readerHighlightColors;

typedef _EngineBuilder = Widget Function(
  ReaderEngineCallbacks callbacks,
  String? initialLocator,
  double? initialPercent,
);

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _focusNode = FocusNode();

  late final PageCurlController _curl = PageCurlController(
    vsync: this,
    onChange: () {
      if (!mounted) return;
      unawaited(_controller?.setAnimating(_curl.busy) ?? Future.value());
      setState(() {});
    },
  );

  _EngineBuilder? _engine;
  PdfDocument? _pdfDocument;
  ComicArchive? _comicArchive;
  OpenedFile? _openedFile;

  Future<void> _releaseSources() async {
    final document = _pdfDocument;
    final comic = _comicArchive;
    final file = _openedFile;
    _pdfDocument = null;
    _comicArchive = null;
    _openedFile = null;
    try {
      await document?.dispose();
      await comic?.close();
    } finally {
      file?.close();
    }
  }

  ReaderEngineController? _controller;
  Book? _book;
  ReaderLocation? _location;

  List<EpubTocEntry> _toc = const [];
  List<Bookmark> _bookmarks = const [];
  List<Highlight> _highlights = const [];
  ReaderSelection? _selection;
  double _lastPercent = 0;

  ReaderSettings _settings = const ReaderSettings();

  String? _error;
  bool _chromeVisible = true;
  bool _showAppearance = false;
  bool _showToc = false;
  bool _showSearch = false;

  int _pageCount = 0;
  List<SearchHit> _searchHits = const [];
  bool _searchBusy = false;
  String _searchQuery = '';

  Timer? _saveTimer;

  late final ReadingTracker _tracker = ReadingTracker(onSpan: _saveSpan);
  bool _finishMarked = false;

  void _saveSpan(ReadingSpan span) {
    unawaited(
      _repo.addReadingSession(
        bookId: widget.bookId,
        startedAt: span.start,
        seconds: span.seconds,
        startPercent: span.startPercent,
        endPercent: span.endPercent,
        pages: span.pages,
      ),
    );
  }

  ProviderSubscription<AsyncValue<ReaderSettings>>? _settingsSub;
  ProviderSubscription<AsyncValue<List<Bookmark>>>? _bookmarksSub;
  ProviderSubscription<AsyncValue<List<Highlight>>>? _highlightsSub;
  late final BookRepository _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_curl.loadShader());
    _repo = ref.read(bookRepositoryProvider);
    _settings =
        ref.read(readerSettingsProvider).valueOrNull ?? const ReaderSettings();
    _settingsSub = ref.listenManual(readerSettingsProvider, (_, next) {
      final s = next.valueOrNull;
      if (s == null || !mounted) return;
      setState(() => _settings = s);
      _applySettings(s);
    });
    _bookmarks =
        ref.read(bookmarksProvider(widget.bookId)).valueOrNull ?? const [];
    _bookmarksSub = ref.listenManual(bookmarksProvider(widget.bookId), (
      _,
      next,
    ) {
      final list = next.valueOrNull;
      if (list == null || !mounted) return;
      setState(() => _bookmarks = list);
    }, fireImmediately: true);
    _highlights =
        ref.read(highlightsProvider(widget.bookId)).valueOrNull ?? const [];
    _highlightsSub = ref.listenManual(highlightsProvider(widget.bookId), (
      _,
      next,
    ) {
      final list = next.valueOrNull;
      if (list == null || !mounted) return;
      setState(() => _highlights = list);
      _refreshSnapshot();
    }, fireImmediately: true);
    _syncSystemUi();
    unawaited(_open());
  }

  void _syncSystemUi() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgressNow();
      _tracker.pause();
    } else if (state == AppLifecycleState.resumed && _location != null) {
      _tracker.activity();
    }
  }

  void _saveProgressNow() {
    final loc = _location;
    if (loc == null) return;
    _saveTimer?.cancel();
    unawaited(
      _repo.saveProgress(
        bookId: widget.bookId,
        locator: loc.cfi,
        percent: _lastPercent,
        chapterIndex: loc.chapterIndex,
      ),
    );
  }

  Offset? _tapDownPos;
  DateTime? _tapDownAt;

  PageTransition? get _transition =>
      PageTransition.forSetting(_settings.pageAnimation);

  bool get _dragCurlEnabled =>
      _dragCurlReady &&
      (_transition?.tracksDrag ?? false) &&
      !_showToc &&
      !_showAppearance &&
      !_showSearch;

  double _dragProgress = 0;

  bool get _atStart => _location?.atStart ?? false;

  bool get _atEnd => _location?.atEnd ?? false;

  bool _canTurn(int dir) => dir > 0 ? !_atEnd : !_atStart;

  double _dragTravel = 0;

  Future<bool>? _curlStart;

  void _onDragStart(DragStartDetails details) {
    _dragTravel = 0;
    _dragProgress = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragTravel += details.delta.dx;
    if (!_dragCurlEnabled) return;

    final width = MediaQuery.sizeOf(context).width;
    if (!_curl.dragging) {
      if (_curl.busy || _curlStart != null) return;
      if (_dragTravel.abs() < 16) return;
      final controller = _controller;
      if (controller == null) return;
      final forward = _rtl ? _dragTravel > 0 : _dragTravel < 0;
      if (!_canTurn(forward ? 1 : -1)) return;
      final start = _curl.beginDrag(
        _foldFor(forward ? 1 : -1),
        mode: _transition ?? PageTransition.curl,
        outgoing: controller.snapshot,
        advance: () => forward ? controller.next() : controller.previous(),
        revert: () => forward ? controller.previous() : controller.next(),
      );
      _curlStart = start;
      unawaited(start.whenComplete(() => _curlStart = null));
      return;
    }

    final mode = _transition ?? PageTransition.curl;
    final travel = (_dragTravel.abs() - 16).clamp(0.0, double.infinity);
    _dragProgress = (travel / mode.travelSpan(width)).clamp(0.0, 1.0);
    _curl.updateDrag(_dragProgress);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    final pending = _curlStart;
    if (pending != null) await pending;
    if (!mounted) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_curl.dragging) {
      final width = MediaQuery.sizeOf(context).width;
      final mode = _transition ?? PageTransition.curl;
      final span = mode.travelSpan(width);
      _curl.endDrag(
        complete:
            _dragProgress > mode.completion(width) || velocity.abs() > 600,
        velocity: velocity * (_dragTravel.isNegative ? -1 : 1) / span,
      );
      _dragProgress = 0;
      _dragTravel = 0;
      return;
    }
    final travel = _dragTravel;
    _dragTravel = 0;
    _dragProgress = 0;
    if (_showToc || _showAppearance || _showSearch) return;
    if (travel.abs() > 56 || velocity.abs() > 600) {
      _turn(_turnFor(travel));
    }
  }

  Future<void> _onDragCancel() async {
    final pending = _curlStart;
    if (pending != null) await pending;
    if (!mounted) return;
    if (_curl.dragging) _curl.endDrag(complete: false);
    _dragTravel = 0;
    _dragProgress = 0;
  }

  static const _tapSlop = 16.0;
  static const _tapTimeout = Duration(milliseconds: 350);
  static const _edgeWidth = 96.0;

  ({Offset down, Duration elapsed})? _takeTap() {
    final down = _tapDownPos;
    final at = _tapDownAt;
    _tapDownPos = null;
    _tapDownAt = null;
    if (down == null || at == null) return null;
    return (down: down, elapsed: DateTime.now().difference(at));
  }

  bool _isTap(Offset down, Offset up, Duration elapsed) =>
      (up - down).distance <= _tapSlop && elapsed <= _tapTimeout;

  bool _onChromeBars(Offset point) {
    if (!_chromeVisible) return false;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.viewPaddingOf(context);
    return point.dy < safe.top + 52 ||
        point.dy > size.height - safe.bottom - 48;
  }

  int? _edgeTurn(double x) {
    if (!_settings.edgeTaps) return null;
    if (x < _edgeWidth) return turnForEdge(leading: true, rtl: _rtl);
    if (x > MediaQuery.sizeOf(context).width - _edgeWidth) {
      return turnForEdge(leading: false, rtl: _rtl);
    }
    return null;
  }

  void _onReaderPointerUp(Offset up) {
    final tap = _takeTap();
    if (tap == null || _curl.dragging || _curl.busy || !mounted) return;
    if (!_isTap(tap.down, up, tap.elapsed)) return;

    if (_showToc || _showAppearance || _showSearch) {
      setState(() => _showToc = _showAppearance = _showSearch = false);
      return;
    }
    if (_onChromeBars(tap.down)) return;

    final turn = _edgeTurn(up.dx);
    if (turn != null) {
      _turn(turn);
      return;
    }
    setState(() => _chromeVisible = !_chromeVisible);
    _syncSystemUi();
  }

  (double, double)? _lastInsets;

  EdgeInsets? _stableSafeArea;

  void _pushInsets({bool force = false}) {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final safe = MediaQuery.viewPaddingOf(context);
    if (_chromeVisible) _stableSafeArea = safe;
    final effective = _stableSafeArea ?? safe;
    final next = (effective.top + 52.0, effective.bottom + 48.0);
    if (_lastInsets == next && !force) return;
    _lastInsets = next;
    unawaited(controller.setInsets(next.$1, next.$2));
  }

  String _comicError(ComicFormatException e) {
    final l10n = context.l10n;
    return switch (e.kind) {
      ComicError.cbrFromFolder => l10n.comicCbrFromFolder,
      ComicError.invalid => l10n.comicInvalid,
      ComicError.stopped => l10n.comicStopped,
      ComicError.noPages => l10n.comicNoPages,
      ComicError.closed => l10n.comicClosed,
      ComicError.damaged => l10n.comicDamaged,
      ComicError.extractFailed => l10n.comicExtractFailed(e.detail),
      ComicError.readFailed => l10n.comicReadFailed(e.detail),
    };
  }

  Future<void> _open() async {
    final repo = ref.read(bookRepositoryProvider);
    final book = await repo.findBook(widget.bookId);
    if (!mounted) return;
    if (book == null) {
      setState(() => _error = context.l10n.bookNotInLibrary);
      return;
    }
    final OpenedFile opened;
    try {
      opened = await repo.openBookFile(book);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.bookFileNotFound);
      }
      return;
    }
    if (!mounted) {
      opened.close();
      return;
    }
    _openedFile = opened;
    final spec = opened.spec;

    final progress = await repo.readProgress(widget.bookId);
    _lastPercent = progress?.percent ?? 0;

    final rtl = switch (book.readingDirection) {
      'rtl' => true,
      'ltr' => false,
      _ => null,
    };
    final _EngineBuilder? engine;
    try {
      engine = switch (book.format) {
        BookFormat.epub => await _prepareEpub(spec),
        BookFormat.pdf => await _preparePdf(spec, rtl),
        BookFormat.comic => await _prepareComic(spec, rtl),
      };
    } on ComicFormatException catch (e) {
      if (mounted) setState(() => _error = _comicError(e));
      return;
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.bookOpenError('$e'));
      return;
    }

    await repo.markOpened(widget.bookId);
    if (!mounted) {
      unawaited(_releaseSources());
      return;
    }
    if (engine == null) {
      setState(() => _error ??= context.l10n.bookStructureError);
      return;
    }

    setState(() {
      _book = book;
      _engine = engine;
      _initialLocator = progress?.locator;
      _initialPercent = progress?.percent;
      final safe = MediaQuery.viewPaddingOf(context);
      _lastInsets = (safe.top + 52.0, safe.bottom + 48.0);
    });
  }

  Future<Directory> _extractDir() async {
    final cache = await getApplicationCacheDirectory();
    return Directory(p.join(cache.path, 'reader', widget.bookId));
  }

  Future<_EngineBuilder?> _prepareEpub(SourceSpec spec) async {
    final extractDir = await _extractDir();
    EpubBook epubBook;
    try {
      epubBook = await compute(prepareEpub, (
        spec: spec,
        extractDir: extractDir.path,
      ));
    } catch (_) {
      return null;
    } finally {
      _openedFile?.close();
    }
    final source = NativeBookSource(root: extractDir, book: epubBook);
    return (
      ReaderEngineCallbacks callbacks,
      String? locator,
      double? percent,
    ) => createEpubView(
      key: ValueKey(widget.bookId),
      source: source,
      initialLocator: locator,
      initialPercent: percent,
      callbacks: callbacks,
    );
  }

  bool _passwordDenied = false;

  Future<_EngineBuilder?> _preparePdf(SourceSpec spec, bool? rtl) async {
    final PdfDocument document;
    try {
      document = await openPdfDocument(spec, passwordProvider: _askPassword);
    } catch (_) {
      if (!mounted) return null;
      _error = _passwordDenied
          ? context.l10n.pdfPasswordProtected
          : context.l10n.pdfOpenError;
      return null;
    }
    _pdfDocument = document;
    return (ReaderEngineCallbacks callbacks, String? locator, double? _) =>
        PdfEngineView(
          key: ValueKey(widget.bookId),
          document: document,
          initialLocator: locator,
          initialRtl: rtl,
          callbacks: callbacks,
        );
  }

  Future<_EngineBuilder?> _prepareComic(SourceSpec spec, bool? rtl) async {
    final extractDir = await _extractDir();
    final archive = await ComicArchive.open(spec, cacheDir: extractDir.path);
    _comicArchive = archive;
    return (ReaderEngineCallbacks callbacks, String? locator, double? _) =>
        ComicEngineView(
          key: ValueKey(widget.bookId),
          archive: archive,
          initialLocator: locator,
          initialRtl: rtl,
          callbacks: callbacks,
        );
  }

  Future<String?> _askPassword() async {
    if (!mounted) return null;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: LannaColors.surfaceHigh,
        title: Text(context.l10n.pdfProtected),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(hintText: context.l10n.password),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.open),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result == null || result.isEmpty) {
      _passwordDenied = true;
      return null;
    }
    return result;
  }

  String? _initialLocator;
  double? _initialPercent;

  bool get _dragCurlReady => _controller != null;

  bool get _rtl => _controller?.rtl ?? false;

  void _setRtl(bool value) {
    final controller = _controller;
    if (controller == null || value == _rtl) return;
    unawaited(controller.setRtl(value));
    unawaited(_repo.setReadingDirection(widget.bookId, value ? 'rtl' : 'ltr'));
    setState(() {});
  }

  ReaderCapabilities get _caps =>
      _controller?.capabilities ?? const ReaderCapabilities();

  int _foldFor(int logical) => foldFor(logical, rtl: _rtl);

  int _turnFor(double travel) => turnForTravel(travel, rtl: _rtl);

  int get _chapterTotal => _controller?.chapterCount ?? 0;

  Bookmark? get _currentBookmark {
    final cfi = _location?.cfi;
    if (cfi == null) return null;
    for (final b in _bookmarks) {
      if (b.cfi == cfi) return b;
    }
    return null;
  }

  String? _currentChapterLabel() {
    final href = _location?.href?.split('#').first;
    if (href == null) return null;
    String? search(List<EpubTocEntry> entries) {
      for (final e in entries) {
        if (e.href.split('#').first == href) return e.label;
        final nested = search(e.children);
        if (nested != null) return nested;
      }
      return null;
    }

    return search(_toc);
  }

  void _toggleBookmark() {
    final loc = _location;
    if (loc == null) return;
    final repo = ref.read(bookRepositoryProvider);
    final existing = _currentBookmark;
    if (existing != null) {
      unawaited(repo.deleteBookmark(existing.id));
      _notify(context.l10n.bookmarkRemoved);
    } else {
      unawaited(
        repo.addBookmark(
          bookId: widget.bookId,
          cfi: loc.cfi,
          chapterIndex: loc.chapterIndex,
          percent: _lastPercent,
          label: _currentChapterLabel() ?? loc.label,
        ),
      );
      _notify(context.l10n.bookmarkAdded);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _addHighlight(String color) {
    final sel = _selection;
    if (sel == null) return;
    unawaited(
      ref
          .read(bookRepositoryProvider)
          .addHighlight(
            bookId: widget.bookId,
            cfi: sel.cfi,
            text: sel.text,
            color: color,
            chapterIndex: _location?.chapterIndex,
            percent: _lastPercent,
          ),
    );
    unawaited(_controller?.addHighlight(sel.cfi, color));
    unawaited(_controller?.clearSelection());
    setState(() => _selection = null);
  }

  Future<void> _openHighlight(String cfi) async {
    if (!mounted) return;
    final match = _highlights.where((h) => h.cfi == cfi).toList();
    if (match.isEmpty) return;
    final highlight = match.first;
    final repo = _repo;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: LannaColors.surfaceHigh,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s5,
                LannaSpacing.s4,
                LannaSpacing.s5,
                LannaSpacing.s2,
              ),
              child: Text(
                highlight.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.reading(fontSize: 14, color: LannaColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s4),
              child: Row(
                children: [
                  for (final c in _highlightColors.keys)
                    Padding(
                      padding: const EdgeInsets.all(LannaSpacing.s1 + 2),
                      child: GestureDetector(
                        onTap: () {
                          unawaited(repo.setHighlightColor(highlight.id, c));
                          unawaited(_controller?.addHighlight(cfi, c));
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _highlightColors[c],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c == highlight.color
                                  ? LannaColors.textStrong
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: Text(
                highlight.note?.isNotEmpty ?? false
                    ? context.l10n.editNote
                    : context.l10n.addNote,
              ),
              onTap: () => Navigator.of(context).pop('note'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.delete),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
            const SizedBox(height: LannaSpacing.s1 + 2),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      unawaited(repo.deleteHighlight(highlight.id));
      unawaited(_controller?.removeHighlight(cfi) ?? Future.value());
    } else if (action == 'note') {
      final note = await _promptNote(highlight.note);
      if (note != null) unawaited(repo.setHighlightNote(highlight.id, note));
    }
  }

  Future<String?> _promptNote(String? initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LannaColors.surfaceHigh,
        title: Text(context.l10n.note),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: context.l10n.writeNote),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Timer? _primeTimer;

  void _refreshSnapshot() {
    _curl.invalidate();
    _primeTimer?.cancel();
    if (PageTransition.forSetting(_settings.pageAnimation) == null) return;
    _primeTimer = Timer(const Duration(milliseconds: 250), () {
      final controller = _controller;
      if (!mounted || controller == null || _curl.busy) return;
      unawaited(_curl.prime(controller.snapshot));
    });
  }

  void _onLocation(ReaderLocation loc) {
    if (!mounted) return;
    _refreshSnapshot();
    if (loc.percentage != null) _lastPercent = loc.percentage!;
    final previous = _location;
    _tracker.activity(
      percent: loc.percentage,
      turned: previous != null && previous.cfi != loc.cfi,
    );
    if (loc.atEnd && !_finishMarked) {
      _finishMarked = true;
      unawaited(_repo.markFinished(widget.bookId));
    }
    setState(() => _location = loc);

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(
        _repo.saveProgress(
          bookId: widget.bookId,
          locator: loc.cfi,
          percent: _lastPercent,
          chapterIndex: loc.chapterIndex,
        ),
      );
    });
  }

  void _applySettings(ReaderSettings settings) {
    if (!mounted) return;
    _refreshSnapshot();
    _curl.paper = Color.lerp(
      settings.preset.background,
      settings.preset.foreground,
      0.06,
    )!;
    unawaited(_controller?.applyPresentation(settings.toPresentation()));
    unawaited(WakelockPlus.toggle(enable: settings.keepAwake));
  }

  Future<void> _animatedTurn(
    int dir,
    PageTransition mode,
    ReaderEngineController controller,
    PageTurn advance,
  ) async {
    final started = await _curl.start(
      dir,
      mode: mode,
      outgoing: controller.snapshot,
      advance: advance,
    );
    if (!started && mounted) unawaited(advance());
  }

  void _turn(int dir) {
    if (_showToc || _showAppearance || _showSearch) return;
    final controller = _controller;
    if (controller == null || !_canTurn(dir)) return;
    Future<void> advance() =>
        dir > 0 ? controller.next() : controller.previous();
    final mode = _transition;
    if (mode != null) {
      if (_curl.busy) return;
      unawaited(_animatedTurn(_foldFor(dir), mode, controller, advance));
      return;
    }
    unawaited(advance());
  }

  void _runSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchQuery = trimmed;
        _searchHits = const [];
        _searchBusy = false;
      });
      return;
    }
    setState(() {
      _searchQuery = trimmed;
      _searchHits = const [];
      _searchBusy = true;
    });
    unawaited(_controller?.search(trimmed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _settingsSub?.close();
    _bookmarksSub?.close();
    _highlightsSub?.close();
    unawaited(WakelockPlus.disable());
    _primeTimer?.cancel();
    _curl.dispose();
    unawaited(_releaseSources());
    _saveTimer?.cancel();
    _saveProgressNow();
    _tracker.pause();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        _turn(turnForEdge(leading: false, rtl: _rtl));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _turn(turnForEdge(leading: true, rtl: _rtl));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        _turn(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _turn(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_showToc || _showAppearance || _showSearch) {
          setState(() => _showToc = _showAppearance = _showSearch = false);
          return KeyEventResult.handled;
        }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushInsets());
    final barsVisible = _chromeVisible && !_showToc && !_showSearch;

    return Scaffold(
      backgroundColor: settings.preset.background,
      body: switch ((_error, _engine)) {
        (final String error, _) => _ErrorView(message: error),
        (_, null) => const Center(child: CircularProgressIndicator()),
        _ => Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              _engineLayer(settings),
              _gestureLayer(),
              ?_curl.overlay(),
              ?_selectionToolbar(),
              ReaderBar(visible: barsVisible, fromTop: true, child: _topBar()),
              ReaderBar(
                visible: barsVisible,
                fromTop: false,
                child: _bottomBar(),
              ),
              ReaderCornerPanel(
                open: _showAppearance,
                right: 26,
                bottom: 58,
                child: _showAppearance
                    ? _appearancePanel(settings)
                    : const SizedBox.shrink(),
              ),
              ReaderSidePanel(
                open: _showToc,
                child: _showToc ? _tocPanel() : const SizedBox.shrink(),
              ),
              ReaderSidePanel(
                open: _showSearch,
                child: _showSearch ? _searchPanel() : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      },
    );
  }

  void _jumpTo(String cfi) {
    unawaited(_controller?.goToCfi(cfi));
    setState(() {
      _showToc = false;
      _showSearch = false;
    });
  }

  ReaderEngineCallbacks _engineCallbacks(ReaderSettings settings) {
    return ReaderEngineCallbacks(
      onReady: (c) {
        _controller = c;
        _applySettings(settings);
        unawaited(
          c.applyHighlights([
            for (final h in _highlights)
              HighlightSpec(cfi: h.cfi, color: h.color),
          ]),
        );
        _pushInsets(force: true);
        _focusNode.requestFocus();
      },
      onLocationChanged: _onLocation,
      onTocLoaded: (toc) {
        if (mounted) setState(() => _toc = toc);
      },
      onPageCount: (total) {
        if (!mounted || total == _pageCount) return;
        setState(() => _pageCount = total);
      },
      onSearchResults: (query, hits) {
        if (!mounted || query != _searchQuery) return;
        setState(() {
          _searchHits = hits;
          _searchBusy = false;
        });
      },
      onTextSelected: (sel) {
        if (!mounted) return;
        setState(() => _selection = sel);
        _refreshSnapshot();
      },
      onSelectionCleared: () {
        if (mounted && _selection != null) setState(() => _selection = null);
      },
      onHighlightTapped: _openHighlight,
      onError: (m) {
        if (mounted) setState(() => _error = m);
      },
    );
  }

  Widget _engineLayer(ReaderSettings settings) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _curl.animation,
        builder: (context, child) => FractionalTranslation(
          key: readerIncomingKey,
          translation: Offset(_curl.incomingShift, 0),
          child: child,
        ),
        child: _engine!(
          _engineCallbacks(settings),
          _initialLocator,
          _initialPercent,
        ),
      ),
    );
  }

  Widget _gestureLayer() {
    return Positioned.fill(
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                () => HorizontalDragGestureRecognizer(
                  supportedDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                ),
                (instance) {
                  instance
                    ..onStart = _onDragStart
                    ..onUpdate = _onDragUpdate
                    ..onEnd = _onDragEnd
                    ..onCancel = _onDragCancel;
                },
              ),
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _tapDownPos = e.position;
            _tapDownAt = DateTime.now();
            if (_location != null) _tracker.activity();
          },
          onPointerUp: (e) => _onReaderPointerUp(e.position),
          onPointerCancel: (_) {
            _tapDownPos = null;
            _tapDownAt = null;
          },
        ),
      ),
    );
  }

  Widget _appearancePanel(ReaderSettings settings) {
    final controller = ref.read(readerSettingsControllerProvider);
    final reflowable = _caps.reflowable;
    return AppearancePanel(
      settings: settings,
      bookFontAvailable: _caps.bookFontAvailable,
      bookFontUnsupported: _caps.bookFontUnsupported,
      onPreset: controller.setPreset,
      onFontFamily: reflowable ? controller.setFontFamily : null,
      onFontScale: reflowable ? controller.setFontScale : null,
      onLineHeight: reflowable ? controller.setLineHeight : null,
      onColumns: controller.setColumns,
      rtl: _rtl,
      onDirection: _caps.directional ? _setRtl : null,
      onPageNumbers: reflowable ? controller.setPageNumbers : null,
    );
  }

  Widget _tocPanel() {
    final repo = ref.read(bookRepositoryProvider);
    return TocDrawer(
      toc: _toc,
      currentHref: _location?.href,
      chapterCount: _chapterTotal,
      pageCount: _pageCount,
      bookmarks: _bookmarks,
      currentCfi: _location?.cfi,
      chrome: _chrome,
      onSelect: (entry) {
        if (entry.href.isNotEmpty) {
          _jumpTo(entry.href);
        } else {
          setState(() => _showToc = false);
        }
      },
      onBookmarkSelect: (bookmark) => _jumpTo(bookmark.cfi),
      onBookmarkDelete: (bookmark) => repo.deleteBookmark(bookmark.id),
      highlights: _highlights,
      highlightColors: _highlightColors,
      onHighlightSelect: (h) => _jumpTo(h.cfi),
      onHighlightDelete: (h) {
        unawaited(repo.deleteHighlight(h.id));
        unawaited(_controller?.removeHighlight(h.cfi));
      },
      onClose: () => setState(() => _showToc = false),
    );
  }

  Widget _searchPanel() {
    return SearchPanel(
      chrome: _chrome,
      hits: _searchHits,
      busy: _searchBusy,
      query: _searchQuery,
      onSubmit: _runSearch,
      onSelect: (hit) => _jumpTo(hit.cfi),
      onClose: () => setState(() => _showSearch = false),
    );
  }

  ReaderChrome get _chrome => ReaderChrome.of(_settings.preset);

  Widget? _selectionToolbar() {
    final sel = _selection;
    if (sel == null || sel.text.isEmpty) return null;
    final chrome = _chrome;
    final size = MediaQuery.sizeOf(context);
    const toolbarWidth = 236.0;
    const toolbarHeight = 44.0;
    final origin = selectionToolbarOrigin(
      selection: sel.rect,
      viewport: size,
      toolbar: const Size(toolbarWidth, toolbarHeight),
    );
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(sel.cfi),
          tween: Tween(begin: 0, end: 1),
          duration: LannaMotion.fast,
          curve: LannaMotion.ease,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
          child: Container(
            height: toolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s2),
            decoration: BoxDecoration(
              color: chrome.panelBackground,
              borderRadius: LannaRadii.brMd,
              border: Border.all(color: chrome.panelBorder),
              boxShadow: LannaElevation.e2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in _highlightColors.keys)
                  GestureDetector(
                    onTap: () => _addHighlight(c),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _highlightColors[c],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 1,
                  height: 22,
                  color: chrome.panelBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.copy, size: 17, color: chrome.onBarMuted),
                  onPressed: () {
                    unawaited(Clipboard.setData(ClipboardData(text: sel.text)));
                    unawaited(_controller?.clearSelection());
                    setState(() => _selection = null);
                    _notify(context.l10n.textCopied);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final author = _book?.author;
    final title = _book?.title ?? '';
    final chrome = _chrome;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.viewPaddingOf(context).top,
        left: LannaSpacing.s3,
        right: LannaSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: chrome.barBackground.withValues(alpha: 0.94),
        border: Border(bottom: BorderSide(color: chrome.barBorder)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ReaderBarButton(
              icon: Icons.chevron_left,
              size: 22,
              color: chrome.onBarMuted,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text(
                author == null ? title : '$title  ·  $author',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.reading(fontSize: 13, color: chrome.onBarMuted),
              ),
            ),
            ReaderBarButton(
              icon: Icons.format_list_bulleted,
              active: _showToc,
              tooltip: context.l10n.tableOfContents,
              color: chrome.onBarMuted,
              onTap: () => setState(() {
                _showToc = !_showToc;
                _showAppearance = false;
              }),
            ),
            ReaderBarButton(
              label: 'Aa',
              active: _showAppearance,
              tooltip: context.l10n.appearance,
              color: chrome.onBarMuted,
              onTap: () => setState(() {
                _showAppearance = !_showAppearance;
                _showToc = false;
              }),
            ),
            ReaderBarButton(
              icon: _currentBookmark != null
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              active: _currentBookmark != null,
              tooltip: context.l10n.bookmark,
              color: chrome.onBarMuted,
              onTap: _location == null ? null : _toggleBookmark,
            ),
            if (_caps.searchable)
              ReaderBarButton(
                icon: Icons.search,
                active: _showSearch,
                tooltip: context.l10n.search,
                color: chrome.onBarMuted,
                onTap: () => setState(() {
                  _showSearch = !_showSearch;
                  _showToc = false;
                  _showAppearance = false;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final pct = (_location?.percentage ?? _lastPercent).clamp(0.0, 1.0);
    final label = _location?.label;
    final mins = _location?.remainingMinutes;
    final controller = _controller;
    final chrome = _chrome;

    final style = LannaType.micro.copyWith(color: chrome.onBarMuted);

    return Container(
      padding: EdgeInsets.only(
        left: LannaSpacing.s6,
        right: LannaSpacing.s6,
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: chrome.barBackground.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: chrome.barBorder)),
      ),
      child: SizedBox(
        height: LannaSpacing.barHeight,
        child: Row(
          children: [
            if (label != null) Text(label, style: style),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: ReaderScrubber(
                value: pct,
                chrome: chrome,
                rtl: controller?.rtl ?? false,
                onSeek: (f) => controller?.goToPercentage(f),
                trailingLabel: (f) => '${(f * 100).round()} %',
                bubbleLabel: (f) =>
                    controller?.scrubLabel(f) ?? '${(f * 100).round()} %',
              ),
            ),
            if (mins != null && mins > 0) ...[
              Text('  ·  ', style: style),
              Text(context.l10n.minutesLeft(mins), style: style),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: LannaColors.textMuted),
          const SizedBox(height: LannaSpacing.s3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
            child: Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: LannaType.md.copyWith(color: LannaColors.textMuted),
            ),
          ),
          const SizedBox(height: LannaSpacing.s4),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(context.l10n.back),
          ),
        ],
      ),
    );
  }
}
