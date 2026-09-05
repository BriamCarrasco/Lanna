// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef PageImageSource = Future<ui.Image?> Function();
typedef PageTurn = Future<void> Function();

class PageCurlController {
  PageCurlController({required TickerProvider vsync, required this.onChange}) {
    _anim =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 480),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            unawaited(_settle(null));
          } else if (status == AnimationStatus.dismissed && _cancelling) {
            _cancelling = false;
            final revert = _revert;
            _revert = null;
            unawaited(_settle(revert));
          }
        });
  }

  final VoidCallback onChange;

  late final AnimationController _anim;
  ui.Image? _active;
  int _direction = 1;
  bool _fade = false;
  bool _dragging = false;
  bool _cancelling = false;
  PageTurn? _revert;
  Future<void>? _pending;

  bool get busy => _active != null;

  bool get dragging => _dragging;

  bool _adopt(ui.Image? image, int direction, {bool fade = false}) {
    if (busy || image == null) {
      image?.dispose();
      return false;
    }
    _active = image;
    _direction = direction;
    _fade = fade;
    return true;
  }

  bool _capturing = false;

  Future<bool> start(
    int direction, {
    required PageImageSource outgoing,
    required PageTurn advance,
    bool fade = false,
  }) async {
    if (busy || _capturing) return false;
    _capturing = true;
    final image = await outgoing();
    _capturing = false;
    if (!_adopt(image, direction, fade: fade)) return false;
    _pending = advance();
    _anim.duration = Duration(milliseconds: fade ? 200 : 420);
    _anim.forward(from: 0);
    onChange();
    return true;
  }

  Future<bool> beginDrag(
    int direction, {
    required PageImageSource outgoing,
    required PageTurn advance,
    required PageTurn revert,
  }) async {
    if (busy || _capturing) return false;
    _capturing = true;
    final image = await outgoing();
    _capturing = false;
    if (!_adopt(image, direction)) return false;
    _dragging = true;
    _cancelling = false;
    _revert = revert;
    _pending = advance();
    _anim.value = 0;
    onChange();
    return true;
  }

  void updateDrag(double progress) {
    if (!_dragging) return;
    _anim.value = progress.clamp(0.0, 1.0);
    onChange();
  }

  void endDrag({required bool complete}) {
    if (!_dragging) return;
    _dragging = false;
    final remaining = complete ? 1 - _anim.value : _anim.value;
    _anim.duration = Duration(
      milliseconds: (remaining * 260).round().clamp(90, 260),
    );
    if (complete) {
      _revert = null;
      _anim.forward();
    } else {
      _cancelling = true;
      _anim.reverse();
    }
  }

  Future<void> _settle(PageTurn? revert) async {
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    if (revert != null) {
      try {
        await revert();
      } catch (_) {}
    }
    _finish();
  }

  void _finish() {
    final image = _active;
    _active = null;
    _dragging = false;
    onChange();
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  Widget? overlay() {
    final image = _active;
    if (image == null) return null;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => _fade
              ? Opacity(
                  opacity: (1 - _anim.value).clamp(0.0, 1.0),
                  child: RawImage(image: image, fit: BoxFit.fill),
                )
              : PageCurl(
                  image: image,
                  progress: _anim.value,
                  direction: _direction,
                ),
        ),
      ),
    );
  }

  void dispose() {
    _anim.dispose();
    _active?.dispose();
    _active = null;
  }
}

class PageCurl extends StatelessWidget {
  const PageCurl({
    super.key,
    required this.image,
    required this.progress,
    required this.direction,
  });

  final ui.Image image;
  final double progress;
  final int direction;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PageCurlPainter(
            image: image,
            progress: progress.clamp(0.0, 1.0),
            direction: direction,
          ),
        ),
      ),
    );
  }
}

class _PageCurlPainter extends CustomPainter {
  _PageCurlPainter({
    required this.image,
    required this.progress,
    required this.direction,
  });

  final ui.Image image;
  final double progress;
  final int direction;

  static const _cols = 20;
  static const _rows = 26;

  static final Int32List _indices = _buildIndices();

