// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../data/epub/epub_document.dart';
import 'book_source.dart';
import 'paginator.dart';

class PageSelection {
  const PageSelection({
    required this.start,
    required this.end,
    required this.text,
    required this.rect,
  });

  final int start;
  final int end;
  final String text;
  final Rect rect;
}

class PageHighlight {
  const PageHighlight({
    required this.cfi,
    required this.start,
    required this.end,
    required this.color,
  });

  final String cfi;
  final int start;
  final int end;
  final String color;
}

const _highlightColors = <String, Color>{
  'yellow': Color(0xFFFFE14D),
  'green': Color(0xFF8FE08A),
  'blue': Color(0xFF7FC0FF),
  'pink': Color(0xFFFF9EC9),
};

class NativePage extends StatefulWidget {
  const NativePage({
    super.key,
    required this.page,
    required this.style,
    required this.metrics,
    required this.source,
    required this.foreground,
    required this.linkColor,
    this.highlights = const [],
    this.onSelection,
    this.onHighlightTap,
  });

  final PageLayout page;
  final PaginationStyle style;
  final PaginationMetrics metrics;
  final NativeBookSource source;
  final Color foreground;
  final Color linkColor;
  final List<PageHighlight> highlights;
  final ValueChanged<PageSelection?>? onSelection;
  final ValueChanged<String>? onHighlightTap;

  @override
  State<NativePage> createState() => _NativePageState();
}

class _NativePageState extends State<NativePage> {
  final List<SelectionListenerNotifier> _notifiers = [];
  final List<GlobalKey> _keys = [];
  final Map<String, TapGestureRecognizer> _taps = {};

  @override
  void initState() {
    super.initState();
    _buildNotifiers();
    _syncTaps();
  }

