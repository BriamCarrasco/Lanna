// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/widgets/page_curl.dart';

void main() {
  const w = 400.0;
  const r = curlRadius;

  double bordeEn(double progreso) =>
      edgeForAxis(curlAxisFor(progreso, w, r), w, r);

  test('sin progreso la hoja está entera y sin plegar', () {
    expect(curlAxisFor(0, w, r), w);
    expect(bordeEn(0), closeTo(w, 0.01));
  });

  test('el borde de la hoja acompaña al dedo uno a uno', () {
    final recorrido = PageTransition.curl.travelSpan(w);
    for (final progreso in [0.1, 0.25, 0.5, 0.75, 1.0]) {
      expect(
        bordeEn(progreso),
        closeTo(w - recorrido * progreso, 0.5),
        reason: 'a $progreso el borde no va donde el dedo',
      );
    }
  });

  test('el recorrido del curl es el del borde, no el 70 % del ancho', () {
    expect(PageTransition.curl.travelSpan(w), greaterThan(w * 1.5));
    expect(PageTransition.slide.travelSpan(w), w * 0.7);
    expect(PageTransition.fade.travelSpan(w), w * 0.7);
  });

  test('soltar completa cuando el borde pasa la mitad de la pantalla', () {
    final umbral = PageTransition.curl.completion(w);
    expect(bordeEn(umbral), closeTo(w / 2, 0.5));
    expect(bordeEn(umbral * 0.9), greaterThan(w / 2));
    expect(bordeEn(umbral * 1.1), lessThan(w / 2));
    expect(PageTransition.slide.completion(w), 0.35);
  });

  test('al terminar la hoja quedó fuera de la pantalla', () {
    expect(curlAxisFor(1, w, r), closeTo(-r, 0.01));
    expect(bordeEn(1), lessThan(0));
  });

  test('eje y borde son inversos en todo el recorrido', () {
    for (var eje = -r; eje <= w; eje += 7) {
      final borde = edgeForAxis(eje, w, r);
      expect(
        axisForEdge(borde, w, r),
        closeTo(eje, 0.05),
        reason: 'ida y vuelta falla en el eje $eje',
      );
    }
  });

  test('el progreso avanza el pliegue de forma monótona', () {
    var anterior = double.infinity;
    for (var p = 0.0; p <= 1.0; p += 0.05) {
      final eje = curlAxisFor(p, w, r);
      expect(eje, lessThan(anterior), reason: 'el pliegue retrocede en $p');
      anterior = eje;
    }
  });
}
