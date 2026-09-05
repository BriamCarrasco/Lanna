// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../data/epub/epub_document.dart';

typedef ImageSizeResolver = Size? Function(String src);

ui.TextDirection directionOf(DocBlock block) =>
    block.rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr;

String? fontFamilyFromCss(String? css) {
  if (css == null) return null;
  for (final part in css.split(',')) {
    final name = part.trim().replaceAll('"', '').replaceAll("'", '');
    if (name.isEmpty) continue;
    if (const {
      'serif',
      'sans-serif',
      'system-ui',
      'monospace',
      'cursive',
      'fantasy',
      'ui-serif',
      'ui-sans-serif',
      'ui-monospace',
    }.contains(name.toLowerCase())) {
      continue;
    }
    return name;
  }
  return null;
}

class PaginationStyle {
  const PaginationStyle({
    this.fontFamily,
    this.monoFamily,
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.justify = true,
  });

  final String? fontFamily;
  final String? monoFamily;
  final double fontSize;
  final double lineHeight;
  final bool justify;

  static const _headingScale = {
    1: 1.6,
    2: 1.42,
    3: 1.26,
    4: 1.14,
    5: 1.06,
    6: 1.0,
  };

  double sizeFor(DocBlock block) => switch (block.kind) {
    BlockKind.heading => fontSize * (_headingScale[block.level] ?? 1.0),
    BlockKind.preformatted => fontSize * 0.88,
    _ => fontSize,
  };

  TextStyle baseStyleFor(DocBlock block) {
    final size = sizeFor(block);
    return TextStyle(
      fontFamily: block.kind == BlockKind.preformatted
          ? monoFamily
          : fontFamily,
      fontSize: size,
      height: lineHeight,
      fontWeight: block.kind == BlockKind.heading
          ? FontWeight.w600
          : FontWeight.w400,
      fontStyle: block.kind == BlockKind.quote
          ? FontStyle.italic
          : FontStyle.normal,
    );
  }

  TextStyle styleForRun(DocBlock block, InlineRun run) {
    var style = baseStyleFor(block);
    if (run.marks.contains(InlineMark.bold)) {
      style = style.copyWith(fontWeight: FontWeight.w700);
    }
    if (run.marks.contains(InlineMark.italic)) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (run.marks.contains(InlineMark.code)) {
      style = style.copyWith(fontFamily: monoFamily);
    }
    if (run.marks.contains(InlineMark.superscript) ||
        run.marks.contains(InlineMark.subscript)) {
      style = style.copyWith(fontSize: style.fontSize! * 0.72);
    }
    return style;
  }

  TextAlign alignFor(DocBlock block) {
    if (block.kind == BlockKind.preformatted) return TextAlign.left;
    return switch (block.align) {
      BlockAlign.center => TextAlign.center,
      BlockAlign.end => TextAlign.end,
      BlockAlign.justify => TextAlign.justify,
      BlockAlign.start =>
        justify && block.kind == BlockKind.paragraph
            ? TextAlign.justify
            : TextAlign.start,
    };
  }

  double spacingBefore(DocBlock block, DocBlock? previous) {
    if (previous == null) return 0;
    final ems = switch (block.kind) {
      BlockKind.heading => 1.2,
      BlockKind.image => 0.9,
      BlockKind.quote => 0.8,
      BlockKind.separator => 1.0,
      BlockKind.listItem => previous.kind == BlockKind.listItem ? 0.25 : 0.7,
      _ => previous.kind == BlockKind.heading ? 0.45 : 0.7,
    };
    return ems * fontSize;
  }

  double get separatorHeight => fontSize * 1.4;

  double listInset(DocBlock block) => block.kind == BlockKind.listItem
      ? fontSize * 1.2 * (math.max(1, block.level) - 1)
      : 0;

  double listGutter(DocBlock block) =>
      block.kind == BlockKind.listItem ? fontSize * 1.7 : 0;

  double textIndent(DocBlock block) => listInset(block) + listGutter(block);

  String markerFor(DocBlock block) {
    if (block.kind != BlockKind.listItem) return '';
    if (block.listOrdered) return '${block.listIndex}.';
    return switch (math.max(1, block.level)) {
      1 => '•',
      2 => '◦',
      _ => '▪',
    };
  }

  String get key => '$fontFamily|$monoFamily|$fontSize|$lineHeight|$justify';
}

