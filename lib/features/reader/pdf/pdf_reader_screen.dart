// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/text_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/book_repository.dart';
import '../../../data/epub/epub_book.dart';
import '../../../data/local/app_database.dart';
import '../epub_view.dart';
import '../reader_settings_provider.dart';
import '../reader_theme.dart';
import '../widgets/appearance_panel.dart';
import '../widgets/reader_bar_button.dart';
import '../widgets/search_panel.dart';
import '../widgets/toc_drawer.dart';

const _spreadMinWidth = 820.0;

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  final _focusNode = FocusNode();
  PageController? _pageController;
  PdfDocument? _document;

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
  List<SearchHit> _searchHits = const [];
  bool _searchBusy = false;
  String _searchQuery = '';

  ReaderSettings _settings = const ReaderSettings();

  Timer? _saveTimer;
  ProviderSubscription<AsyncValue<ReaderSettings>>? _settingsSub;
  ProviderSubscription<AsyncValue<List<Bookmark>>>? _bookmarksSub;

  @override
  void initState() {
    super.initState();
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
    _bookmarksSub = ref.listenManual(
      bookmarksProvider(widget.bookId),
      (_, next) {
        final list = next.valueOrNull;
        if (list == null || !mounted) return;
        setState(() => _bookmarks = list);
      },
      fireImmediately: true,
    );
    _load();
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
      document = await PdfDocument.openFile(book.filePath);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo abrir el PDF');
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
    final controller = _pageController;
    if (controller == null || !controller.hasClients || _spreadCount == 0) {
      return;
    }
    final target = (_spreadIndex + dir).clamp(0, _spreadCount - 1);
    if (target == _spreadIndex) return;
    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToPage(int page) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    controller.jumpToPage(_spreadIndexOf(page.clamp(1, _pageCount)));
  }

  void _onSpreadChanged(int index) {
    if (!mounted) return;
    setState(() {
      _spreadIndex = index;
      _page = index * _spreadSize + 1;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(bookRepositoryProvider)
          .saveProgress(
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
    _settingsSub?.close();
    _bookmarksSub?.close();
    _saveTimer?.cancel();
    WakelockPlus.disable();
    if (_pageCount > 0) {
      ref
          .read(bookRepositoryProvider)
          .saveProgress(
            bookId: widget.bookId,
            locator: 'page:$_page',
            percent: _page / _pageCount,
            chapterIndex: _page - 1,
          );
    }
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
                      }
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      allowImplicitScrolling: true,
                      itemCount: _spreadCount,
                      onPageChanged: _onSpreadChanged,
                      itemBuilder: (context, i) => _spread(document, i),
                    ),
                  ),
                ),
                if (_settings.edgeTaps && !panelOpen) ..._edgeTapZones(),
                if (_chromeVisible && !panelOpen) _topBar(book, chrome),
                if (_chromeVisible && !panelOpen) _bottomBar(chrome),
                if (_showAppearance)
                  Positioned(
                    right: 26,
                    bottom: 58,
                    child: AppearancePanel(
                      settings: _settings,
                      onPreset: (p) => ref
                          .read(readerSettingsControllerProvider)
                          .setPreset(p),
                      onColumns: (m) => ref
                          .read(readerSettingsControllerProvider)
                          .setColumns(m),
                    ),
                  ),
                if (_showToc)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: TocDrawer(
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
                      onClose: () => setState(() => _showToc = false),
                    ),
                  ),
                if (_showSearch)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SearchPanel(
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
                    ),
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
    return int.tryParse(href.substring(5));
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 56),
      child: Center(
        child: AspectRatio(
          aspectRatio: spreadWidth / spreadHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pn in pages)
                Expanded(
                  flex: (document.pages[pn - 1].width * 100).round(),
                  child: PdfPageView(
                    document: document,
                    pageNumber: pn,
                    alignment: Alignment.center,
                    backgroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _edgeTapZones() {
    Widget zone(bool isNext) => Positioned(
      top: 60,
      bottom: 56,
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: chrome.barBackground.withValues(alpha: 0.94),
          border: Border(bottom: BorderSide(color: chrome.barBorder)),
        ),
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
                style: AppTheme.reading(
                  fontSize: 13.5,
                  color: chrome.onBarMuted,
                ),
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
    final style = TextStyle(
      fontSize: 11.5,
      color: chrome.onBarMuted,
      fontFamily: AppFonts.ui,
    );
    final last = math.min(_page + _spreadSize - 1, _pageCount);
    final label = last > _page
        ? 'Páginas $_page–$last de $_pageCount'
        : 'Página $_page de $_pageCount';
    final pct = _pageCount > 0 ? (_page / _pageCount).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: chrome.barBackground.withValues(alpha: 0.94),
          border: Border(top: BorderSide(color: chrome.barBorder)),
        ),
        child: Row(
          children: [
            Text(label, style: style),
            const SizedBox(width: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3,
                  backgroundColor: chrome.progressTrack,
                  valueColor: const AlwaysStoppedAnimation(ReaderChrome.accent),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text('${(pct * 100).round()} %', style: style),
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
