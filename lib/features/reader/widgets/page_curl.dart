// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef PageImageSource = Future<ui.Image?> Function();
typedef PageTurn = Future<void> Function();

enum PageTransition {
  curl(420),
  slide(260),
  fade(200);

  const PageTransition(this.millis);

  final int millis;

  static PageTransition? forSetting(String value) => switch (value) {
    'curl' => PageTransition.curl,
    'slide' => PageTransition.slide,
    'fade' => PageTransition.fade,
    _ => null,
  };

  bool get tracksDrag => this != PageTransition.fade;

  Key get overlayKey => ValueKey('page-transition-$name');
}

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

  /// Color del dorso de la hoja al plegarse. Lo fija el lector desde su tema:
  /// un dorso claro sobre fondo oscuro delata la animacion.
  Color paper = const Color(0xFFF2EDE4);

  late final AnimationController _anim;
  ui.Image? _active;
  int _direction = 1;
  PageTransition _mode = PageTransition.curl;
  bool _dragging = false;
  bool _cancelling = false;
  PageTurn? _revert;
  Future<void>? _pending;

  /// Fuente de verdad de la transicion. Quien dependa del progreso escucha
  /// esto en vez de reconstruirse: durante el arrastre la pagina de debajo no
  /// cambia de contenido y no tiene por que volver a construirse.
  Listenable get animation => _anim;

  bool get busy => _active != null;

  bool get dragging => _dragging;

  bool _adopt(ui.Image? image, int direction, PageTransition mode) {
    if (busy || image == null) {
      image?.dispose();
      return false;
    }
    _active = image;
    _direction = direction;
    _mode = mode;
    return true;
  }

  double get incomingShift => _active == null || _mode != PageTransition.slide
      ? 0
      : _direction * (1 - _anim.value);

  bool _capturing = false;
  ui.Image? _primed;
  ui.ImageShader? _primedShader;
  ui.ImageShader? _shader;

  /// El shader se compila y sube la textura al crearse: tambien se prepara
  /// en reposo para que el primer frame del giro no lo pague.
  ui.ImageShader? get shader => _shader;

  static ui.ImageShader _shaderFor(ui.Image image) => ui.ImageShader(
    image,
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
  );

  /// Captura la pagina de salida mientras el lector esta quieto. El readback
  /// de GPU cuesta un frame y no puede pagarse al empezar el giro.
  Future<void> prime(PageImageSource outgoing) async {
    if (busy || _capturing || _primed != null) return;
    _capturing = true;
    final image = await outgoing();
    _capturing = false;
    if (busy || image == null) {
      image?.dispose();
      return;
    }
    _primed = image;
    _primedShader = _shaderFor(image);
  }

  void invalidate() {
    _primed?.dispose();
    _primed = null;
    _primedShader?.dispose();
    _primedShader = null;
  }

  Future<ui.Image?> _obtain(PageImageSource outgoing) async {
    final ready = _primed;
    if (ready != null) {
      _primed = null;
      _shader = _primedShader;
      _primedShader = null;
      return ready;
    }
    _capturing = true;
    final image = await outgoing();
    _capturing = false;
    if (image != null) _shader = _shaderFor(image);
    return image;
  }

  Future<bool> start(
    int direction, {
    required PageImageSource outgoing,
    required PageTurn advance,
    PageTransition mode = PageTransition.curl,
  }) async {
    if (busy || _capturing) return false;
    final image = await _obtain(outgoing);
    if (!_adopt(image, direction, mode)) return false;
    _pending = advance();
    _anim.duration = Duration(milliseconds: mode.millis);
    _anim.forward(from: 0);
    onChange();
    return true;
  }

  Future<bool> beginDrag(
    int direction, {
    required PageImageSource outgoing,
    required PageTurn advance,
    required PageTurn revert,
    PageTransition mode = PageTransition.curl,
  }) async {
    if (busy || _capturing) return false;
    final image = await _obtain(outgoing);
    if (!_adopt(image, direction, mode)) return false;
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
    _shader?.dispose();
    _shader = null;
    _dragging = false;
    onChange();
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  Widget? overlay() {
    final image = _active;
    if (image == null) return null;
    return Positioned.fill(
      key: _mode.overlayKey,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => switch (_mode) {
            PageTransition.fade => Opacity(
              opacity: (1 - _anim.value).clamp(0.0, 1.0),
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
            PageTransition.slide => FractionalTranslation(
              translation: Offset(-_direction * _anim.value, 0),
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
            PageTransition.curl => PageCurl(
              image: image,
              shader: _shader,
              progress: _anim.value,
              direction: _direction,
              paper: paper,
            ),
          },
        ),
      ),
    );
  }

  void dispose() {
    _anim.dispose();
    _active?.dispose();
    _active = null;
    invalidate();
  }
}