class PaginationMetrics {
  const PaginationMetrics({
    required this.size,
    this.padding = const EdgeInsets.all(24),
    this.columns = 1,
    this.columnGap = 40,
  });

  final Size size;
  final EdgeInsets padding;
  final int columns;
  final double columnGap;

  double get columnHeight => size.height - padding.vertical;

  double get columnWidth {
    final usable = size.width - padding.horizontal;
    if (columns <= 1) return usable;
    return (usable - columnGap * (columns - 1)) / columns;
  }

  String get key => '${size.width}x${size.height}|$padding|$columns|$columnGap';
}

class PageFragment {
  const PageFragment({
    required this.block,
    required this.column,
    required this.start,
    required this.end,
    required this.top,
    required this.height,
    this.continuesBefore = false,
    this.continuesAfter = false,
    this.imageSize,
  });

  final DocBlock block;
  final int column;
  final int start;
  final int end;
  final double top;
  final double height;
  final bool continuesBefore;
  final bool continuesAfter;
  final Size? imageSize;

  bool get isPartial => continuesBefore || continuesAfter;

  List<InlineRun> get runs => sliceRuns(block.runs, start, end);

  @override
  String toString() =>
      'PageFragment(${block.kind.name}, col $column, $start..$end)';
}

class PageLayout {
  const PageLayout({
    required this.index,
    required this.spineIndex,
    required this.start,
    required this.end,
    required this.fragments,
  });

  final int index;
  final int spineIndex;
  final int start;
  final int end;
  final List<PageFragment> fragments;

  bool get isEmpty => fragments.isEmpty;

  bool contains(int offset) =>
      offset >= start && (offset < end || (start == end && offset == start));

  @override
  String toString() => 'PageLayout($index, $start..$end)';
}

class DocumentPagination {
  const DocumentPagination({
    required this.spineIndex,
    required this.length,
    required this.pages,
    required this.key,
  });

  final int spineIndex;
  final int length;
  final List<PageLayout> pages;
  final String key;

  int get pageCount => pages.length;

  int pageForOffset(int offset) {
    if (pages.isEmpty) return 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].contains(offset)) return i;
    }
    return offset < pages.first.start ? 0 : pages.length - 1;
  }
}

List<InlineRun> sliceRuns(List<InlineRun> runs, int start, int end) {
  final result = <InlineRun>[];
  for (final run in runs) {
    if (run.end <= start) continue;
    if (run.start >= end) break;
    final from = math.max(run.start, start);
    final to = math.min(run.end, end);
    if (to <= from) continue;
    result.add(
      InlineRun(
        text: run.text.substring(from - run.start, to - run.start),
        start: from,
        marks: run.marks,
        href: run.href,
      ),
    );
  }
  return result;
}

class Paginator {
  Paginator({
    required this.style,
    required this.metrics,
    this.images,
    this.textScaler = TextScaler.noScaling,
    this.chunkChars = defaultChunkChars,
  });

  static const int defaultChunkChars = 4000;

  final PaginationStyle style;
  final PaginationMetrics metrics;
  final ImageSizeResolver? images;
  final TextScaler textScaler;
  final int chunkChars;

  PaginationJob jobFor(EpubDocument document) => PaginationJob(
    document: document,
    style: style,
    metrics: metrics,
    images: images,
    textScaler: textScaler,
    chunkChars: chunkChars,
  );

  DocumentPagination paginate(EpubDocument document) =>
      jobFor(document).finish();
}

class _LineBox {
  const _LineBox(this.start, this.end, this.height);
  final int start;
  final int end;
  final double height;
}

class _BlockCursor {
  _BlockCursor(this.block);

  final DocBlock block;
  final List<_LineBox> lines = [];
  int lineIndex = 0;
  int segmentStart = 0;
  bool measured = false;
  bool placedAny = false;

  bool get drained => measured && lineIndex >= lines.length;
}

class PaginationJob {
  PaginationJob({
    required this.document,
    required this.style,
    required this.metrics,
    this.images,
    this.textScaler = TextScaler.noScaling,
    this.chunkChars = Paginator.defaultChunkChars,
  });

  final EpubDocument document;
  final PaginationStyle style;
  final PaginationMetrics metrics;
  final ImageSizeResolver? images;
  final TextScaler textScaler;
  final int chunkChars;

  final List<PageLayout> _pages = [];
  final List<PageFragment> _fragments = [];

  int _blockIndex = 0;
  DocBlock? _previous;
  _BlockCursor? _cursorBlock;

