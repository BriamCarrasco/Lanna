// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

typedef PageImageSource = Future<ui.Image?> Function();
typedef PageTurn = Future<void> Function();

const double curlRadius = 36;

final SpringDescription curlSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 180,
  ratio: 1,
);

double edgeForAxis(double axis, double width, double radius) {
  final theta = (width - axis) / radius;
  if (theta <= 0) return width;
  if (theta <= math.pi) return axis + radius * math.sin(theta);
  return 2 * axis - width + math.pi * radius;
}

double axisForEdge(double edge, double width, double radius) {
  final k = (width - edge) / radius;
  if (k <= 0) return width;
  if (k >= math.pi) return (edge + width - math.pi * radius) / 2;
  var lo = 0.0;
  var hi = math.pi;
  for (var i = 0; i < 32; i++) {
    final mid = (lo + hi) / 2;
    if (mid - math.sin(mid) < k) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return width - radius * (lo + hi) / 2;
}

double edgeTurned(double width, double radius) =>
    edgeForAxis(-radius, width, radius);

double curlAxisFor(double progress, double width, double radius) {
  final fin = edgeTurned(width, radius);
  final edge = width + (fin - width) * progress.clamp(0.0, 1.0);
  return axisForEdge(edge, width, radius);
}

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

  /// Recorrido del dedo que agota la animación. En el curl el borde de la
  /// hoja va bajo el dedo, así que el dedo recorre lo que recorre el borde.
  double travelSpan(double width) => this == PageTransition.curl
      ? width - edgeTurned(width, curlRadius)
      : width * 0.7;

  /// Progreso a partir del cual soltar completa el giro. En el curl es cuando
  /// el borde de la hoja pasa la mitad de la pantalla.
  double completion(double width) =>
      this == PageTransition.curl ? (width * 0.5) / travelSpan(width) : 0.35;

  Key get overlayKey => ValueKey('page-transition-$name');
}

class PageCurlController {
  PageCurlController({required TickerProvider vsync, required this.onChange}) {
    _anim =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 480),
        )..addStatusListener((status) {
          if (_springing) return;
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
  ui.FragmentShader? _curl;
  bool _springing = false;

  /// El shader se compila una vez por lector: compilarlo al empezar el giro
  /// costaria el primer frame.
  bool get curlReady => _curl != null;

  Future<void> loadShader() async {
    if (_curl != null) return;
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/page_curl.frag',
      );
      _curl = program.fragmentShader();
      onChange();
    } catch (_) {}
  }

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
  }

  void invalidate() {
    _primed?.dispose();
    _primed = null;
  }

  Future<ui.Image?> _obtain(PageImageSource outgoing) async {
    final ready = _primed;
    if (ready != null) {
      _primed = null;
      return ready;
    }
    _capturing = true;
    final image = await outgoing();
    _capturing = false;
    return image;
  }

  PageTransition _usable(PageTransition mode) =>
      mode == PageTransition.curl && !curlReady ? PageTransition.slide : mode;

  Future<bool> start(
    int direction, {
    required PageImageSource outgoing,
    required PageTurn advance,
    PageTransition mode = PageTransition.curl,
  }) async {
    if (busy || _capturing) return false;
    final usable = _usable(mode);
    final image = await _obtain(outgoing);
    if (!_adopt(image, direction, usable)) return false;
    _pending = advance();
    _anim.duration = Duration(milliseconds: usable.millis);
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
    if (!_adopt(image, direction, _usable(mode))) return false;
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

  void _cancelSpring(Object error) {
    _springing = false;
  }

  void endDrag({required bool complete, double velocity = 0}) {
    if (!_dragging) return;
    _dragging = false;
    if (_mode == PageTransition.curl) {
      final revert = complete ? null : _revert;
      _revert = null;
      _springing = true;
      _anim
          .animateWith(
            SpringSimulation(
              curlSpring,
              _anim.value,
              complete ? 1 : 0,
              velocity,
              tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
            ),
          )
          .orCancel
          .then((_) {
            _springing = false;
            unawaited(_settle(revert));
          }, onError: _cancelSpring);
      return;
    }
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
    _springing = false;
    _dragging = false;
    onChange();
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  Widget? overlay() {
    final image = _active;
    if (image == null) return null;
    final curl = _curl;
    if (_mode == PageTransition.curl && curl != null) {
      return Positioned.fill(
        key: _mode.overlayKey,
        child: PageCurl(
          image: image,
          shader: curl,
          progress: _anim.value,
          direction: _direction,
          paper: paper,
          repaint: _anim,
        ),
      );
    }
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
            _ => FractionalTranslation(
              translation: Offset(-_direction * _anim.value, 0),
              child: RawImage(image: image, fit: BoxFit.fill),
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
    _curl?.dispose();
    _curl = null;
    invalidate();
  }
}

class PageCurl extends StatelessWidget {
  const PageCurl({
    super.key,
    required this.image,
    required this.shader,
    required this.progress,
    required this.direction,
    this.paper = const Color(0xFFF2EDE4),
    this.radius = curlRadius,
    this.repaint,
  });

  final ui.Image image;
  final ui.FragmentShader shader;
  final double progress;
  final int direction;
  final Color paper;
  final double radius;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PageCurlPainter(
            image: image,
            shader: shader,
            progress: progress.clamp(0.0, 1.0),
            direction: direction,
            paper: paper,
            radius: radius,
            repaint: repaint,
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
    required this.radius,
    this.repaint,
  }) : super(repaint: repaint);

  final ui.Image image;
  final ui.FragmentShader shader;
  final double progress;
  final int direction;
  final Color paper;
  final double radius;
  final Listenable? repaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final value = repaint is Animation<double>
        ? (repaint! as Animation<double>).value.clamp(0.0, 1.0)
        : progress;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, curlAxisFor(value, size.width, radius))
      ..setFloat(3, radius)
      ..setFloat(4, 1)
      ..setFloat(5, 1)
      ..setFloat(6, direction < 0 ? 1 : 0)
      ..setFloat(7, paper.r)
      ..setFloat(8, paper.g)
      ..setFloat(9, paper.b)
      ..setImageSampler(0, image)
      ..setImageSampler(1, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_PageCurlPainter old) =>
      old.progress != progress ||
      old.image != image ||
      old.direction != direction ||
      old.paper != paper ||
      old.radius != radius ||
      old.shader != shader;
}