class PageCurl extends StatefulWidget {
  const PageCurl({
    super.key,
    required this.image,
    required this.progress,
    required this.direction,
    this.shader,
    this.paper = const Color(0xFFF2EDE4),
  });

  final ui.Image image;
  final double progress;
  final int direction;
  final ui.ImageShader? shader;
  final Color paper;

  @override
  State<PageCurl> createState() => _PageCurlState();
}

/// Los buffers y el shader viven en el State: crearlos por frame costaba
/// ~2000 objetos y una recompilacion del shader en cada pintada.
class _PageCurlState extends State<PageCurl> {
  static const _points = _PageCurlPainter.points;

  final _positions = Float32List(_points * 2);
  final _texCoords = Float32List(_points * 2);
  final _front = Int32List(_points);
  final _back = Int32List(_points);
  final _theta = Float32List(_points);
  final _frontIdx = Uint16List(_PageCurlPainter.maxIndices);
  final _backIdx = Uint16List(_PageCurlPainter.maxIndices);

  ui.ImageShader? _own;

  ui.ImageShader get _shader => widget.shader ?? (_own ??= _makeShader());

  @override
  void didUpdateWidget(PageCurl old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _own?.dispose();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  ui.ImageShader _makeShader() => ui.ImageShader(
    widget.image,
    TileMode.clamp,
    TileMode.clamp,
    Matrix4.identity().storage,
  );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PageCurlPainter(
            image: widget.image,
            shader: _shader,
            progress: widget.progress.clamp(0.0, 1.0),
            direction: widget.direction,
            paper: widget.paper,
            positions: _positions,
            texCoords: _texCoords,
            front: _front,
            back: _back,
            theta: _theta,
            frontIdx: _frontIdx,
            backIdx: _backIdx,
          ),
        ),
      ),
    );
  }
}

class _PageCurlPainter extends CustomPainter {
  _PageCurlPainter({
    required this.image,
    required this.shader,
    required this.progress,
    required this.direction,
    required this.paper,
    required this.positions,
    required this.texCoords,
    required this.front,
    required this.back,
    required this.theta,
    required this.frontIdx,
    required this.backIdx,
  });

  final ui.Image image;
  final ui.ImageShader shader;
  final double progress;
  final int direction;
  final Color paper;
  final Float32List positions;
  final Float32List texCoords;
  final Int32List front;
  final Int32List back;
  final Float32List theta;
  final Uint16List frontIdx;
  final Uint16List backIdx;

  static const _cols = 44;
  static const _rows = 10;
  static const points = (_cols + 1) * (_rows + 1);
  static const maxIndices = _rows * _cols * 6;
  static final _half = math.pi / 2;
  static final _maxTheta = math.pi * 1.12;

