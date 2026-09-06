// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/native/page_canvas.dart';
import 'package:lanna/features/reader/reader_screen.dart';

import '../support/reader_harness.dart';

void main() {
  Object? paginaActual(WidgetTester tester) {
    final encontrados = tester.widgetList<NativePage>(find.byType(NativePage));
    return encontrados.isEmpty ? null : encontrados.first;
  }

  double? entrante(WidgetTester tester) {
    final f = find.byKey(readerIncomingKey);
    if (f.evaluate().isEmpty) return null;
    return tester.widget<FractionalTranslation>(f).translation.dx;
  }

  /// Cuenta cuantas veces se reconstruye el subarbol del lector mientras se
  /// arrastra. Deberia ser cero: la pagina de salida es una instantanea y la
  /// de entrada no cambia de contenido.
  readerTest('el arrastre no reconstruye la página bajo la transición', (
    tester,
    h,
  ) async {
    await h.setAnimation('slide');
    await h.seedBook(chapters: ['<p>${h.words(900)}</p>']);
    await h.pumpReader(tester);

    final centro = tester.getCenter(find.byType(NativePage));
    late final dynamic gesto;
    await tester.runAsync(() async {
      gesto = await tester.startGesture(centro);
      await gesto.moveBy(const Offset(-40, 0));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();

    var previa = paginaActual(tester);
    var reconstrucciones = 0;
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => gesto.moveBy(const Offset(-14, 0)));
      await tester.pump(const Duration(milliseconds: 16));
      final actual = paginaActual(tester);
      if (!identical(actual, previa)) reconstrucciones++;
      previa = actual;
    }

    await tester.runAsync(() => gesto.up());
    await settleReader(tester);

    // Una sola reconstruccion al arrancar (el overlay entra en el arbol) es
    // estructural; a partir de ahi manda la animacion, no setState.
    expect(
      reconstrucciones,
      lessThanOrEqualTo(1),
      reason:
          'la página se reconstruyó $reconstrucciones veces en 12 frames de '
          'arrastre: el motor trabaja bajo una instantánea que lo tapa',
    );
  });

  readerTest('el deslizado mueve la entrante frame a frame', (tester, h) async {
    await h.setAnimation('slide');
    await h.seedBook(chapters: ['<p>${h.words(900)}</p>']);
    await h.pumpReader(tester);

    await h.turnForward(tester);

    final muestras = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 24));
      final valor = entrante(tester);
      if (valor != null) muestras.add(valor);
    }
    await settleReader(tester);

    final distintos = muestras.toSet();
    expect(
      distintos.length,
      greaterThan(3),
      reason:
          'la entrante solo tomó ${distintos.length} valores '
          '($distintos): salta en vez de deslizarse',
    );
  });

  readerTest('el capítulo vecino se prepara en reposo', (tester, h) async {
    await h.seedBook(
      chapters: ['<p>${h.words(120)}</p>', '<p>${h.words(120)}</p>'],
    );
    await h.pumpReader(tester);

    final source = h.sourceOf(tester);
    expect(
      source.isCached(1),
      isFalse,
      reason: 'se adelantó sin esperar a que el lector estuviera quieto',
    );

    await tester.pump(const Duration(milliseconds: 600));
    await settleReader(tester);

    expect(
      source.isCached(1),
      isTrue,
      reason: 'cruzar de capítulo seguirá costando el parseo dentro del giro',
    );
  });
}