  static Int32List _buildIndices() {
    final out = Int32List(_rows * _cols * 6);
    var k = 0;
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final a = j * (_cols + 1) + i;
        final b = a + 1;
        final c = a + _cols + 1;
        final d = c + 1;
        out[k++] = a;
        out[k++] = c;
        out[k++] = b;
        out[k++] = b;
        out[k++] = c;
        out[k++] = d;
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    final radius = math.min(w, h) * 0.10;
    final maxTheta = math.pi * 1.12;
    final maxDist = radius * maxTheta;

    final corner = direction > 0 ? Offset(w, h) : Offset(0, h);
    final foldNormal = _normalize(
      direction > 0 ? const Offset(1, 0.32) : const Offset(-1, 0.32),
    );
    final sweep = -foldNormal;
    final diagonal = math.sqrt(w * w + h * h);
    final travel = -maxDist + progress * (diagonal + 2 * maxDist);
    final foldPoint = corner + sweep * travel;

    _paintCastShadow(canvas, w, h, foldPoint, foldNormal, maxDist);

    final positions = List<Offset>.filled(
      (_cols + 1) * (_rows + 1),
      Offset.zero,
    );
    final texCoords = List<Offset>.filled(
      (_cols + 1) * (_rows + 1),
      Offset.zero,
    );
    final colors = List<Color>.filled(
      (_cols + 1) * (_rows + 1),
      const Color(0xFFFFFFFF),
    );

    for (var j = 0; j <= _rows; j++) {
      for (var i = 0; i <= _cols; i++) {
        final gx = i / _cols;
        final gy = j / _rows;
        final flat = Offset(gx * w, gy * h);
        final dist =
            (flat.dx - foldPoint.dx) * foldNormal.dx +
            (flat.dy - foldPoint.dy) * foldNormal.dy;

        Offset pos;
        double shade;
        var alpha = 1.0;
        if (dist <= 0) {
          pos = flat;
          final prox = (1 + dist / (radius * 1.7)).clamp(0.0, 1.0);
          shade = 1.0 - 0.34 * prox * prox;
        } else if (dist >= maxDist) {
          pos = flat - foldNormal * dist;
          shade = 0.3;
          alpha = 0.0;
        } else {
          final theta = dist / radius;
          final n = radius * math.sin(theta);
          pos = flat - foldNormal * (dist - n);
          if (theta <= math.pi / 2) {
            shade = 0.74 + 0.26 * math.cos(theta);
          } else {
            shade = 0.30 + 0.16 * (1 + math.cos(theta));
          }
          alpha =
              1.0 -
              ((dist - maxDist * 0.82) / (maxDist * 0.18)).clamp(0.0, 1.0);
        }

        final index = j * (_cols + 1) + i;
        positions[index] = pos;
        texCoords[index] = Offset(gx * imgW, gy * imgH);
        final v = (shade * 255).round().clamp(0, 255);
        final a = (alpha * 255).round().clamp(0, 255);
        colors[index] = Color.fromARGB(a, v, v, v);
      }
    }

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
      indices: _indices,
    );
    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = shader;
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
    shader.dispose();
    vertices.dispose();
  }

  void _paintCastShadow(
    Canvas canvas,
    double w,
    double h,
    Offset foldPoint,
    Offset foldNormal,
    double maxDist,
  ) {
    final along = Offset(-foldNormal.dy, foldNormal.dx);
    final reach = w + h;
    final near = foldPoint + foldNormal * (maxDist * 0.15);
    final far = foldPoint + foldNormal * (maxDist * 1.15);
    final path = Path()
      ..moveTo((near - along * reach).dx, (near - along * reach).dy)
      ..lineTo((near + along * reach).dx, (near + along * reach).dy)
      ..lineTo((far + along * reach).dx, (far + along * reach).dy)
      ..lineTo((far - along * reach).dx, (far - along * reach).dy)
      ..close();
    final paint = Paint()
      ..shader = ui.Gradient.linear(near, far, const [
        Color(0x3D000000),
        Color(0x00000000),
      ])
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Offset _normalize(Offset o) {
    final len = o.distance;
    return len == 0 ? o : o / len;
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.progress != progress ||
      old.image != image ||
      old.direction != direction;
}
