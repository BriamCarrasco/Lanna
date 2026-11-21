// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../data/epub/epub_document.dart';
import '../../../l10n/l10n.dart';
import '../engine_support.dart';
import '../reader_engine.dart';
import 'book_source.dart';
import 'page_canvas.dart';
import 'page_counts.dart';
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
  final ReaderEngineCallbacks callbacks;
  final String? initialLocator;
  final double? initialPercent;

  @override
  State<NativeEpubView> createState() => _NativeEpubViewState();
}

class _NativeEpubViewState extends State<NativeEpubView>
    with EngineHighlights<NativeEpubView>
    implements ReaderEngineController {
  final GlobalKey _boundary = GlobalKey();
  final GlobalKey<SelectionAreaState> _selectionKey =
      GlobalKey<SelectionAreaState>();

  final Map<int, PaginationJob> _jobs = {};

  late PageCounts _counts = PageCounts(widget.source.chapterCount);
  late final PageCountStore _countStore = PageCountStore(
    File(p.join(widget.source.root.path, '.lanna-pages.json')),
  );
  int _countRound = 0;
  int _countingRound = -1;
  bool _countsStored = false;

  PaginationStyle _style = const PaginationStyle();
  PaginationMetrics _metrics = const PaginationMetrics(size: Size.zero);

  Color _background = const Color(0xFF121116);
  Color _foreground = const Color(0xFFE8E4E9);
  Color _link = const Color(0xFFF0876F);

  int _chapter = 0;
  int _page = 0;
  ({int chapter, int offset})? _target;
  bool _ready = false;
  bool _pumping = false;
  double _insetTop = 0;
  double _insetBottom = 0;
  String _columnMode = 'auto';
  bool _pageNumbers = true;

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
    _resetCounts();

    final locator = ReaderLocator.parse(widget.initialLocator);
    final percent = widget.initialPercent ?? 0;
    final resuming = locator != null || percent > 0.001;

    var opened = switch ((locator, resuming)) {
      (final ReaderLocator l, _) => await _openChapter(
        l.chapter,
        offset: l.offset,
      ),
      (_, true) => await _goToPercentage(percent),
      _ => await _openChapter(0),
    };
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
    final toc = widget.source.book.toc;
    if (toc.isNotEmpty) widget.callbacks.onTocLoaded?.call(toc);
  }

  @override
  ReaderCapabilities get capabilities => ReaderCapabilities(
    reflowable: true,
    searchable: true,
    selectable: true,
    bookFontAvailable: widget.source.bookFontFamily != null,
    bookFontUnsupported: widget.source.bookFontUnsupported,
  );

  @override
  bool get rtl => widget.source.rtl;

  @override
  Future<void> setRtl(bool value) async {}

  @override
  int get chapterCount => widget.source.chapterCount;

  @override
  String scrubLabel(double fraction) => '${(fraction * 100).round()} %';

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
    final target = _target;
    final chapter = target?.chapter ?? _chapter;
    final offset = target?.offset ?? _offset;
    final before = _layoutKey;
    _applyMetrics();
    if (_layoutKey == before) return;
    _jobs.clear();
    _resetCounts();
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
      _fail(context.l10n.bookNoChapters, 'empty spine');
      return false;
    }
    final clamped = chapter.clamp(0, widget.source.chapterCount - 1);
    _target = last ? null : (chapter: clamped, offset: offset);
    final EpubDocument document;
    try {
      document = await widget.source.document(clamped);
    } catch (error) {
      if (mounted) _fail(context.l10n.chapterReadError(clamped + 1), error);
      return false;
    }
    if (!mounted || token != _navToken) return false;

    final job = _jobFor(clamped, document);
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
    if (!reached || !mounted) return false;

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
    _harvestCounts();
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
      job.step();
      if (!mounted) break;
      if (!identical(_current, before)) setState(() {});
    }
    _pumping = false;
    if (mounted) {
      final job = _jobs[_chapter];
      if (job != null && job.isDone) {
        _harvestCounts();
        setState(() {});
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
        label: context.l10n.chapterOf(_chapter + 1, widget.source.chapterCount),
        remainingMinutes: widget.source.remainingMinutes(_chapter, _offset),
        atStart: atStart,
        atEnd: atEnd,
      ),
    );
  }

  Timer? _prefetchTimer;
  int _prefetchRound = 0;

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
    unawaited(_countPages());
  }

  void _resetCounts() {
    final round = ++_countRound;
    _counts = PageCounts(widget.source.chapterCount);
    _countsStored = false;
    if (_metrics.size.isEmpty) return;
    unawaited(
      _countStore.read(_layoutKey).then((saved) {
        if (!mounted || round != _countRound || saved == null) return;
        if (!_counts.restore(saved)) return;
        _countsStored = true;
        setState(() {});
      }),
    );
  }

  void _harvestCounts() {
    for (final MapEntry(key: chapter, value: job) in _jobs.entries) {
      if (job.isDone) _counts.record(chapter, job.pageCount);
    }
  }

  int? _pagesOf(int chapter) {
    final known = _counts.of(chapter);
    if (known != null) return known;
    final job = _jobs[chapter];
    return job != null && job.isDone ? math.max(1, job.pageCount) : null;
  }

  bool get _numberReady {
    for (var c = 0; c < _chapter; c++) {
      if (_pagesOf(c) == null) return false;
    }
    return true;
  }

  Future<void> _countPages() async {
    final round = _countRound;
    if (_countingRound == round || _metrics.size.isEmpty) return;
    _countingRound = round;
    final key = _layoutKey;
    bool live() => mounted && round == _countRound;

    var shown = false;
    void reveal() {
      if (shown || !_numberReady) return;
      shown = true;
      setState(() {});
    }

    while (live()) {
      _harvestCounts();
      reveal();
      final chapter = _counts.nextMissing(_chapter);
      if (chapter == null) break;

      var pages = 1;
      try {
        final document = await widget.source.document(chapter);
        if (!live()) return;
        final job =
            _jobs[chapter] ??
            Paginator(
              style: _style,
              metrics: _metrics,
              images: widget.source.imageSize,
            ).jobFor(document);
        while (!job.isDone) {
          if (_animating) {
            await SchedulerBinding.instance.endOfFrame;
          } else {
            await SchedulerBinding.instance.scheduleTask<void>(() {
              final busy = SchedulerBinding.instance.transientCallbackCount > 0;
              job.step(budget: Duration(milliseconds: busy ? 4 : 8));
            }, Priority.animation);
          }
          if (!live()) return;
        }
        pages = job.pageCount;
      } catch (_) {}
      if (!mounted || round != _countRound) return;

      _counts.record(chapter, pages);
      if ((chapter - _chapter).abs() > 2) widget.source.release(chapter);
      reveal();
    }

    if (!mounted || round != _countRound) return;
    setState(() {});
    final counts = _counts.toList();
    if (counts != null && !_countsStored) {
      _countsStored = true;
      unawaited(_countStore.write(key, counts));
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
    final reached = await _paginate(
      job,
      token,
      until: () => job.pageCount > target,
    );
    if (!reached || !mounted) return;
    if (_page + 1 < job.pageCount) {
      _target = null;
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
      _target = null;
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
      if (mounted) _fail(context.l10n.chapterReadError(chapter + 1), error);
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
      _fail(context.l10n.bookNoChapters, 'empty spine');
      return false;
    }
    final (chapter, within) = widget.source.locate(percentage);
    final EpubDocument document;
    try {
      document = await widget.source.document(chapter);
    } catch (error) {
      if (mounted) _fail(context.l10n.chapterReadError(chapter + 1), error);
      return false;
    }
    if (!mounted) return false;
    return _openChapter(chapter, offset: (document.length * within).round());
  }

  @override
  Future<void> applyPresentation(ReaderPresentation presentation) async {
    final target = _target;
    final chapter = target?.chapter ?? _chapter;
    final offset = target?.offset ?? _offset;

    _background = parseCssColor(presentation.background, _background);
    _foreground = parseCssColor(presentation.foreground, _foreground);
    _link = parseCssColor(presentation.link, _link);
    _pageNumbers = presentation.pageNumbers;

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
    _resetCounts();
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
  Future<ui.Image?> snapshot() => captureBoundary(_boundary, context);

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

  List<PageHighlight> get _pageHighlights {
    final result = <PageHighlight>[];
    for (final spec in highlights) {
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            SelectionArea(
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
            if (page != null) ..._pageFooter(page),
          ],
        ),
      ),
    );
  }

  List<Widget> _pageFooter(PageLayout page) {
    if (!_pageNumbers) return const [];
    final number = pageNumber(
      chapter: _chapter,
      pageInChapter: page.index,
      chapterCount: widget.source.chapterCount,
      pagesOf: _pagesOf,
    );
    if (number == null) return const [];

    final style = TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 11.5,
      height: 1,
      color: _foreground.withValues(alpha: 0.45),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final metrics = _metrics;
    final bottom = (metrics.padding.bottom / 2 - 6).clamp(6.0, 200.0);
    if (metrics.columns <= 1) {
      return [
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: Text(
            number.total == null
                ? '${number.current}'
                : '${number.current} / ${number.total}',
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ];
    }
    final used = {for (final f in page.fragments) f.column};
    return [
      for (var column = 0; column < metrics.columns; column++)
        if (used.contains(column))
          Positioned(
            left:
                metrics.padding.left +
                (widget.source.rtl ? metrics.columns - 1 - column : column) *
                    (metrics.columnWidth + metrics.columnGap),
            width: metrics.columnWidth,
            bottom: bottom,
            child: Text(
              '${(number.current - 1) * metrics.columns + column + 1}',
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
    ];
  }

  @override
  void dispose() {
    _countRound++;
    _prefetchTimer?.cancel();
    _resize?.cancel();
    super.dispose();
  }

  bool get isReady => _ready;
}
