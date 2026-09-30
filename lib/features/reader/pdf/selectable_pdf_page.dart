// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../reader_engine.dart';
import '../reader_theme.dart';

class PdfSelection {
  const PdfSelection({
    required this.page,
    required this.rects,
    required this.text,
    required this.screenRect,
  });

  final int page;
  final List<Rect> rects;
  final String text;
  final Rect screenRect;

  String encodeCfi() {
    final parts = rects
        .map((r) => '${_r(r.left)},${_r(r.top)},${_r(r.width)},${_r(r.height)}')
        .join(';');
    return 'page:$page#$parts';
  }

  static String _r(double v) => v.toStringAsFixed(4);
}

List<Rect> decodeHighlightRects(String cfi) {
  final hash = cfi.indexOf('#');
  if (hash < 0) return const [];
  final rects = <Rect>[];
  for (final chunk in cfi.substring(hash + 1).split(';')) {
    final n = chunk.split(',');
    if (n.length != 4) continue;
    final v = n.map(double.tryParse).toList();
    if (v.any((x) => x == null)) continue;
    rects.add(Rect.fromLTWH(v[0]!, v[1]!, v[2]!, v[3]!));
  }
  return rects;
}

class SelectablePdfPage extends StatefulWidget {
  const SelectablePdfPage({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.highlights,
    required this.selection,
    required this.onSelect,
    required this.onHighlightTap,
    required this.onTapEmpty,
  });

  final PdfDocument document;
  final int pageNumber;
  final List<HighlightSpec> highlights;
  final PdfSelection? selection;
  final ValueChanged<PdfSelection> onSelect;
  final ValueChanged<String> onHighlightTap;
  final VoidCallback onTapEmpty;

  @override
  State<SelectablePdfPage> createState() => _SelectablePdfPageState();
}

class _SelectablePdfPageState extends State<SelectablePdfPage> {
  PdfPageRawText? _raw;
  int? _anchorChar;

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  @override
  void didUpdateWidget(SelectablePdfPage old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber ||
        old.document != widget.document) {
      _raw = null;
      _loadText();
    }
  }

  Future<void> _loadText() async {
    try {
      final raw = await widget.document.pages[widget.pageNumber - 1].loadText();
      if (mounted) setState(() => _raw = raw);
    } catch (_) {}
  }

  double get _pw => widget.document.pages[widget.pageNumber - 1].width;
  double get _ph => widget.document.pages[widget.pageNumber - 1].height;

  Rect _norm(PdfRect r) {
    final left = r.left / _pw;
    final right = r.right / _pw;
    final top = 1 - r.top / _ph;
    final bottom = 1 - r.bottom / _ph;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  int? _charAt(Offset normalized) {
    final raw = _raw;
    if (raw == null || raw.charRects.isEmpty) return null;
    var best = -1;
    var bestDist = double.infinity;
    for (var i = 0; i < raw.charRects.length; i++) {
      final r = _norm(raw.charRects[i]);
      if (r.isEmpty) continue;
      if (r.contains(normalized)) return i;
      final d = (r.center - normalized).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best < 0 || bestDist > 0.02 ? null : best;
  }

  List<Rect> _lineRects(int a, int b) {
    final raw = _raw!;
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    final merged = <Rect>[];
    Rect? current;
    for (var i = lo; i <= hi && i < raw.charRects.length; i++) {
      final r = _norm(raw.charRects[i]);
      if (r.isEmpty) continue;
      if (current == null) {
        current = r;
      } else if ((r.center.dy - current.center.dy).abs() <
              current.height * 0.8 &&
          r.left >= current.left - 0.02) {
        current = current.expandToInclude(r);
      } else {
        merged.add(current);
        current = r;
      }
    }
    if (current != null) merged.add(current);
    return merged;
  }

  void _updateSelection(int anchor, int focus, Size size) {
    final raw = _raw;
    if (raw == null) return;
    final lo = math.min(anchor, focus);
    final hi = math.max(anchor, focus);
    final text = raw.fullText.substring(
      lo,
      math.min(hi + 1, raw.fullText.length),
    );
    if (text.trim().isEmpty) return;
    final rects = _lineRects(anchor, focus);
    if (rects.isEmpty) return;

    final box = context.findRenderObject() as RenderBox?;
    var union = rects.first;
    for (final r in rects.skip(1)) {
      union = union.expandToInclude(r);
    }
    final pxUnion = Rect.fromLTWH(
      union.left * size.width,
      union.top * size.height,
      union.width * size.width,
      union.height * size.height,
    );
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    widget.onSelect(
      PdfSelection(
        page: widget.pageNumber,
        rects: rects,
        text: text.trim(),
        screenRect: pxUnion.shift(origin),
      ),
    );
  }

  HighlightSpec? _highlightAt(Offset normalized) {
    for (final h in widget.highlights) {
      for (final r in decodeHighlightRects(h.cfi)) {
        if (r.inflate(0.01).contains(normalized)) return h;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final n = Offset(
              d.localPosition.dx / size.width,
              d.localPosition.dy / size.height,
            );
            final hit = _highlightAt(n);
            if (hit != null) {
              widget.onHighlightTap(hit.cfi);
            } else {
              widget.onTapEmpty();
            }
          },
          onLongPressStart: (d) {
            final n = Offset(
              d.localPosition.dx / size.width,
              d.localPosition.dy / size.height,
            );
            final c = _charAt(n);
            if (c == null) return;
            _anchorChar = c;
            _updateSelection(c, c, size);
          },
          onLongPressMoveUpdate: (d) {
            final anchor = _anchorChar;
            if (anchor == null) return;
            final n = Offset(
              (d.localPosition.dx / size.width).clamp(0.0, 1.0),
              (d.localPosition.dy / size.height).clamp(0.0, 1.0),
            );
            final c = _charAt(n);
            if (c != null) _updateSelection(anchor, c, size);
          },
          onLongPressEnd: (_) => _anchorChar = null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PdfPageView(
                document: widget.document,
                pageNumber: widget.pageNumber,
                alignment: Alignment.center,
                backgroundColor: Colors.white,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _HighlightPainter(
                      highlights: widget.highlights,
                      selection: widget.selection?.page == widget.pageNumber
                          ? widget.selection!.rects
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({required this.highlights, required this.selection});

  final List<HighlightSpec> highlights;
  final List<Rect>? selection;

  @override
  void paint(Canvas canvas, Size size) {
    for (final h in highlights) {
      final color = (readerHighlightColors[h.color] ?? const Color(0xFFFFE14D))
          .withValues(alpha: 0.34);
      final paint = Paint()..color = color;
      for (final r in decodeHighlightRects(h.cfi)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(_scale(r, size), const Radius.circular(2)),
          paint,
        );
      }
    }
    final sel = selection;
    if (sel != null) {
      final paint = Paint()..color = const Color(0x552F6FE0);
      for (final r in sel) {
        canvas.drawRect(_scale(r, size), paint);
      }
    }
  }

  Rect _scale(Rect r, Size size) => Rect.fromLTWH(
    r.left * size.width,
    r.top * size.height,
    r.width * size.width,
    r.height * size.height,
  );

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.highlights != highlights || old.selection != selection;
}