  int _column = 0;
  double _y = 0;
  int _pageStart = 0;
  int _offset = 0;
  bool _finished = false;

  List<PageLayout> get pages => _pages;

  int get pageCount => _pages.length;

  bool get isDone => _finished;

  int get coveredOffset => _offset;

  double get columnWidth => metrics.columnWidth;

  double get columnHeight => metrics.columnHeight;

  void run() {
    while (!_finished) {
      step(budget: const Duration(days: 1));
    }
  }

  void step({Duration budget = const Duration(milliseconds: 6)}) {
    if (_finished) return;
    final watch = Stopwatch()..start();

    while (true) {
      final cursor = _cursorBlock;
      if (cursor == null) {
        if (_blockIndex >= document.blocks.length) {
          _closePage();
          if (_pages.isEmpty) {
            _pages.add(
              PageLayout(
                index: 0,
                spineIndex: document.spineIndex,
                start: 0,
                end: document.length,
                fragments: const [],
              ),
            );
          }
          _finished = true;
          return;
        }
        final block = document.blocks[_blockIndex];
        _blockIndex++;
        if (block.kind == BlockKind.pageBreak) continue;

        final gap = style.spacingBefore(block, _previous);
        _previous = block;

        switch (block.kind) {
          case BlockKind.separator:
            _placeSolid(block, gap, style.separatorHeight);
          case BlockKind.image:
            final size = _imageSize(block);
            _placeSolid(block, gap, size.height, imageSize: size);
          default:
            _cursorBlock = _BlockCursor(block);
            _pendingGap = gap;
        }
      } else {
        _placeLines(cursor);
        if (cursor.drained) _cursorBlock = null;
      }

      if (watch.elapsed >= budget) return;
    }
  }

  double _pendingGap = 0;

  DocumentPagination finish() {
    run();
    return DocumentPagination(
      spineIndex: document.spineIndex,
      length: document.length,
      pages: List.unmodifiable(_pages),
      key: '${style.key}#${metrics.key}',
    );
  }

  DocumentPagination snapshot() => DocumentPagination(
    spineIndex: document.spineIndex,
    length: document.length,
    pages: List.unmodifiable(_pages),
    key: '${style.key}#${metrics.key}',
  );

  void _placeSolid(
    DocBlock block,
    double gap,
    double height, {
    Size? imageSize,
  }) {
    final needed = (_y == 0 ? 0.0 : gap) + height;
    if (_y + needed > columnHeight && _y > 0) _breakColumn();
    final top = _y + (_y == 0 ? 0.0 : gap);
    _fragments.add(
      PageFragment(
        block: block,
        column: _column,
        start: block.start,
        end: block.end,
        top: top,
        height: height,
        imageSize: imageSize,
      ),
    );
    _y = top + height;
    _offset = block.end;
  }

  void _placeLines(_BlockCursor cursor) {
    _ensureLines(cursor, cursor.lineIndex + 1);
    if (cursor.drained) return;

    final leading = !cursor.placedAny && _y > 0 ? _pendingGap : 0.0;
    final top = _y + leading;
    var height = 0.0;
    final from = cursor.lineIndex;

    while (true) {
      _ensureLines(cursor, cursor.lineIndex + 1);
      if (cursor.lineIndex >= cursor.lines.length) break;
      final line = cursor.lines[cursor.lineIndex];
      if (top + height + line.height > columnHeight && (height > 0 || _y > 0)) {
        break;
      }
      height += line.height;
      cursor.lineIndex++;
    }

    if (cursor.lineIndex == from) {
      _breakColumn();
      cursor.placedAny = true;
      return;
    }

    final last = cursor.lines[cursor.lineIndex - 1];
    _fragments.add(
      PageFragment(
        block: cursor.block,
        column: _column,
        start: cursor.lines[from].start,
        end: last.end,
        top: top,
        height: height,
        continuesBefore: from > 0,
        continuesAfter: !cursor.drained,
      ),
    );
    _y = top + height;
    _offset = last.end;
    cursor.placedAny = true;

    if (!cursor.drained) _breakColumn();
  }

  void _breakColumn() {
    _column++;
    _y = 0;
    if (_column >= metrics.columns) _closePage();
  }

