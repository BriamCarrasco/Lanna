// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PageCurlController {
  PageCurlController({
    required TickerProvider vsync,
    required this.onChange,
    this.onSettled,
  }) {
    _anim =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 480),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
  }

  final VoidCallback onChange;
  final VoidCallback? onSettled;

  late final AnimationController _anim;
  ui.Image? _ready;
  ui.Image? _active;
  int _direction = 1;
  bool _fade = false;
  Timer? _timer;

  bool get busy => _active != null;

  Future<ui.Image?> Function()? _capture;

  void scheduleCapture(
    Future<ui.Image?> Function() capture, {
    required bool enabled,
    int delayMs = 120,
    int attempt = 0,
  }) {
    _capture = enabled ? capture : null;
    if (!enabled) {
      _timer?.cancel();
      _ready?.dispose();
      _ready = null;
      return;
    }
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: attempt == 0 ? delayMs : 400),
      () async {
        if (busy) return;
        final image = await capture();
        if (busy) {
          image?.dispose();
          return;
        }
        _ready?.dispose();
        _ready = image;
        _log('captura previa: ${_describe(image)} (intento $attempt)');
        if (image == null && attempt < 3) {
          scheduleCapture(
            capture,
            enabled: enabled,
            delayMs: delayMs,
            attempt: attempt + 1,
          );
          return;
        }
        onChange();
      },
    );
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[curl] $message');
  }

  static String _describe(ui.Image? image) =>
      image == null ? 'null' : '${image.width}x${image.height}';

  bool start(
    int direction, {
    required VoidCallback advance,
    bool fade = false,
  }) {
    if (busy || _ready == null) {
      _log('start rechazado (busy=$busy, snapshot=${_describe(_ready)})');
      return false;
    }
    _active = _ready;
    _ready = null;
    _direction = direction;
    _fade = fade;
    advance();
    _anim.duration = Duration(milliseconds: fade ? 200 : 480);
    _anim.forward(from: 0);
    onChange();
    _log('animando dir=$direction con ${_describe(_active)}');
    return true;
  }

  void invalidate() {
    _timer?.cancel();
    _ready?.dispose();
    _ready = null;
  }

  Future<bool> startOrCapture(
    int direction, {
    required VoidCallback advance,
    bool fade = false,
  }) async {
    if (busy) return false;
    if (_ready == null) {
      final capture = _capture;
      if (capture == null) return false;
      _timer?.cancel();
      ui.Image? image;
      for (var attempt = 0; attempt < 3 && image == null; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 70));
        }
        image = await capture();
      }
      _log('captura al vuelo: ${_describe(image)}');
      if (image == null) return false;
      if (busy) {
        image.dispose();
        return false;
      }
      _ready?.dispose();
      _ready = image;
    }
    return start(direction, advance: advance, fade: fade);
  }

  void _finish() {
    _active?.dispose();
    _active = null;
    onChange();
    onSettled?.call();
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
    _timer?.cancel();
    _anim.dispose();
    _ready?.dispose();
    _active?.dispose();
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

    final indices = <int>[];
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final a = j * (_cols + 1) + i;
        final b = a + 1;
        final c = a + _cols + 1;
        final d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      colors: colors,
      indices: indices,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
    canvas.drawVertices(vertices, BlendMode.modulate, paint);
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
