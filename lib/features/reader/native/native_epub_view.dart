// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/epub/epub_book.dart';
import '../../../data/epub/epub_document.dart';
import '../epub_view.dart';
import 'book_source.dart';
import 'page_canvas.dart';
import 'paginator.dart';

class NativeEpubView extends StatefulWidget {
  const NativeEpubView({
    super.key,
    required this.source,
    required this.callbacks,
    this.initialLocator,
    this.initialPercent,
  });

  final NativeBookSource source;
  final EpubViewCallbacks callbacks;
  final String? initialLocator;
  final double? initialPercent;

  @override
  State<NativeEpubView> createState() => _NativeEpubViewState();
}

class _NativeEpubViewState extends State<NativeEpubView>
    implements EpubViewController {
  final GlobalKey _boundary = GlobalKey();
  final GlobalKey<SelectionAreaState> _selectionKey =
      GlobalKey<SelectionAreaState>();

  final Map<int, PaginationJob> _jobs = {};

  PaginationStyle _style = const PaginationStyle();
  PaginationMetrics _metrics = const PaginationMetrics(size: Size.zero);

  Color _background = const Color(0xFF121116);
  Color _foreground = const Color(0xFFE8E4E9);
  Color _link = const Color(0xFFF0876F);

  int _chapter = 0;
  int _page = 0;
  bool _ready = false;
  bool _pumping = false;
  double _insetTop = 0;
  double _insetBottom = 0;
  String _columnMode = 'auto';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    try {
      await widget.source.loadFonts();
    } catch (_) {}
    if (!mounted) return;
    _applyMetrics();

    final locator = ReaderLocator.parse(widget.initialLocator);
    final percent = widget.initialPercent ?? 0;
    final resuming = locator != null || percent > 0.001;

    var opened = locator != null
        ? await _openChapter(locator.chapter, offset: locator.offset)
        : resuming
        ? await _goToPercentage(percent)
        : await _openChapter(0);
    if (!mounted) return;
    if (!opened && resuming) opened = await _openChapter(0);
    if (!mounted) return;

    setState(() => _ready = true);
    widget.callbacks.onReady?.call(this);
    _emitToc();
    _emitLocation();
  }

  void _fail(String context, Object error) {
    if (!mounted) return;
    widget.callbacks.onError?.call('$context\n$error');
  }

  void _emitToc() {
    final toc = <TocEntry>[];
    void walk(List<EpubTocEntry> entries) {
      for (final entry in entries) {
        toc.add(TocEntry(label: entry.label, href: entry.href));
        walk(entry.children);
      }
    }

    walk(widget.source.book.toc);
    if (toc.isNotEmpty) widget.callbacks.onTocLoaded?.call(toc);
  }

  Size _viewport = Size.zero;
  Timer? _resize;

  String get _layoutKey => '${_style.key}#${_metrics.key}';

  void _onViewport(Size size) {
    if (size.isEmpty || size == _viewport) return;
    _viewport = size;
    if (!_ready) return;
    _resize?.cancel();
    _resize = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_relayout()),
    );
  }

  Future<void> _relayout() async {
    if (!mounted) return;
    final offset = _offset;
    final chapter = _chapter;
    final before = _layoutKey;
    _applyMetrics();
    if (_layoutKey == before) return;
    _jobs.clear();
    await _openChapter(chapter, offset: offset);
    _settle();
  }

  void _applyMetrics() {
    final size = _viewport;
    final columns = switch (_columnMode) {
      'single' => 1,
      'double' => 2,
      _ => size.width >= 820 ? 2 : 1,
    };
    _metrics = PaginationMetrics(
      size: size,
      padding: EdgeInsets.fromLTRB(24, _insetTop + 16, 24, _insetBottom + 16),
      columns: columns,
    );
  }

  PaginationJob _jobFor(int chapter, EpubDocument document) {
    final existing = _jobs[chapter];
    if (existing != null) return existing;
    final job = Paginator(
      style: _style,
      metrics: _metrics,
      images: widget.source.imageSize,
    ).jobFor(document);
    _jobs[chapter] = job;
    return job;
  }

  int _navToken = 0;

  Future<bool> _openChapter(
    int chapter, {
    int offset = 0,
    bool last = false,
  }) async {
    final token = ++_navToken;
    if (widget.source.chapterCount == 0) {
      _fail('El libro no tiene capítulos legibles', 'spine vacío');
      return false;
    }
    final clamped = chapter.clamp(0, widget.source.chapterCount - 1);
    final EpubDocument document;
    try {
      document = await widget.source.document(clamped);
    } catch (error) {
      _fail('No se pudo leer el capítulo ${clamped + 1}', error);
      return false;
    }
    if (!mounted || token != _navToken) return false;

    final job = _jobFor(clamped, document);
    // Paginar hasta que la página que contiene `offset` esté cerrada:
    // sin eso pageForOffset devuelve la última página conocida, una antes.
    final reached = await _paginate(
      job,
      token,
      until: last
          ? null
          : () {
              final pages = job.pages;
              return pages.isNotEmpty && pages.last.end > offset;
            },
    );
    if (!reached) return false;

    final page = last
        ? job.pageCount - 1
        : job.snapshot().pageForOffset(offset);

    setState(() {
      _chapter = clamped;
      _page = page.clamp(0, job.pageCount > 0 ? job.pageCount - 1 : 0);
    });
    _evictFar();
    _startPump();
    return true;
  }

  void _evictFar() {
    _jobs.removeWhere((i, _) => (i - _chapter).abs() > 1);
    widget.source.keepNear(_chapter);
  }

  Future<bool> _paginate(
    PaginationJob job,
    int token, {
    bool Function()? until,
    Duration budget = const Duration(milliseconds: 6),
  }) async {
    while (!job.isDone && !(until?.call() ?? false)) {
      job.step(budget: budget);
      if (job.isDone || (until?.call() ?? false)) break;
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || token != _navToken) return false;
    }
    return true;
  }

  void _startPump() {
    if (_pumping) return;
    _pumping = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    while (mounted) {
      final job = _jobs[_chapter];
      if (job == null || job.isDone) break;
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) break;
      if (_animating) break;
      final before = _current;
      job.step(budget: const Duration(milliseconds: 6));
      if (!mounted) break;
      if (!identical(_current, before)) setState(() {});
    }
    _pumping = false;
    if (mounted) {
      final job = _jobs[_chapter];
      if (job != null && job.isDone) {
        widget.callbacks.onPageCount?.call(job.pageCount);
        _emitLocation();
      }
    }
  }

  PaginationJob? get _job => _jobs[_chapter];

  PageLayout? get _current {
    final job = _job;
    if (job == null || job.pageCount == 0) return null;
    return job.pages[_page.clamp(0, job.pageCount - 1)];
  }

  int get _offset => _current?.start ?? 0;

  void _emitLocation() {
    final job = _job;
    final document = widget.source.cached(_chapter);
    if (job == null || document == null) return;
    final atStart = _chapter == 0 && _page == 0;
    final atEnd =
        _chapter == widget.source.chapterCount - 1 &&
        job.isDone &&
        _page >= job.pageCount - 1;
    _schedulePrefetch();
    widget.callbacks.onLocationChanged?.call(
      ReaderLocation(
        cfi: ReaderLocator(chapter: _chapter, offset: _offset).toString(),
        href: widget.source.spine[_chapter].href,
        percentage: widget.source.percentageAt(
          _chapter,
          _offset,
          document.length,
        ),
        chapterIndex: _chapter,
        remainingMinutes: widget.source.remainingMinutes(_chapter, _offset),
        atStart: atStart,
        atEnd: atEnd,
      ),
    );
  }

  Timer? _prefetchTimer;
  int _prefetchRound = 0;

  /// Trae los capitulos vecinos cuando el lector lleva un rato quieto. Abrir
  /// uno cuesta ~17 ms de parseo: dentro de un giro eso es un frame perdido.
  void _schedulePrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_prefetch(++_prefetchRound)),
    );
  }

  Future<void> _prefetch(int round) async {
    final token = _navToken;
    for (final n in [_chapter + 1, _chapter - 1]) {
      if (!mounted || round != _prefetchRound || token != _navToken) return;
      if (_animating) return;
      if (n < 0 || n >= widget.source.chapterCount) continue;
      if (_jobs[n]?.pageCount != null && _jobs[n]!.pageCount > 0) continue;

      final EpubDocument document;
      try {
        document = await widget.source.document(n);
      } catch (_) {
        continue;
      }
      if (!mounted || round != _prefetchRound || token != _navToken) return;

      final job = _jobFor(n, document);
      final ready = await _paginate(
        job,
        token,
        until: () => job.pageCount > 0,
        budget: const Duration(milliseconds: 3),
      );
      if (!ready) return;
    }
  }

  void _settle() {
    widget.callbacks.onRendered?.call();
    _emitLocation();
  }

  @override
  Future<void> next() async {
    final job = _job;
    if (job == null) return;
    final token = _navToken;
    final target = _page + 1;
    if (!await _paginate(job, token, until: () => job.pageCount > target)) {
      return;
    }
    if (_page + 1 < job.pageCount) {
      setState(() => _page++);
      _settle();
      return;
    }
    if (_chapter + 1 < widget.source.chapterCount) {
      await _openChapter(_chapter + 1);
      _settle();
    }
  }

  @override
  Future<void> previous() async {
    if (_page > 0) {
      setState(() => _page--);
      _settle();
      return;
    }
    if (_chapter > 0) {
      await _openChapter(_chapter - 1, last: true);
      _settle();
    }
  }

  @override
  Future<void> goToCfi(String cfi) async {
    final locator = ReaderLocator.parse(cfi);
    if (locator != null) {
      await _openChapter(locator.chapter, offset: locator.offset);
      _settle();
      return;
    }
    if (cfi.startsWith('epubcfi(')) return;

    final chapter = widget.source.chapterForHref(cfi);
    if (chapter == null) return;
    final EpubDocument document;
    try {
      document = await widget.source.document(chapter);
    } catch (error) {
      _fail('No se pudo leer el capítulo ${chapter + 1}', error);
      return;
    }
    if (!mounted) return;
    final hash = cfi.indexOf('#');
    final anchor = hash < 0 ? null : cfi.substring(hash + 1);
    await _openChapter(chapter, offset: document.offsetForAnchor(anchor));
    _settle();
  }

  @override
  Future<void> goToPercentage(double percentage) async {
    await _goToPercentage(percentage);
    _settle();
  }

  Future<bool> _goToPercentage(double percentage) async {
    if (widget.source.chapterCount == 0) {
      _fail('El libro no tiene capítulos legibles', 'spine vacío');
      return false;
    }
    final (chapter, within) = widget.source.locate(percentage);
    final EpubDocument document;
    try {
      document = await widget.source.document(chapter);
    } catch (error) {
      _fail('No se pudo leer el capítulo ${chapter + 1}', error);
      return false;
    }
    if (!mounted) return false;
    return _openChapter(chapter, offset: (document.length * within).round());
  }

  @override
  Future<void> applyPresentation(ReaderPresentation presentation) async {
    final offset = _offset;
    final chapter = _chapter;

    _background = _parseColor(presentation.background, _background);
    _foreground = _parseColor(presentation.foreground, _foreground);
    _link = _parseColor(presentation.link, _link);

    final before = _layoutKey;
    _columnMode = presentation.columnMode;
    _style = PaginationStyle(
      fontFamily: _resolveFamily(presentation.fontFamily),
      monoFamily: 'monospace',
      fontSize: 18 * presentation.fontSizePercent / 100,
      lineHeight: presentation.lineHeight,
    );
    _applyMetrics();

    if (_layoutKey == before) {
      if (mounted) setState(() {});
      return;
    }

    _jobs.clear();
    await _openChapter(chapter, offset: offset);
    _settle();
  }

  bool _animating = false;

  @override
  Future<void> setAnimating(bool value) async {
    if (_animating == value) return;
    _animating = value;
    if (!value) _startPump();
  }

  @override
  Future<void> setInsets(double top, double bottom) async {
    if (_insetTop == top && _insetBottom == bottom) return;
    _insetTop = top;
    _insetBottom = bottom;
    await _relayout();
  }

  @override
  Future<ui.Image?> snapshot() async {
    final object = _boundary.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    if (!object.hasSize || object.debugNeedsPaint) return null;
    try {
      return await object.toImage(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> search(String query) async {
    final needle = query.trim();
    if (needle.length < 2) {
      widget.callbacks.onSearchResults?.call(query, const []);
      return;
    }
    _searchToken++;
    final token = _searchToken;
    final hits = <SearchHit>[];
    final lower = needle.toLowerCase();

    for (var chapter = 0; chapter < widget.source.chapterCount; chapter++) {
      if (!mounted || token != _searchToken) return;
      final borrowed = !widget.source.isCached(chapter);
      final EpubDocument document;
      try {
        document = await widget.source.document(chapter);
      } catch (_) {
        continue;
      }
      if (!mounted || token != _searchToken) return;

      final haystack = document.text.toLowerCase();
      var from = 0;
      while (hits.length < 400) {
        final at = haystack.indexOf(lower, from);
        if (at < 0) break;
        hits.add(
          SearchHit(
            cfi: ReaderLocator(chapter: chapter, offset: at).toString(),
            excerpt: _excerpt(document.text, at, needle.length),
          ),
        );
        from = at + needle.length;
      }
      if (borrowed && chapter != _chapter) widget.source.release(chapter);
      if (hits.length >= 400) break;
      await Future<void>.delayed(Duration.zero);
    }

    if (!mounted || token != _searchToken) return;
    widget.callbacks.onSearchResults?.call(query, hits);
  }

  int _searchToken = 0;

  static String _excerpt(String text, int at, int length) {
    final from = (at - 48).clamp(0, text.length);
    final to = (at + length + 48).clamp(0, text.length);
    final prefix = from > 0 ? '…' : '';
    final suffix = to < text.length ? '…' : '';
    return '$prefix${text.substring(from, to).replaceAll('\n', ' ')}$suffix';
  }

  List<HighlightSpec> _highlights = const [];

  @override
  Future<void> applyHighlights(List<HighlightSpec> highlights) async {
    if (!mounted) return;
    setState(() => _highlights = highlights);
  }

  @override
  Future<void> addHighlight(String cfi, String color) async {
    if (!mounted) return;
    setState(
      () => _highlights = [
        ..._highlights.where((h) => h.cfi != cfi),
        HighlightSpec(cfi: cfi, color: color),
      ],
    );
  }

  @override
  Future<void> removeHighlight(String cfi) async {
    if (!mounted) return;
    setState(
      () => _highlights = _highlights.where((h) => h.cfi != cfi).toList(),
    );
  }

  List<PageHighlight> get _pageHighlights {
    final result = <PageHighlight>[];
    for (final spec in _highlights) {
      final locator = ReaderLocator.parse(spec.cfi);
      if (locator == null || locator.chapter != _chapter) continue;
      if (!locator.isRange) continue;
      result.add(
        PageHighlight(
          cfi: spec.cfi,
          start: locator.offset,
          end: locator.end!,
          color: spec.color,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> clearSelection() async {
    final area = _selectionKey.currentState;
    if (area != null) area.selectableRegion.clearSelection();
    widget.callbacks.onSelectionCleared?.call();
  }

  String? _resolveFamily(String? logical) => switch (logical) {
    'sans' => AppFonts.ui,
    'book' => widget.source.bookFontFamily ?? AppFonts.serif,
    'serif' => AppFonts.serif,
    _ => fontFamilyFromCss(logical) ?? AppFonts.serif,
  };

  static Color _parseColor(String? value, Color fallback) {
    if (value == null) return fallback;
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  void _onSelection(PageSelection? selection) {
    if (selection == null) {
      widget.callbacks.onSelectionCleared?.call();
      return;
    }
    widget.callbacks.onTextSelected?.call(
      ReaderSelection(
        cfi: ReaderLocator(
          chapter: _chapter,
          offset: selection.start,
          end: selection.end,
        ).toString(),
        text: selection.text,
        rect: selection.rect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _onViewport(constraints.biggest);
        return _content();
      },
    );
  }

  Widget _content() {
    final page = _current;
    return RepaintBoundary(
      key: _boundary,
      child: ColoredBox(
        color: _background,
        child: SelectionArea(
          key: _selectionKey,
          contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          child: page == null
              ? const SizedBox.expand()
              : NativePage(
                  key: ValueKey('$_chapter/${page.index}'),
                  page: page,
                  style: _style,
                  metrics: _metrics,
                  source: widget.source,
                  foreground: _foreground,
                  linkColor: _link,
                  highlights: _pageHighlights,
                  onSelection: _onSelection,
                  onHighlightTap: widget.callbacks.onHighlightTapped,
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    _resize?.cancel();
    super.dispose();
  }

  bool get isReady => _ready;
}