  @override
  void didUpdateWidget(NativePage old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _disposeNotifiers();
      _buildNotifiers();
    }
    _syncTaps();
  }

  @override
  void dispose() {
    _disposeNotifiers();
    for (final tap in _taps.values) {
      tap.dispose();
    }
    _taps.clear();
    super.dispose();
  }

  void _buildNotifiers() {
    for (var i = 0; i < widget.page.fragments.length; i++) {
      final notifier = SelectionListenerNotifier();
      notifier.addListener(_onSelectionChanged);
      _notifiers.add(notifier);
      _keys.add(GlobalKey());
    }
  }

  void _disposeNotifiers() {
    for (final notifier in _notifiers) {
      notifier.removeListener(_onSelectionChanged);
      notifier.dispose();
    }
    _notifiers.clear();
    _keys.clear();
  }

  void _syncTaps() {
    final wanted = {for (final h in widget.highlights) h.cfi};
    for (final cfi in _taps.keys.toList()) {
      if (wanted.contains(cfi)) continue;
      _taps.remove(cfi)!.dispose();
    }
    for (final cfi in wanted) {
      _taps.putIfAbsent(
        cfi,
        () =>
            TapGestureRecognizer()
              ..onTap = () => widget.onHighlightTap?.call(cfi),
      );
    }
  }

  PageHighlight? _highlightAt(int offset) {
    for (final highlight in widget.highlights) {
      if (offset >= highlight.start && offset < highlight.end) return highlight;
    }
    return null;
  }

  List<InlineRun> _splitByHighlights(List<InlineRun> runs) {
    if (widget.highlights.isEmpty) return runs;
    final cuts = <int>{};
    for (final highlight in widget.highlights) {
      cuts.add(highlight.start);
      cuts.add(highlight.end);
    }
    final result = <InlineRun>[];
    for (final run in runs) {
      final points = <int>[run.start, run.end];
      for (final cut in cuts) {
        if (cut > run.start && cut < run.end) points.add(cut);
      }
      points.sort();
      for (var i = 0; i + 1 < points.length; i++) {
        result.addAll(sliceRuns([run], points[i], points[i + 1]));
      }
    }
    return result;
  }

  void _onSelectionChanged() {
    final report = widget.onSelection;
    if (report == null) return;

    int? start;
    int? end;
    Rect? bounds;

    for (var i = 0; i < _notifiers.length; i++) {
      final notifier = _notifiers[i];
      if (!notifier.registered) continue;
      final details = notifier.selection;
      if (details.status != SelectionStatus.uncollapsed) continue;
      final range = details.range;
      if (range == null) continue;

      final fragment = widget.page.fragments[i];
      final from = fragment.start + range.startOffset;
      final to = fragment.start + range.endOffset;
      final low = from < to ? from : to;
      final high = from < to ? to : from;
      start = start == null || low < start ? low : start;
      end = end == null || high > end ? high : end;

      final box = _keys[i].currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final origin = box.localToGlobal(Offset.zero);
        final rect = origin & box.size;
        bounds = bounds == null ? rect : bounds.expandToInclude(rect);
      }
    }

    if (start == null || end == null || start == end) {
      report(null);
      return;
    }

    report(
      PageSelection(
        start: start,
        end: end,
        text: _textBetween(start, end),
        rect: bounds ?? Rect.zero,
      ),
    );
  }

  String _textBetween(int start, int end) {
    final buffer = StringBuffer();
    for (final fragment in widget.page.fragments) {
      if (fragment.end <= start || fragment.start >= end) continue;
      for (final run in sliceRuns(fragment.runs, start, end)) {
        buffer.write(run.text);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    return Padding(
      padding: metrics.padding,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.page.fragments.length; i++)
            Positioned(
              left: _fullBleed(i) ? 0 : _leftOf(widget.page.fragments[i]),
              top: widget.page.fragments[i].top,
              width: _fullBleed(i)
                  ? metrics.size.width - metrics.padding.horizontal
                  : metrics.columnWidth -
                        widget.style.listInset(widget.page.fragments[i].block),
              height: widget.page.fragments[i].height,
              child: _fragment(widget.page.fragments[i], i),
            ),
        ],
      ),
    );
  }

  double _leftOf(PageFragment fragment) {
    final metrics = widget.metrics;
    final slot = metrics.columnWidth + metrics.columnGap;
    final column = widget.source.rtl
        ? metrics.columns - 1 - fragment.column
        : fragment.column;
    final inset = widget.source.rtl
        ? 0.0
        : widget.style.listInset(fragment.block);
    return column * slot + inset;
  }

  bool _fullBleed(int index) {
    final fragment = widget.page.fragments[index];
    return widget.page.fragments.length == 1 &&
        fragment.block.kind == BlockKind.image &&
        (fragment.imageSize?.width ?? 0) > widget.metrics.columnWidth;
  }

  Widget _fragment(PageFragment fragment, int index) {
    switch (fragment.block.kind) {
      case BlockKind.separator:
        return Center(
          child: SizedBox(
            width: widget.metrics.columnWidth * 0.3,
            child: Divider(color: widget.foreground.withValues(alpha: 0.35)),
          ),
        );
      case BlockKind.image:
        return _image(fragment);
      case BlockKind.listItem:
        return Row(
          textDirection: directionOf(fragment.block),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.style.listGutter(fragment.block),
              child: fragment.continuesBefore
                  ? null
                  : SelectionContainer.disabled(
                      child: Text(
                        widget.style.markerFor(fragment.block),
                        textAlign: TextAlign.end,
                        textDirection: directionOf(fragment.block),
                        textScaler: TextScaler.noScaling,
                        style: widget.style
                            .baseStyleFor(fragment.block)
                            .copyWith(
                              color: widget.foreground.withValues(alpha: 0.7),
                            ),
                      ),
                    ),
            ),
            Expanded(child: _text(fragment, index)),
          ],
        );
      default:
        return _text(fragment, index);
    }
  }

  Widget _text(PageFragment fragment, int index) {
    return SelectionListener(
      selectionNotifier: _notifiers[index],
      child: Text.rich(
        TextSpan(
          children: [
            for (final run in _splitByHighlights(fragment.runs))
              _span(fragment, run),
          ],
        ),
        key: _keys[index],
        textAlign: widget.style.alignFor(fragment.block),
        textDirection: directionOf(fragment.block),
        textScaler: TextScaler.noScaling,
        strutStyle: StrutStyle(
          fontFamily: widget.style.baseStyleFor(fragment.block).fontFamily,
          fontSize: widget.style.sizeFor(fragment.block),
          height: widget.style.lineHeight,
          forceStrutHeight: true,
        ),
      ),
    );
  }

  TextSpan _span(PageFragment fragment, InlineRun run) {
    final highlight = _highlightAt(run.start);
    final tint = highlight == null
        ? null
        : _highlightColors[highlight.color] ?? _highlightColors['yellow']!;
    return TextSpan(
      text: run.text,
      recognizer: highlight == null ? null : _taps[highlight.cfi],
      style: widget.style
          .styleForRun(fragment.block, run)
          .copyWith(
            color: tint != null
                ? const Color(0xFF14121A)
                : (run.href == null ? widget.foreground : widget.linkColor),
            backgroundColor: tint,
          ),
    );
  }

  Widget _image(PageFragment fragment) {
    final src = fragment.block.src;
    final size = fragment.imageSize;
    if (src == null || size == null) return const SizedBox.shrink();
    if (!widget.source.hasFile(src)) {
      return Center(
        child: Text(
          fragment.block.alt ?? '',
          style: TextStyle(
            color: widget.foreground.withValues(alpha: 0.5),
            fontSize: widget.style.fontSize * 0.8,
          ),
        ),
      );
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Center(
      child: Image.file(
        widget.source.fileFor(src),
        width: size.width,
        height: size.height,
        cacheWidth: math.max(1, (size.width * ratio).round()),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
