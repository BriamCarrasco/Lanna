// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/text_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/epub/epub_book.dart';
import '../../../data/local/app_database.dart';
import '../epub_view.dart';
import '../reader_settings_provider.dart';
import '../reader_theme.dart';
import '../widgets/appearance_panel.dart';
import '../widgets/page_curl.dart';
import '../widgets/reader_bar_button.dart';
import '../widgets/reader_scrubber.dart';
import '../widgets/reader_transitions.dart';
import '../widgets/search_panel.dart';
import '../widgets/toc_drawer.dart';
import 'selectable_pdf_page.dart';

const _spreadMinWidth = 820.0;

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _focusNode = FocusNode();
  final _pagerKey = GlobalKey();
  PageController? _pageController;
  PdfDocument? _document;

  late final PageCurlController _curl = PageCurlController(
    vsync: this,
    onChange: () {
      if (mounted) setState(() {});
    },
  );

  Book? _book;
  String? _error;
  int _restorePage = 1;
  int _page = 1;
  int _pageCount = 0;
  int _spreadIndex = 0;
  int _spreadSize = 1;
  double _viewportWidth = 0;

  bool _chromeVisible = true;
  bool _showToc = false;
  bool _showAppearance = false;
  bool _showSearch = false;

  List<EpubTocEntry> _toc = const [];
  List<Bookmark> _bookmarks = const [];
  List<Highlight> _highlights = const [];
  PdfSelection? _pdfSelection;
  List<SearchHit> _searchHits = const [];
  bool _searchBusy = false;
  String _searchQuery = '';

  ReaderSettings _settings = const ReaderSettings();

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
      _syncSpreadSize();
      WakelockPlus.toggle(enable: s.keepAwake);
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
    _load();
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
    if (_pageCount <= 0) return;
    _saveTimer?.cancel();
    _repo.saveProgress(
      bookId: widget.bookId,
      locator: 'page:$_page',
      percent: _page / _pageCount,
      chapterIndex: _page - 1,
    );
  }

  List<Highlight> _highlightsForPage(int page) =>
      _highlights.where((h) => h.cfi.startsWith('page:$page#')).toList();

  static const _highlightColors = <String, Color>{
    'yellow': Color(0xFFFFE14D),
    'green': Color(0xFF8FE08A),
    'blue': Color(0xFF7FC0FF),
    'pink': Color(0xFFFF9EC9),
  };

  bool _passwordDenied = false;

  Future<String?> _askPassword() async {
    if (!mounted) return null;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: LannaColors.surfaceHigh,
        title: const Text('PDF protegido'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Contraseña'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Abrir'),
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

  Future<void> _load() async {
    final repo = ref.read(bookRepositoryProvider);
    final book = await repo.findBook(widget.bookId);
    if (book == null) {
      setState(() => _error = 'El libro no está en la biblioteca');
      return;
    }
    if (!File(book.filePath).existsSync()) {
      setState(() => _error = 'No se encontró el archivo del libro');
      return;
    }
    final progress = await repo.readProgress(widget.bookId);
    await repo.markOpened(widget.bookId);

    PdfDocument document;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openFile(
        book.filePath,
        passwordProvider: _askPassword,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _passwordDenied
              ? 'PDF protegido con contraseña'
              : 'No se pudo abrir el PDF',
        );
      }
      return;
    }
    if (!mounted) {
      unawaited(document.dispose());
      return;
    }

    List<EpubTocEntry> toc = const [];
    try {
      toc = _mapOutline(await document.loadOutline());
    } catch (_) {}

    if (_settings.keepAwake) unawaited(WakelockPlus.enable());

    setState(() {
      _book = book;
      _document = document;
      _pageCount = document.pages.length;
      _restorePage = ((progress?.chapterIndex ?? 0) + 1).clamp(1, _pageCount);
      _page = _restorePage;
      _toc = toc;
    });
  }

  List<EpubTocEntry> _mapOutline(List<PdfOutlineNode> nodes) => [
    for (final node in nodes)
      EpubTocEntry(
        label: node.title.trim(),
        href: node.dest != null ? 'page:${node.dest!.pageNumber}' : '',
        children: _mapOutline(node.children),
      ),
  ];

  int _resolveSpreadSize() {
    switch (_settings.columns) {
      case 'single':
        return 1;
      case 'double':
        return 2;
      default:
        return _viewportWidth >= _spreadMinWidth ? 2 : 1;
    }
  }

  int get _spreadCount =>
      _pageCount == 0 ? 0 : ((_pageCount + _spreadSize - 1) ~/ _spreadSize);

  int _spreadIndexOf(int page) => (page - 1) ~/ _spreadSize;

  void _applyViewport(double width) {
    if (width == _viewportWidth) return;
    _viewportWidth = width;
    _syncSpreadSize();
  }

  void _syncSpreadSize() {
    final next = _resolveSpreadSize();
    if (next == _spreadSize) return;
    _spreadSize = next;
    final controller = _pageController;
    if (controller != null && controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.jumpToPage(_spreadIndexOf(_page));
      });
    }
  }

  void _turn(int dir) {
    if (_showToc || _showAppearance || _showSearch) return;
    final controller = _pageController;
    if (controller == null || !controller.hasClients || _spreadCount == 0) {
      return;
    }
    final target = (_spreadIndex + dir).clamp(0, _spreadCount - 1);
    if (target == _spreadIndex) return;

    final anim = _settings.pageAnimation;
    void jump() => controller.jumpToPage(target);
    void fallback() {
      if (anim == 'none') {
        controller.jumpToPage(target);
      } else {
        controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }

    if (anim == 'curl' || anim == 'fade') {
      if (_curl.busy) return;
      unawaited(
        _curl
            .start(
              dir,
              outgoing: _captureSpread,
              advance: jump,
              fade: anim == 'fade',
            )
            .then((ok) {
              if (!ok && mounted) fallback();
            }),
      );
      return;
    }
    fallback();
  }

  void _goToPage(int page) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    controller.jumpToPage(_spreadIndexOf(page.clamp(1, _pageCount)));
  }

  Future<ui.Image?> _captureSpread() async {
    if (!mounted) return null;
    final boundary =
        _pagerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize || boundary.debugNeedsPaint) {
      return null;
    }
    try {
      return await boundary.toImage(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      return null;
    }
  }

  void _onSpreadChanged(int index) {
    if (!mounted) return;
    setState(() {
      _spreadIndex = index;
      _page = index * _spreadSize + 1;
      _pdfSelection = null;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _repo.saveProgress(
        bookId: widget.bookId,
        locator: 'page:$_page',
        percent: _pageCount > 0 ? _page / _pageCount : 0,
        chapterIndex: _page - 1,
      );
    });
  }

  Bookmark? get _currentBookmark {
    final cfi = 'page:$_page';
    for (final b in _bookmarks) {
      if (b.cfi == cfi) return b;
    }
    return null;
  }

  String _pageLabel(int page) {
    String? search(List<EpubTocEntry> entries) {
      String? found;
      for (final e in entries) {
        if (e.href == 'page:$page') return e.label;
        found ??= search(e.children);
      }
      return found;
    }

    return search(_toc) ?? 'Página $page';
  }

  void _toggleBookmark() {
    if (_pageCount == 0) return;
    final repo = ref.read(bookRepositoryProvider);
    final existing = _currentBookmark;
    if (existing != null) {
      repo.deleteBookmark(existing.id);
      _notify('Marcador quitado');
    } else {
      repo.addBookmark(
        bookId: widget.bookId,
        cfi: 'page:$_page',
        chapterIndex: _page - 1,
        percent: _pageCount > 0 ? _page / _pageCount : 0,
        label: _pageLabel(_page),
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

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    final document = _document;
    if (trimmed.length < 2 || document == null) {
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

    final folded = foldForSearch(trimmed);
    final hits = <SearchHit>[];
    for (var n = 1; n <= document.pages.length; n++) {
      if (!mounted || _searchQuery != trimmed) return;
      String text;
      try {
        text = (await document.pages[n - 1].loadText())?.fullText ?? '';
      } catch (_) {
        continue;
      }
      final foldedText = foldForSearch(text);
      var from = 0;
      while (hits.length < 200) {
        final at = foldedText.indexOf(folded, from);
        if (at < 0) break;
        final start = math.max(0, at - 48);
        final end = math.min(text.length, at + folded.length + 48);
        final prefix = start > 0 ? '…' : '';
        final suffix = end < text.length ? '…' : '';
        hits.add(
          SearchHit(
            cfi: 'page:$n',
            excerpt: '$prefix${text.substring(start, end).trim()}$suffix',
          ),
        );
        from = at + folded.length;
      }
      if (hits.length >= 200) break;
    }

    if (!mounted || _searchQuery != trimmed) return;
    setState(() {
      _searchHits = List.unmodifiable(hits);
      _searchBusy = false;
    });
  }

  void _closePanels() {
    setState(() => _showToc = _showAppearance = _showSearch = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _settingsSub?.close();
    _bookmarksSub?.close();
    WakelockPlus.disable();
    _saveProgressNow();
    _highlightsSub?.close();
    _curl.dispose();
    _pageController?.dispose();
    _document?.dispose();
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
          _closePanels();
        } else {
          Navigator.of(context).maybePop();
        }
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final chrome = ReaderChrome.of(_settings.preset);

    if (_error != null) {
      return Scaffold(
        backgroundColor: _settings.preset.background,
        body: _ErrorView(message: _error!, chrome: chrome),
      );
    }
    final book = _book;
    final document = _document;
    if (book == null || document == null) {
      return Scaffold(
        backgroundColor: _settings.preset.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final panelOpen = _showToc || _showSearch;

    return Scaffold(
      backgroundColor: _settings.preset.background,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _applyViewport(constraints.maxWidth);
            if (_pageController == null) {
              _spreadIndex = _spreadIndexOf(_restorePage);
              _pageController = PageController(initialPage: _spreadIndex);
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_showToc || _showAppearance || _showSearch) {
                        _closePanels();
                      } else {
                        setState(() => _chromeVisible = !_chromeVisible);
                        _syncSystemUi();
                      }
                    },
                    child: RepaintBoundary(
                      key: _pagerKey,
                      child: PageView.builder(
                        controller: _pageController,
                        allowImplicitScrolling: true,
                        itemCount: _spreadCount,
                        onPageChanged: _onSpreadChanged,
                        itemBuilder: (context, i) => _spread(document, i),
                      ),
                    ),
                  ),
                ),
                ?_curl.overlay(),
                if (_settings.edgeTaps && !panelOpen) ..._edgeTapZones(),
                ReaderBar(
                  visible: _chromeVisible && !panelOpen,
                  fromTop: true,
                  child: _topBar(book, chrome),
                ),
                ReaderBar(
                  visible: _chromeVisible && !panelOpen,
                  fromTop: false,
                  child: _bottomBar(chrome),
                ),
                ReaderCornerPanel(
                  open: _showAppearance,
                  right: 26,
                  bottom: 58,
                  child: _showAppearance
                      ? AppearancePanel(
                          settings: _settings,
                          onPreset: (p) => ref
                              .read(readerSettingsControllerProvider)
                              .setPreset(p),
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
                          currentHref: 'page:$_page',
                          chapterCount: 0,
                          pageCount: _pageCount,
                          bookmarks: _bookmarks,
                          currentCfi: 'page:$_page',
                          chrome: chrome,
                          onSelect: (entry) {
                            final page = _pageOf(entry.href);
                            if (page != null) _goToPage(page);
                            setState(() => _showToc = false);
                          },
                          onBookmarkSelect: (bookmark) {
                            final page = _pageOf(bookmark.cfi);
                            if (page != null) _goToPage(page);
                            setState(() => _showToc = false);
                          },
                          onBookmarkDelete: (bookmark) => ref
                              .read(bookRepositoryProvider)
                              .deleteBookmark(bookmark.id),
                          highlights: _highlights,
                          highlightColors: _highlightColors,
                          onHighlightSelect: (h) {
                            final page = _pageOf(h.cfi);
                            if (page != null) _goToPage(page);
                            setState(() => _showToc = false);
                          },
                          onHighlightDelete: (h) => ref
                              .read(bookRepositoryProvider)
                              .deleteHighlight(h.id),
                          onClose: () => setState(() => _showToc = false),
                        )
                      : const SizedBox.shrink(),
                ),
                ?_selectionToolbar(chrome),
                ReaderSidePanel(
                  open: _showSearch,
                  child: _showSearch
                      ? SearchPanel(
                          chrome: chrome,
                          hits: _searchHits,
                          busy: _searchBusy,
                          query: _searchQuery,
                          onSubmit: _runSearch,
                          onSelect: (hit) {
                            final page = _pageOf(hit.cfi);
                            if (page != null) _goToPage(page);
                            setState(() => _showSearch = false);
                          },
                          onClose: () => setState(() => _showSearch = false),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int? _pageOf(String href) {
    if (!href.startsWith('page:')) return null;
    final tail = href.substring(5).split('#').first;
    return int.tryParse(tail);
  }

  Widget? _selectionToolbar(ReaderChrome chrome) {
    final sel = _pdfSelection;
    if (sel == null || sel.text.isEmpty) return null;
    final size = MediaQuery.sizeOf(context);
    const w = 236.0;
    const h = 44.0;
    final left = (sel.screenRect.center.dx - w / 2)
        .clamp(8.0, size.width - w - 8)
        .toDouble();
    var top = sel.screenRect.top - h - 10;
    if (top < 60) {
      top = (sel.screenRect.bottom + 10)
          .clamp(60.0, size.height - h - 50)
          .toDouble();
    }
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(sel.encodeCfi()),
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
            height: h,
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
                    onTap: () => _addPdfHighlight(c),
                    child: Padding(
                      padding: const EdgeInsets.all(LannaSpacing.s1 + 2),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: LannaSpacing.s1,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.copy, size: 17, color: chrome.onBarMuted),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: sel.text));
                    _closeSelection();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeSelection() {
    if (_pdfSelection != null) setState(() => _pdfSelection = null);
  }

  void _onBackgroundTap() {
    if (_pdfSelection != null) {
      _closeSelection();
    } else if (_showToc || _showAppearance || _showSearch) {
      _closePanels();
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
      _syncSystemUi();
    }
  }

  void _addPdfHighlight(String color) {
    final sel = _pdfSelection;
    if (sel == null) return;
    ref
        .read(bookRepositoryProvider)
        .addHighlight(
          bookId: widget.bookId,
          cfi: sel.encodeCfi(),
          text: sel.text,
          color: color,
          chapterIndex: sel.page - 1,
          percent: _pageCount > 0 ? sel.page / _pageCount : 0,
        );
    _closeSelection();
  }

  Future<void> _openHighlight(Highlight highlight) async {
    final repo = ref.read(bookRepositoryProvider);
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
    } else if (action == 'note') {
      final controller = TextEditingController(text: highlight.note);
      final note = await showDialog<String>(
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
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
      if (note != null) unawaited(repo.setHighlightNote(highlight.id, note));
    }
  }

  Widget _spread(PdfDocument document, int spreadIndex) {
    final first = spreadIndex * _spreadSize + 1;
    final pages = <int>[
      for (var p = first; p < first + _spreadSize && p <= _pageCount; p++) p,
    ];
    var spreadWidth = 0.0;
    var spreadHeight = 0.0;
    for (final pn in pages) {
      final page = document.pages[pn - 1];
      spreadWidth += page.width;
      spreadHeight = math.max(spreadHeight, page.height);
    }
    if (spreadWidth == 0) return const SizedBox.shrink();

    final safe = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 60 + safe.top, 20, 56 + safe.bottom),
      child: Center(
        child: AspectRatio(
          aspectRatio: spreadWidth / spreadHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pn in pages)
                Expanded(
                  flex: (document.pages[pn - 1].width * 100).round(),
                  child: SelectablePdfPage(
                    document: document,
                    pageNumber: pn,
                    highlights: _highlightsForPage(pn),
                    highlightColors: _highlightColors,
                    selection: _pdfSelection,
                    onSelect: (sel) => setState(() => _pdfSelection = sel),
                    onSelectionEnd: () => setState(() {}),
                    onHighlightTap: _openHighlight,
                    onBackgroundTap: _onBackgroundTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _edgeTapZones() {
    final safe = MediaQuery.viewPaddingOf(context);
    Widget zone(bool isNext) => Positioned(
      top: 60 + safe.top,
      bottom: 56 + safe.bottom,
      left: isNext ? null : 0,
      right: isNext ? 0 : null,
      width: 96,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _turn(isNext ? 1 : -1),
      ),
    );
    return [zone(false), zone(true)];
  }

  Widget _topBar(Book book, ReaderChrome chrome) {
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
                book.author == null
                    ? book.title
                    : '${book.title}  ·  ${book.author}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.reading(fontSize: 13, color: chrome.onBarMuted),
              ),
            ),
            if (_toc.isNotEmpty)
              ReaderBarButton(
                icon: Icons.format_list_bulleted,
                active: _showToc,
                tooltip: 'Índice',
                color: chrome.onBarMuted,
                onTap: () => setState(() {
                  _showToc = !_showToc;
                  _showAppearance = _showSearch = false;
                }),
              ),
            ReaderBarButton(
              label: 'Aa',
              active: _showAppearance,
              tooltip: 'Apariencia',
              color: chrome.onBarMuted,
              onTap: () => setState(() {
                _showAppearance = !_showAppearance;
                _showToc = _showSearch = false;
              }),
            ),
            ReaderBarButton(
              icon: _currentBookmark != null
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              active: _currentBookmark != null,
              tooltip: 'Marcador',
              color: chrome.onBarMuted,
              onTap: _toggleBookmark,
            ),
            ReaderBarButton(
              icon: Icons.search,
              active: _showSearch,
              tooltip: 'Buscar',
              color: chrome.onBarMuted,
              onTap: () => setState(() {
                _showSearch = !_showSearch;
                _showToc = _showAppearance = false;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(ReaderChrome chrome) {
    final style = LannaType.micro.copyWith(color: chrome.onBarMuted);
    final last = math.min(_page + _spreadSize - 1, _pageCount);
    final label = last > _page
        ? 'Páginas $_page–$last de $_pageCount'
        : 'Página $_page de $_pageCount';
    final pct = _pageCount > 0 ? (_page / _pageCount).clamp(0.0, 1.0) : 0.0;

    int pageForFraction(double f) =>
        (f * _pageCount).ceil().clamp(1, math.max(1, _pageCount));

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
            Text(label, style: style),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: ReaderScrubber(
                value: pct,
                chrome: chrome,
                onSeek: (f) => _goToPage(pageForFraction(f)),
                trailingLabel: (f) => '${(f * 100).round()} %',
                bubbleLabel: (f) => 'Pág. ${pageForFraction(f)} de $_pageCount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.chrome});

  final String message;
  final ReaderChrome chrome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: chrome.onBarMuted),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: chrome.onBarMuted)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
