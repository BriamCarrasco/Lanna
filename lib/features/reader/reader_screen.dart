// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/epub/epub_book.dart';
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import 'epub_view.dart';
import 'epub_view_factory.dart';
import 'native/book_source.dart';
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
int foldFor(int logical, {required bool rtl}) => rtl ? -logical : logical;

@visibleForTesting
int turnForTravel(double travel, {required bool rtl}) =>
    (rtl ? travel > 0 : travel < 0) ? 1 : -1;

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
  final left = (selection.center.dx - toolbar.width / 2)
      .clamp(8.0, maxLeft)
      .toDouble();
  var top = selection.top - toolbar.height - 10;
  if (top < 60) {
    final maxTop = math.max(60.0, viewport.height - toolbar.height - 50);
    top = (selection.bottom + 10).clamp(60.0, maxTop).toDouble();
  }
  return Offset(left, top);
}

const _highlightColors = <String, Color>{
  'yellow': Color(0xFFFFE14D),
  'green': Color(0xFF8FE08A),
  'blue': Color(0xFF7FC0FF),
  'pink': Color(0xFFFF9EC9),
};

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
      if (mounted) setState(() {});
    },
  );

  NativeBookSource? _nativeSource;
  EpubViewController? _controller;
  Book? _book;
  EpubBook? _epubBook;
  ReaderLocation? _location;

  List<EpubTocEntry> _fallbackToc = const [];
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
  ProviderSubscription<AsyncValue<ReaderSettings>>? _settingsSub;
  ProviderSubscription<AsyncValue<List<Bookmark>>>? _bookmarksSub;
  ProviderSubscription<AsyncValue<List<Highlight>>>? _highlightsSub;
  late final BookRepository _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    }, fireImmediately: true);
    _syncSystemUi();
    _open();
  }

  void _syncSystemUi() {
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgressNow();
    }
  }

  void _saveProgressNow() {
    final loc = _location;
    if (loc == null) return;
    _saveTimer?.cancel();
    _repo.saveProgress(
      bookId: widget.bookId,
      locator: loc.cfi,
      percent: _lastPercent,
      chapterIndex: loc.chapterIndex,
    );
  }

  Offset? _tapDownPos;
  DateTime? _tapDownAt;

  bool get _dragCurlEnabled =>
      _dragCurlReady &&
      _settings.pageAnimation == 'curl' &&
      !_showToc &&
      !_showAppearance &&
      !_showSearch;

  double _dragProgress = 0;

  bool get _atStart => _location?.atStart ?? false;

  bool get _atEnd => _location?.atEnd ?? false;

  double _dragTravel = 0;

  void _onDragStart(DragStartDetails details) {
    _dragTravel = 0;
    _dragProgress = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragTravel += details.delta.dx;
    if (!_dragCurlEnabled) return;

    final width = MediaQuery.sizeOf(context).width;
    if (!_curl.dragging) {
      if (_curl.busy) return;
      if (_dragTravel.abs() < 16) return;
      final controller = _controller;
      if (controller == null) return;
      final forward = _rtl ? _dragTravel > 0 : _dragTravel < 0;
      if (forward ? _atEnd : _atStart) return;
      unawaited(
        _curl.beginDrag(
          _foldFor(forward ? 1 : -1),
          outgoing: controller.snapshot,
          advance: () => forward ? controller.next() : controller.previous(),
          revert: () => forward ? controller.previous() : controller.next(),
        ),
      );
      return;
    }

    final travel = (_dragTravel.abs() - 16).clamp(0.0, double.infinity);
    _dragProgress = (travel / (width * 0.7)).clamp(0.0, 1.0);
    _curl.updateDrag(_dragProgress);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_curl.dragging) {
      _curl.endDrag(complete: _dragProgress > 0.35 || velocity.abs() > 600);
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

  void _onDragCancel() {
    if (_curl.dragging) _curl.endDrag(complete: false);
    _dragTravel = 0;
    _dragProgress = 0;
  }

  void _onReaderPointerUp(Offset up) {
    if (_curl.dragging || _curl.busy) {
      _tapDownPos = null;
      _tapDownAt = null;
      return;
    }
    final down = _tapDownPos;
    final at = _tapDownAt;
    _tapDownPos = null;
    _tapDownAt = null;
    if (down == null || at == null || !mounted) return;

    final elapsed = DateTime.now().difference(at);
    final delta = up - down;
    final panelOpen = _showToc || _showAppearance || _showSearch;

    if (panelOpen) {
      if (delta.distance <= 16 &&
          elapsed <= const Duration(milliseconds: 350)) {
        setState(() => _showToc = _showAppearance = _showSearch = false);
      }
      return;
    }

    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.viewPaddingOf(context);
    if (_chromeVisible &&
        (down.dy < safe.top + 52 || down.dy > size.height - safe.bottom - 48)) {
      return;
    }

    if (delta.distance > 16) return;

    if (elapsed > const Duration(milliseconds: 350)) return;

    final edgeRaw = size.width * 0.22;
    final edge = edgeRaw > 130 ? 130.0 : edgeRaw;
    if (_settings.edgeTaps && up.dx < edge) {
      _turn(turnForEdge(leading: true, rtl: _rtl));
      return;
    }
    if (_settings.edgeTaps && up.dx > size.width - edge) {
      _turn(turnForEdge(leading: false, rtl: _rtl));
      return;
    }
    setState(() => _chromeVisible = !_chromeVisible);
    _syncSystemUi();
  }

  (double, double)? _lastInsets;

  void _pushInsets({bool force = false}) {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final safe = MediaQuery.viewPaddingOf(context);
    final next = (safe.top + 52.0, safe.bottom + 48.0);
    if (_lastInsets == next && !force) return;
    _lastInsets = next;
    controller.setInsets(next.$1, next.$2);
  }

  Future<void> _open() async {
    final repo = ref.read(bookRepositoryProvider);
    final book = await repo.findBook(widget.bookId);
    if (!mounted) return;
    if (book == null) {
      setState(() => _error = 'El libro no está en la biblioteca');
      return;
    }
    if (book.format != BookFormat.epub) {
      setState(() => _error = 'Por ahora solo se pueden leer archivos EPUB');
      return;
    }
    final file = File(book.filePath);
    if (!file.existsSync()) {
      setState(() => _error = 'No se encontró el archivo del libro');
      return;
    }

    final progress = await repo.readProgress(widget.bookId);
    _lastPercent = progress?.percent ?? 0;

    final cache = await getApplicationCacheDirectory();
    final extractDir = Directory(p.join(cache.path, 'reader', widget.bookId));

    EpubBook? epubBook;
    try {
      epubBook = await compute(prepareEpub, (
        path: file.path,
        extractDir: extractDir.path,
      ));
    } catch (_) {}

    await repo.markOpened(widget.bookId);
    if (!mounted) return;

    if (epubBook == null) {
      setState(() => _error = 'No se pudo leer la estructura del libro');
      return;
    }

    setState(() {
      _book = book;
      _epubBook = epubBook;
      _nativeSource = NativeBookSource(root: extractDir, book: epubBook!);
      _initialLocator = progress?.locator;
      _initialPercent = progress?.percent;
      final safe = MediaQuery.viewPaddingOf(context);
      _lastInsets = (safe.top + 52.0, safe.bottom + 48.0);
    });
  }

  String? _initialLocator;
  double? _initialPercent;

  bool get _dragCurlReady => _nativeSource != null;

  bool get _rtl => _nativeSource?.rtl ?? false;

  int _foldFor(int logical) => foldFor(logical, rtl: _rtl);

  int _turnFor(double travel) => turnForTravel(travel, rtl: _rtl);

  List<EpubTocEntry> get _toc {
    final parsed = _epubBook?.toc ?? const [];
    return parsed.isNotEmpty ? parsed : _fallbackToc;
  }

  int get _chapterTotal => _epubBook?.spine.where((s) => s.linear).length ?? 0;

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
      repo.deleteBookmark(existing.id);
      _notify('Marcador quitado');
    } else {
      repo.addBookmark(
        bookId: widget.bookId,
        cfi: loc.cfi,
        chapterIndex: loc.chapterIndex,
        percent: _lastPercent,
        label: _currentChapterLabel(),
      );
      _notify('Marcador añadido');
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
    ref
        .read(bookRepositoryProvider)
        .addHighlight(
          bookId: widget.bookId,
          cfi: sel.cfi,
          text: sel.text,
          color: color,
          chapterIndex: _location?.chapterIndex,
          percent: _lastPercent,
        );
    _controller?.addHighlight(sel.cfi, color);
    _controller?.clearSelection();
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
                          repo.setHighlightColor(highlight.id, c);
                          _controller?.addHighlight(cfi, c);
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
                highlight.note?.isNotEmpty == true
                    ? 'Editar nota'
                    : 'Añadir nota',
              ),
              onTap: () => Navigator.of(context).pop('note'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
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
        title: const Text('Nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Escribe una nota'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  void _onLocation(ReaderLocation loc) {
    if (!mounted) return;
    if (loc.percentage != null) _lastPercent = loc.percentage!;
    setState(() => _location = loc);

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      _repo.saveProgress(
        bookId: widget.bookId,
        locator: loc.cfi,
        percent: _lastPercent,
        chapterIndex: loc.chapterIndex,
      );
    });
  }

  void _applySettings(ReaderSettings settings) {
    if (!mounted) return;
    _controller?.applyPresentation(settings.toPresentation());
    WakelockPlus.toggle(enable: settings.keepAwake);
  }

  Future<void> _curlTurn(
    int dir,
    EpubViewController controller,
    PageTurn advance,
  ) async {
    final started = await _curl.start(
      dir,
      outgoing: controller.snapshot,
      advance: advance,
    );
    if (!started && mounted) unawaited(advance());
  }

  void _turn(int dir) {
    if (_showToc || _showAppearance || _showSearch) return;
    final controller = _controller;
    if (controller == null) return;
    Future<void> advance() =>
        dir > 0 ? controller.next() : controller.previous();
    if (_settings.pageAnimation == 'curl') {
      if (_curl.busy) return;
      unawaited(_curlTurn(_foldFor(dir), controller, advance));
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
    _controller?.search(trimmed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _settingsSub?.close();
    _bookmarksSub?.close();
    _highlightsSub?.close();
    WakelockPlus.disable();
    _curl.dispose();
    _saveProgressNow();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        _turn(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
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

    return Scaffold(
      backgroundColor: settings.preset.background,
      body: _error != null
          ? _ErrorView(message: _error!)
          : _nativeSource == null
          ? const Center(child: CircularProgressIndicator())
          : Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: createEpubView(
                      key: ValueKey(widget.bookId),
                      source: _nativeSource!,
                      initialLocator: _initialLocator,
                      initialPercent: _initialPercent,
                      callbacks: EpubViewCallbacks(
                        onReady: (c) {
                          _controller = c;
                          _applySettings(settings);
                          c.applyHighlights([
                            for (final h in _highlights)
                              HighlightSpec(cfi: h.cfi, color: h.color),
                          ]);
                          _pushInsets(force: true);
                          _focusNode.requestFocus();
                        },
                        onLocationChanged: _onLocation,
                        onTocLoaded: (toc) {
                          if (!mounted) return;
                          setState(() {
                            _fallbackToc = [
                              for (final e in toc)
                                EpubTocEntry(label: e.label, href: e.href),
                            ];
                          });
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
                        },
                        onSelectionCleared: () {
                          if (mounted && _selection != null) {
                            setState(() => _selection = null);
                          }
                        },
                        onHighlightTapped: _openHighlight,
                        onError: (m) {
                          if (!mounted) return;
                          setState(() => _error = m);
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: _onDragCancel,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (e) {
                          _tapDownPos = e.position;
                          _tapDownAt = DateTime.now();
                        },
                        onPointerUp: (e) => _onReaderPointerUp(e.position),
                        onPointerCancel: (_) {
                          _tapDownPos = null;
                          _tapDownAt = null;
                        },
                      ),
                    ),
                  ),
                  ?_curl.overlay(),
                  ?_selectionToolbar(),
                  ReaderBar(
                    visible: _chromeVisible && !_showToc && !_showSearch,
                    fromTop: true,
                    child: _topBar(),
                  ),
                  ReaderBar(
                    visible: _chromeVisible && !_showToc && !_showSearch,
                    fromTop: false,
                    child: _bottomBar(),
                  ),
                  ReaderCornerPanel(
                    open: _showAppearance,
                    right: 26,
                    bottom: 58,
                    child: _showAppearance
                        ? AppearancePanel(
                            settings: settings,
                            bookFontAvailable:
                                _nativeSource?.bookFontFamily != null,
                            bookFontUnsupported:
                                _nativeSource?.bookFontUnsupported ?? false,
                            onPreset: (p) => ref
                                .read(readerSettingsControllerProvider)
                                .setPreset(p),
                            onFontFamily: (f) => ref
                                .read(readerSettingsControllerProvider)
                                .setFontFamily(f),
                            onFontScale: (v) => ref
                                .read(readerSettingsControllerProvider)
                                .setFontScale(v),
                            onLineHeight: (v) => ref
                                .read(readerSettingsControllerProvider)
                                .setLineHeight(v),
                            onColumns: (m) => ref
                                .read(readerSettingsControllerProvider)
                                .setColumns(m),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ReaderSidePanel(
                    open: _showToc,
                    child: _showToc
                        ? TocDrawer(
                            toc: _toc,
                            currentHref: _location?.href,
                            chapterCount: _chapterTotal,
                            pageCount: _pageCount,
                            bookmarks: _bookmarks,
                            currentCfi: _location?.cfi,
                            chrome: _chrome,
                            onSelect: (entry) {
                              if (entry.href.isNotEmpty) {
                                _controller?.goToCfi(entry.href);
                              }
                              setState(() => _showToc = false);
                            },
                            onBookmarkSelect: (bookmark) {
                              _controller?.goToCfi(bookmark.cfi);
                              setState(() => _showToc = false);
                            },
                            onBookmarkDelete: (bookmark) => ref
                                .read(bookRepositoryProvider)
                                .deleteBookmark(bookmark.id),
                            highlights: _highlights,
                            highlightColors: _highlightColors,
                            onHighlightSelect: (h) {
                              _controller?.goToCfi(h.cfi);
                              setState(() => _showToc = false);
                            },
                            onHighlightDelete: (h) {
                              ref
                                  .read(bookRepositoryProvider)
                                  .deleteHighlight(h.id);
                              _controller?.removeHighlight(h.cfi);
                            },
                            onClose: () => setState(() => _showToc = false),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ReaderSidePanel(
                    open: _showSearch,
                    child: _showSearch
                        ? SearchPanel(
                            chrome: _chrome,
                            hits: _searchHits,
                            busy: _searchBusy,
                            query: _searchQuery,
                            onSubmit: _runSearch,
                            onSelect: (hit) {
                              _controller?.goToCfi(hit.cfi);
                              setState(() => _showSearch = false);
                            },
                            onClose: () => setState(() => _showSearch = false),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
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
                    Clipboard.setData(ClipboardData(text: sel.text));
                    _controller?.clearSelection();
                    setState(() => _selection = null);
                    _notify('Texto copiado');
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
              tooltip: 'Índice',
              color: chrome.onBarMuted,
              onTap: () => setState(() {
                _showToc = !_showToc;
                _showAppearance = false;
              }),
            ),
            ReaderBarButton(
              label: 'Aa',
              active: _showAppearance,
              tooltip: 'Apariencia',
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
              tooltip: 'Marcador',
              color: chrome.onBarMuted,
              onTap: _location == null ? null : _toggleBookmark,
            ),
            ReaderBarButton(
              icon: Icons.search,
              active: _showSearch,
              tooltip: 'Buscar',
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
    final chapter = _location?.chapterIndex;
    final total = _chapterTotal;
    final mins = _location?.remainingMinutes;
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
            if (chapter != null)
              Text(
                total > 0
                    ? 'Capítulo ${chapter + 1} de $total'
                    : 'Capítulo ${chapter + 1}',
                style: style,
              ),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: ReaderScrubber(
                value: pct,
                chrome: chrome,
                onSeek: (f) => _controller?.goToPercentage(f),
                trailingLabel: (f) => '${(f * 100).round()} %',
                bubbleLabel: (f) => '${(f * 100).round()} %',
              ),
            ),
            if (mins != null && mins > 0) ...[
              Text('  ·  ', style: style),
              Text('quedan ~$mins min', style: style),
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
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