  static double _ramp(double value, double from, double to) =>
      ((value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    final radius = math.min(w, h) * 0.085;
    final arc = radius * _maxTheta;
    final flapDrop = radius * math.sin(_maxTheta);
    final flapSlope = math.cos(_maxTheta);

    final corner = direction > 0 ? Offset(w, h) : Offset(0, h);
    final normal = _normalize(
      direction > 0 ? const Offset(1, 0.32) : const Offset(-1, 0.32),
    );
    final diagonal = math.sqrt(w * w + h * h);
    final travel = -arc + progress * (diagonal + 2 * arc);
    final foldPoint = corner - normal * travel;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    _paintCastShadow(canvas, w, h, foldPoint, normal, arc);

    final argb = paper.toARGB32();
    final pr = (argb >> 16) & 0xFF;
    final pg = (argb >> 8) & 0xFF;
    final pb = argb & 0xFF;

    for (var j = 0; j <= _rows; j++) {
      for (var i = 0; i <= _cols; i++) {
        final gx = i / _cols;
        final gy = j / _rows;
        final flat = Offset(gx * w, gy * h);
        final along =
            (flat.dx - foldPoint.dx) * normal.dx +
            (flat.dy - foldPoint.dy) * normal.dy;

        double lift;
        double theta_;
        if (along <= 0) {
          lift = along;
          theta_ = 0;
        } else {
          theta_ = along / radius;
          lift = theta_ <= _maxTheta
              ? radius * math.sin(theta_)
              : flapDrop + (along - arc) * flapSlope;
        }

        final lit = math.sin(theta_.clamp(0.0, math.pi));
        double frontShade;
        if (along <= 0) {
          final prox = (1 + along / (radius * 2.4)).clamp(0.0, 1.0);
          frontShade = 1.0 - 0.30 * prox * prox;
        } else {
          frontShade = 0.68 + 0.32 * lit;
        }
        final backShade = 0.76 + 0.24 * lit;

        final index = j * (_cols + 1) + i;
        final shift = along - lift;
        positions[index * 2] = flat.dx - normal.dx * shift;
        positions[index * 2 + 1] = flat.dy - normal.dy * shift;
        texCoords[index * 2] = gx * imgW;
        texCoords[index * 2 + 1] = gy * imgH;
        theta[index] = theta_;
        front[index] = _packed(
          255,
          255,
          255,
          frontShade,
          1 - _ramp(theta_, _half + 0.20, _half + 0.50),
        );
        back[index] = _packed(
          pr,
          pg,
          pb,
          backShade,
          _ramp(theta_, _half - 0.04, _half + 0.16),
        );
      }
    }

    var nFront = 0;
    var nBack = 0;
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final a = j * (_cols + 1) + i;
        final b = a + 1;
        final c = a + _cols + 1;
        final d = c + 1;
        final lo = math.min(
          math.min(theta[a], theta[b]),
          math.min(theta[c], theta[d]),
        );
        final hi = math.max(
          math.max(theta[a], theta[b]),
          math.max(theta[c], theta[d]),
        );
        if (lo < _half + 0.50) {
          frontIdx[nFront++] = a;
          frontIdx[nFront++] = c;
          frontIdx[nFront++] = b;
          frontIdx[nFront++] = b;
          frontIdx[nFront++] = c;
          frontIdx[nFront++] = d;
        }
        if (hi > _half - 0.04) {
          backIdx[nBack++] = a;
          backIdx[nBack++] = c;
          backIdx[nBack++] = b;
          backIdx[nBack++] = b;
          backIdx[nBack++] = c;
          backIdx[nBack++] = d;
        }
      }
    }

    if (nFront == 0 && nBack == 0) {
      canvas.restore();
      return;
    }

    if (nFront > 0) {
      final faceUp = ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
        colors: front,
        indices: Uint16List.sublistView(frontIdx, 0, nFront),
      );
      canvas.drawVertices(
        faceUp,
        BlendMode.modulate,
        Paint()
          ..isAntiAlias = true
          ..shader = shader,
      );
      faceUp.dispose();
    }

    if (nBack > 0) {
      final faceDown = ui.Vertices.raw(
        ui.VertexMode.triangles,
        positions,
        colors: back,
        indices: Uint16List.sublistView(backIdx, 0, nBack),
      );
      canvas.drawVertices(
        faceDown,
        BlendMode.modulate,
        Paint()
          ..isAntiAlias = true
          ..color = const Color(0xFFFFFFFF),
      );
      faceDown.dispose();
    }

    canvas.restore();
  }

  static int _packed(int r, int g, int b, double shade, double alpha) =>
      ((alpha * 255).round().clamp(0, 255) << 24) |
      ((r * shade).round().clamp(0, 255) << 16) |
      ((g * shade).round().clamp(0, 255) << 8) |
      (b * shade).round().clamp(0, 255);

  void _paintCastShadow(
    Canvas canvas,
    double w,
    double h,
    Offset foldPoint,
    Offset normal,
    double arc,
  ) {
    final along = Offset(-normal.dy, normal.dx);
    final reach = w + h;
    final near = foldPoint + normal * (arc * 0.05);
    final far = foldPoint + normal * (arc * 1.05);
    final path = Path()
      ..moveTo((near - along * reach).dx, (near - along * reach).dy)
      ..lineTo((near + along * reach).dx, (near + along * reach).dy)
      ..lineTo((far + along * reach).dx, (far + along * reach).dy)
      ..lineTo((far - along * reach).dx, (far - along * reach).dy)
      ..close();
    final paint = Paint()
      ..shader = ui.Gradient.linear(near, far, const [
        Color(0x4D000000),
        Color(0x00000000),
      ]);
    canvas.drawPath(path, paint);
  }

  Offset _normalize(Offset o) {
    final len = o.distance;
    return len == 0 ? o : o / len;
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.progress != progress ||
      old.image != image ||
      old.direction != direction ||
      old.paper != paper ||
      old.shader != shader;
}
