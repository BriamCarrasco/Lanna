// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/reader_screen.dart';
import 'package:lanna/features/reader/reader_theme.dart';
import 'package:lanna/features/reader/widgets/page_curl.dart';

import '../support/reader_harness.dart';

void main() {
  readerTest('abre el libro y pinta su primera página', (tester, h) async {
    await h.seedBook(chapters: ['<h1>Uno</h1><p>${h.words(60)}</p>']);
    await h.pumpReader(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Libro de prueba  ·  Autora'), findsOneWidget);
    expect(find.textContaining('palabra'), findsWidgets);
  });

  readerTest('un libro que no está en la base avisa', (tester, h) async {
    await h.pumpReader(tester, id: 'fantasma');

    expect(find.text('El libro no está en la biblioteca'), findsOneWidget);
  });

  readerTest('un EPUB corrupto avisa en vez de quedarse en blanco', (
    tester,
    h,
  ) async {
    await h.seedBook(chapters: ['<p>x</p>']);
    h.corrupt();
    await h.pumpReader(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  Future<void> abrirLargo(WidgetTester tester, ReaderHarness h) async {
    await h.seedBook(chapters: ['<p>${h.words(900)}</p>']);
    await h.pumpReader(tester);
    expect(find.textContaining('palabra'), findsWidgets);
  }

  Finder overlayDe(PageTransition modo) => find.byKey(modo.overlayKey);

  double desplazamientoEntrante(WidgetTester tester) => tester
      .widget<FractionalTranslation>(find.byKey(readerIncomingKey))
      .translation
      .dx;

  final seleccionables = [
    for (final m in ReaderSettings.pageAnimations)
      if (PageTransition.forSetting(m) != null) PageTransition.forSetting(m)!,
  ];

  for (final modo in seleccionables) {
    readerTest('el modo ${modo.name} superpone su transición', (
      tester,
      h,
    ) async {
      await h.setAnimation(modo.name);
      await abrirLargo(tester, h);

      await h.turnForward(tester);
      await settleReader(tester, rounds: 4);

      expect(
        overlayDe(modo),
        findsOneWidget,
        reason: 'el ajuste ${modo.name} no animó nada',
      );
      for (final otro in seleccionables) {
        if (otro != modo) expect(overlayDe(otro), findsNothing);
      }
      await settleReader(tester);
    });
  }

  readerTest('sin animación no se superpone nada', (tester, h) async {
    await h.setAnimation('none');
    await abrirLargo(tester, h);

    await h.turnForward(tester);
    await settleReader(tester, rounds: 4);

    for (final modo in seleccionables) {
      expect(overlayDe(modo), findsNothing);
    }
  });

  readerTest('solo el deslizado mueve la página entrante', (tester, h) async {
    await h.setAnimation('slide');
    await abrirLargo(tester, h);
    expect(desplazamientoEntrante(tester), 0);

    await h.turnForward(tester);
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      desplazamientoEntrante(tester).abs(),
      greaterThan(0),
      reason: 'la entrante no acompaña al deslizamiento',
    );

    await settleReader(tester);
    expect(desplazamientoEntrante(tester), 0, reason: 'no acabó encajada');
  });

  readerTest('el fundido no desplaza la página entrante', (tester, h) async {
    await h.setAnimation('fade');
    await abrirLargo(tester, h);

    await h.turnForward(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(desplazamientoEntrante(tester), 0);
    }
    await settleReader(tester);
  });

  readerTest('pasar página guarda el progreso', (tester, h) async {
    await h.seedBook(chapters: ['<p>${h.words(900)}</p>']);
    await h.pumpReader(tester);
    expect(await h.db.readProgress('libro'), isNull);

    await h.setAnimation('none');
    await settleReader(tester, rounds: 4);
    await h.turnForward(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await settleReader(tester, rounds: 4);

    final progreso = await h.db.readProgress('libro');
    expect(progreso, isNotNull, reason: 'no se guardó nada');
    expect(progreso!.percent, greaterThan(0));
    expect(progreso.locator, startsWith('spine:'));
  });

  readerTest('al reabrir vuelve al capítulo guardado', (tester, h) async {
    await h.seedBook(
      chapters: [
        '<p>${h.words(40)}</p>',
        '<p>${h.words(40)}</p>',
        '<p>${h.words(40)}</p>',
      ],
      locator: 'spine:2#0',
      percent: 0.9,
    );
    await h.pumpReader(tester);

    expect(find.text('Capítulo 3 de 3'), findsOneWidget);
  });

  readerTest('el marcador se pone y se quita', (tester, h) async {
    await h.seedBook(chapters: ['<p>${h.words(60)}</p>']);
    await h.pumpReader(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await settleReader(tester, rounds: 4);
    expect(await h.bookmarks(), hasLength(1));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark));
    await settleReader(tester, rounds: 4);
    expect(await h.bookmarks(), isEmpty);

    await tester.pump(const Duration(seconds: 3));
  });

  readerTest('el wakelock sigue al ajuste', (tester, h) async {
    await h.db.saveReaderPrefs(
      const ReaderSettings().copyWith(keepAwake: true).toCompanion(),
    );
    await h.seedBook(chapters: ['<p>${h.words(40)}</p>']);
    await h.pumpReader(tester);

    expect(h.wakelock.on, isTrue, reason: 'no se activó al abrir');
  });
}
