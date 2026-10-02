// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/widgets/page_curl.dart';

typedef Rgba = ({int r, int g, int b, int a});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const w = 300;
  const h = 400;
  const paper = Color(0xFF20C040);
  const lienzo = ValueKey('lienzo');

  Future<ui.Image> sheet() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF1030C0),
    );
    return recorder.endRecording().toImage(w, h);
  }

  Future<ByteData> render(
    WidgetTester tester,
    double progress, {
    int direction = 1,
  }) async {
    final image = (await tester.runAsync(sheet))!;
    addTearDown(image.dispose);
    final program = (await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/page_curl.frag'),
    ))!;
    final shader = program.fragmentShader();
    addTearDown(shader.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: lienzo,
            child: SizedBox(
              width: w.toDouble(),
              height: h.toDouble(),
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned.fill(
                    child: PageCurl(
                      image: image,
                      shader: shader,
                      progress: progress,
                      direction: direction,
                      paper: paper,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(lienzo),
    );
    final shot = (await tester.runAsync(() => boundary.toImage()))!;
    addTearDown(shot.dispose);
    return (await tester.runAsync(
      () => shot.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
  }

  Rgba pixel(ByteData d, int x, int y) {
    final at = (y * w + x) * 4;
    return (
      r: d.getUint8(at),
      g: d.getUint8(at + 1),
      b: d.getUint8(at + 2),
      a: d.getUint8(at + 3),
    );
  }

  int contar(ByteData d, bool Function(Rgba) test, {int paso = 7}) {
    var total = 0;
    for (var y = 4; y < h - 4; y += paso) {
      for (var x = 4; x < w - 4; x += paso) {
        if (test(pixel(d, x, y))) total++;
      }
    }
    return total;
  }

  double fraccion(ByteData d, bool Function(Rgba) test, {int paso = 3}) {
    var muestras = 0;
    for (var y = 4; y < h - 4; y += paso) {
      for (var x = 4; x < w - 4; x += paso) {
        muestras++;
      }
    }
    return contar(d, test, paso: paso) / muestras;
  }

  bool esDorso(Rgba c) => c.a > 200 && c.g > 60 && c.g > c.r && c.g > c.b;
  bool esImpreso(Rgba c) => c.a > 200 && c.b > 60 && c.b > c.g && c.b > c.r;
  bool esFondo(Rgba c) => c.r < 12 && c.g < 12 && c.b < 12;

  testWidgets('el dorso de la hoja se dibuja al plegarse', (tester) async {
    final data = await render(tester, 0.55);

    expect(
      contar(data, esDorso),
      greaterThan(20),
      reason: 'la parte plegada se desvanece en vez de doblarse sobre la hoja',
    );
  });

  testWidgets('la cara impresa convive con el dorso', (tester) async {
    final data = await render(tester, 0.30);

    expect(
      contar(data, esImpreso),
      greaterThan(20),
      reason: 'no queda cara impresa',
    );
    expect(
      contar(data, esFondo),
      greaterThan(20),
      reason: 'no se ve la página nueva',
    );
  });

  testWidgets('sin plegar no hay dorso y la hoja cubre todo', (tester) async {
    final data = await render(tester, 0.0);

    expect(contar(data, esDorso), 0, reason: 'hay dorso antes de empezar');
    expect(
      contar(data, esFondo),
      0,
      reason: 'la hoja no cubre la página nueva',
    );
  });

  testWidgets('el faldón se tumba sobre la hoja, no se queda en el pliegue', (
    tester,
  ) async {
    final data = await render(tester, 0.60);

    expect(
      fraccion(data, esDorso),
      greaterThan(0.15),
      reason:
          'el dorso no llega a tumbarse sobre la hoja'
          ' (se queda pegado al pliegue)',
    );
  });

  int mitad(ByteData d, bool Function(Rgba) test, {required bool izquierda}) {
    var total = 0;
    for (var y = 4; y < h - 4; y += 7) {
      for (var x = 4; x < w - 4; x += 7) {
        final enIzquierda = x < w ~/ 2;
        if (enIzquierda == izquierda && test(pixel(d, x, y))) total++;
      }
    }
    return total;
  }

  testWidgets('hacia atrás el pliegue va por el otro lado', (tester) async {
    final adelante = await render(tester, 0.55);
    final atras = await render(tester, 0.55, direction: -1);

    expect(
      mitad(adelante, esDorso, izquierda: true),
      greaterThan(mitad(adelante, esDorso, izquierda: false)),
      reason: 'hacia delante el dorso se tumba a la izquierda',
    );
    expect(
      mitad(atras, esDorso, izquierda: false),
      greaterThan(mitad(atras, esDorso, izquierda: true)),
      reason: 'hacia atrás el dorso tiene que caer a la derecha',
    );
    expect(
      mitad(atras, esFondo, izquierda: true),
      greaterThan(mitad(atras, esFondo, izquierda: false)),
      reason: 'hacia atrás la página nueva asoma por la izquierda',
    );
  });

  testWidgets('al terminar la hoja ya salió', (tester) async {
    final data = await render(tester, 1.0);

    expect(contar(data, esDorso), 0);
    expect(contar(data, esImpreso), 0, reason: 'quedan restos de la hoja');
  });
}
