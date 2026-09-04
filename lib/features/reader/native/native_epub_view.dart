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
    await widget.source.loadFonts();
    if (!mounted) return;
    _applyMetrics();
    final locator = ReaderLocator.parse(widget.initialLocator);
    if (locator != null) {
      await _openChapter(locator.chapter, offset: locator.offset);
    } else {
      final percent = widget.initialPercent ?? 0;
      if (percent > 0.001) {
        await _goToPercentage(percent);
      } else {
        await _openChapter(0);
      }
    }
    if (!mounted) return;
    setState(() => _ready = true);
    widget.callbacks.onReady?.call(this);
    _emitToc();
    _emitLocation();
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

  void _applyMetrics() {
    final size = MediaQuery.sizeOf(context);
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

  Future<void> _openChapter(
    int chapter, {
    int offset = 0,
    bool last = false,
  }) async {
    final clamped = chapter.clamp(0, widget.source.chapterCount - 1);
    final document = await widget.source.document(clamped);
    if (!mounted) return;

    final job = _jobFor(clamped, document);
    if (last) {
      job.run();
    } else {
      // Paginar hasta que la página que contiene `offset` esté cerrada:
      // sin eso pageForOffset devuelve la última página conocida, una antes.
      while (!job.isDone) {
        final pages = job.pages;
        if (pages.isNotEmpty && pages.last.end > offset) break;
        job.step(budget: const Duration(milliseconds: 6));
      }
    }

    final page = last
        ? (job.pageCount - 1).clamp(0, job.pageCount)
        : job.snapshot().pageForOffset(offset);

    setState(() {
      _chapter = clamped;
      _page = page.clamp(0, job.pageCount > 0 ? job.pageCount - 1 : 0);
    });
    _startPump();
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
      job.step(budget: const Duration(milliseconds: 6));
      if (!mounted) break;
      setState(() {});
    }
    _pumping = false;
    if (mounted) {
      final job = _jobs[_chapter];
      if (job != null && job.isDone) {
        widget.callbacks.onPageCount?.call(job.pageCount);
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
        atStart: atStart,
        atEnd: atEnd,
      ),
    );
  }

  void _settle() {
    widget.callbacks.onRendered?.call();
    _emitLocation();
  }

  @override
  Future<void> next() async {
    final job = _job;
    if (job == null) return;
    while (!job.isDone && job.pageCount <= _page + 1) {
      job.step(budget: const Duration(milliseconds: 6));
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
    final document = await widget.source.document(chapter);
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

  Future<void> _goToPercentage(double percentage) async {
    final (chapter, within) = widget.source.locate(percentage);
    final document = await widget.source.document(chapter);
    if (!mounted) return;
    await _openChapter(chapter, offset: (document.length * within).round());
  }

  @override
  Future<void> applyPresentation(ReaderPresentation presentation) async {
    final offset = _offset;
    final chapter = _chapter;

    _background = _parseColor(presentation.background, _background);
    _foreground = _parseColor(presentation.foreground, _foreground);
    _link = _parseColor(presentation.link, _link);
    _columnMode = presentation.columnMode;
    _style = PaginationStyle(
      fontFamily: _resolveFamily(presentation.fontFamily),
      monoFamily: 'monospace',
      fontSize: 18 * presentation.fontSizePercent / 100,
      lineHeight: presentation.lineHeight,
    );
    _applyMetrics();
    _jobs.clear();
    await _openChapter(chapter, offset: offset);
    _settle();
  }

  @override
  Future<void> setInsets(double top, double bottom) async {
    if (_insetTop == top && _insetBottom == bottom) return;
    final offset = _offset;
    final chapter = _chapter;
    _insetTop = top;
    _insetBottom = bottom;
    _applyMetrics();
    _jobs.clear();
    await _openChapter(chapter, offset: offset);
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
  Future<void> loadLocations(String json) async {}

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
      final document = await widget.source.document(chapter);
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

  bool get isReady => _ready;
}
