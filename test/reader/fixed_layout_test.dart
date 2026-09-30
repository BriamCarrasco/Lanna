// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/comic/comic_engine_view.dart';
import 'package:lanna/features/reader/reader_theme.dart';

import '../support/reader_harness.dart';

const _pages = ['01.png', '02.png', '03.png'];

void main() {
  readerTest('un cómic abre en la misma carcasa que un EPUB', (
    tester,
    h,
  ) async {
    await h.seedComic(pages: _pages);
    await h.pumpReader(tester, id: 'comic');

    expect(tester.takeException(), isNull);
    expect(find.byType(ComicEngineView), findsOneWidget);
    expect(find.text('Página 1 de 3'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing, reason: 'sin texto');
  });

  readerTest('pasar página en un cómic guarda el progreso', (tester, h) async {
    await h.seedComic(pages: _pages);
    await h.pumpReader(tester, id: 'comic');
    await h.setAnimation('none');
    await settleReader(tester, rounds: 4);

    await h.turnForward(tester);
    await settleReader(tester, rounds: 4);
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await settleReader(tester, rounds: 4);
    final progreso = await h.db.readProgress('comic');
    expect(progreso?.locator, 'page:2');
  });

  readerTest('el curl también funciona en un cómic', (tester, h) async {
    await h.seedComic(pages: _pages);
    await h.pumpReader(tester, id: 'comic');
    await h.setAnimation('slide');
    await settleReader(tester, rounds: 4);

    await h.turnForward(tester);
    await settleReader(tester);

    expect(find.text('Página 2 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  readerTest('al reabrir vuelve a la página guardada', (tester, h) async {
    await h.seedComic(pages: _pages, locator: 'page:3');
    await h.pumpReader(tester, id: 'comic');

    expect(find.text('Página 3 de 3'), findsOneWidget);
  });

  readerTest('en pantalla ancha muestra páginas dobles', (tester, h) async {
    await h.db.saveReaderPrefs(
      const ReaderSettings().copyWith(columns: 'double').toCompanion(),
    );
    await h.seedComic(pages: _pages);
    await h.pumpReader(tester, id: 'comic', size: const Size(1200, 800));

    expect(find.text('Páginas 1–2 de 3'), findsOneWidget);

    await h.turnForward(tester);
    await settleReader(tester, rounds: 4);
    expect(find.text('Página 3 de 3'), findsOneWidget);
  });

  readerTest('un manga se lee de derecha a izquierda', (tester, h) async {
    await h.seedComic(
      pages: _pages,
      comicInfo: '<ComicInfo><Manga>YesAndRightToLeft</Manga></ComicInfo>',
    );
    await h.pumpReader(tester, id: 'comic');
    await h.setAnimation('none');
    await settleReader(tester, rounds: 4);

    await tester.flingFrom(const Offset(150, 400), const Offset(300, 0), 1200);
    await settleReader(tester, rounds: 4);

    expect(find.text('Página 2 de 3'), findsOneWidget);
  });

  readerTest('la dirección elegida para el libro manda sobre ComicInfo', (
    tester,
    h,
  ) async {
    await h.seedComic(
      pages: _pages,
      comicInfo: '<ComicInfo><Manga>YesAndRightToLeft</Manga></ComicInfo>',
    );
    await h.db.setReadingDirection('comic', 'ltr');
    await h.pumpReader(tester, id: 'comic');
    await h.setAnimation('none');
    await settleReader(tester, rounds: 4);

    await tester.flingFrom(const Offset(300, 400), const Offset(-300, 0), 1200);
    await settleReader(tester, rounds: 4);

    expect(find.text('Página 2 de 3'), findsOneWidget);
  });

  readerTest('desde Apariencia se cambia a derecha a izquierda', (
    tester,
    h,
  ) async {
    await h.seedComic(pages: _pages);
    await h.pumpReader(tester, id: 'comic');
    await h.setAnimation('none');
    await settleReader(tester, rounds: 4);

    await tester.tap(find.text('Aa'));
    await settleReader(tester, rounds: 4);
    expect(find.text('Lectura'), findsOneWidget);
    await tester.tap(find.text('Der → Izq'));
    await settleReader(tester, rounds: 4);
    await tester.tap(find.text('Aa'));
    await settleReader(tester, rounds: 4);

    await tester.flingFrom(const Offset(150, 400), const Offset(300, 0), 1200);
    await settleReader(tester, rounds: 4);
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settleReader(tester, rounds: 4);
    expect(find.text('Página 3 de 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settleReader(tester, rounds: 4);
    expect(find.text('Página 2 de 3'), findsOneWidget);

    final book = await tester.runAsync(() => h.db.findBook('comic'));
    expect(book?.readingDirection, 'rtl');
  });

  readerTest('un EPUB no ofrece cambiar la dirección', (tester, h) async {
    await h.seedBook(chapters: const ['<p>Hola</p>']);
    await h.pumpReader(tester);

    await tester.tap(find.text('Aa'));
    await settleReader(tester, rounds: 4);

    expect(find.text('Apariencia'), findsWidgets);
    expect(find.text('Lectura'), findsNothing);
  });

  readerTest('un CBZ dañado muestra un error en vez de colgarse', (
    tester,
    h,
  ) async {
    await h.seedComic(pages: _pages, bytes: [1, 2, 3, 4, 5, 6, 7, 8]);
    await h.pumpReader(tester, id: 'comic');

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.text('El archivo no es un CBZ ni un CBR válido'),
      findsOneWidget,
    );
  });
}