  void _closePage() {
    if (_fragments.isEmpty) {
      _column = 0;
      _y = 0;
      return;
    }
    _pages.add(
      PageLayout(
        index: _pages.length,
        spineIndex: document.spineIndex,
        start: _pageStart,
        end: _offset,
        fragments: List.unmodifiable(_fragments),
      ),
    );
    _fragments.clear();
    _pageStart = _offset;
    _column = 0;
    _y = 0;
  }

  bool get _soleImageDocument =>
      document.blocks.length == 1 &&
      document.blocks.first.kind == BlockKind.image;

  Size _imageSize(DocBlock block) {
    final width = _soleImageDocument
        ? metrics.size.width - metrics.padding.horizontal
        : columnWidth;
    final maxHeight = columnHeight;
    final intrinsic = block.src == null ? null : images?.call(block.src!);
    if (intrinsic == null || intrinsic.width <= 0 || intrinsic.height <= 0) {
      return Size(width, math.min(maxHeight, width * 1.3));
    }
    final scale = math.min(
      width / intrinsic.width,
      maxHeight / intrinsic.height,
    );
    return Size(intrinsic.width * scale, intrinsic.height * scale);
  }

  static int _safeCut(String text, int at) {
    if (at <= 0 || at >= text.length) return at;
    final unit = text.codeUnitAt(at);
    return (unit >= 0xDC00 && unit <= 0xDFFF) ? at - 1 : at;
  }

  void _ensureLines(_BlockCursor cursor, int wanted) {
    final text = cursor.block.text;
    while (!cursor.measured && cursor.lines.length < wanted) {
      if (cursor.segmentStart > text.length) {
        cursor.measured = true;
        break;
      }
      final breakAt = text.indexOf('\n', cursor.segmentStart);
      final hardEnd = breakAt == -1 ? text.length : breakAt;

      var segmentEnd = hardEnd;
      var chunked = false;
      if (hardEnd - cursor.segmentStart > chunkChars) {
        final cut = _safeCut(text, cursor.segmentStart + chunkChars);
        if (cut > cursor.segmentStart && cut < hardEnd) {
          segmentEnd = cut;
          chunked = true;
        }
      }

      final before = cursor.lines.length;
      _measureSegment(
        cursor.block,
        cursor.block.start + cursor.segmentStart,
        cursor.block.start + segmentEnd,
        cursor.lines,
      );
      final added = cursor.lines.length - before;

      if (chunked) {
        if (added > 1) {
          final tail = cursor.lines.removeLast();
          cursor.segmentStart = tail.start - cursor.block.start;
        } else {
          cursor.segmentStart = segmentEnd;
        }
        continue;
      }

      if (breakAt == -1) {
        cursor.measured = true;
      } else {
        cursor.segmentStart = hardEnd + 1;
      }
    }
  }

  void _measureSegment(DocBlock block, int start, int end, List<_LineBox> out) {
    if (end <= start) {
      out.add(_LineBox(start, end, style.sizeFor(block) * style.lineHeight));
      return;
    }

    final runs = sliceRuns(block.runs, start, end);
    if (runs.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        children: [
          for (final run in runs)
            TextSpan(text: run.text, style: style.styleForRun(block, run)),
        ],
      ),
      textDirection: directionOf(block),
      textAlign: style.alignFor(block),
      textScaler: textScaler,
      strutStyle: StrutStyle(
        fontFamily: style.baseStyleFor(block).fontFamily,
        fontSize: style.sizeFor(block),
        height: style.lineHeight,
        forceStrutHeight: true,
      ),
    )..layout(maxWidth: math.max(1, columnWidth - style.textIndent(block)));

    final metrics = painter.computeLineMetrics();
    final before = out.length;
    for (var i = 0; i < metrics.length; i++) {
      final line = metrics[i];
      final probe = line.baseline - line.ascent + line.height / 2;
      final lineStart = painter.getPositionForOffset(Offset(0, probe)).offset;
      final lineEnd = i + 1 < metrics.length
          ? painter
                .getPositionForOffset(
                  Offset(
                    0,
                    metrics[i + 1].baseline -
                        metrics[i + 1].ascent +
                        metrics[i + 1].height / 2,
                  ),
                )
                .offset
          : end - start;
      out.add(
        _LineBox(
          start + lineStart,
          start + math.max(lineEnd, lineStart),
          line.height,
        ),
      );
    }
    painter.dispose();

    if (out.length > before) {
      final last = out.last;
      if (last.end < end) {
        out[out.length - 1] = _LineBox(last.start, end, last.height);
      }
    }
  }
}
