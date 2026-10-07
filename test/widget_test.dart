// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/widgets/book_grid.dart';
import 'package:lanna/features/library/widgets/filters_panel.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase db, {
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const LannaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca en la biblioteca vacía', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpApp(tester, db);

    expect(find.text('Biblioteca'), findsWidgets);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('la búsqueda filtra el grid', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
        author: const Value('Julio Cortázar'),
      ),
    );
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'b',
        title: 'Kafka en la orilla',
        filePath: '/b.epub',
        format: BookFormat.epub,
        author: const Value('Haruki Murakami'),
      ),
    );

    await _pumpApp(tester, db);
    expect(find.text('Rayuela'), findsWidgets);
    expect(find.text('Kafka en la orilla'), findsWidgets);

    await tester.enterText(find.byType(EditableText), 'cortazar');
    await tester.pumpAndSettle();

    expect(find.text('Rayuela'), findsWidgets);
    expect(find.text('Kafka en la orilla'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'rayuela julio');
    await tester.pumpAndSettle();
    expect(find.text('Rayuela'), findsWidgets);
    expect(find.text('Kafka en la orilla'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin resultados'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el menú de orden marca el orden activo', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
      ),
    );

    await _pumpApp(tester, db);
    Future<Offset> checkNextTo(String label) async {
      await tester.tap(find.text('Recientes').first);
      await tester.pumpAndSettle();
      return tester.getCenter(find.byIcon(Icons.check));
    }

    final first = await checkNextTo('Recientes');
    expect(
      first.dy,
      moreOrLessEquals(
        tester.getCenter(find.text('Recientes').last).dy,
        epsilon: 4,
      ),
    );
    await tester.tap(find.text('Título'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Título').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.check)).dy,
      moreOrLessEquals(
        tester.getCenter(find.text('Título').last).dy,
        epsilon: 4,
      ),
    );

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el menú del libro se abre junto al cursor', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
      ),
    );

    await _pumpApp(tester, db);
    final cover = tester.getRect(find.byType(BookGridTile).first);
    final click = cover.center;
    await tester.tapAt(click, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.text('Abrir'));
    expect((menu.left - click.dx).abs(), lessThan(48));
    expect((menu.top - click.dy).abs(), lessThan(48));

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el menú contextual del libro ofrece eliminar', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
        author: const Value('Julio Cortázar'),
      ),
    );

    await _pumpApp(tester, db);
    expect(find.text('Rayuela'), findsWidgets);

    await tester.longPress(find.text('Rayuela').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Abrir'), findsOneWidget);
    expect(find.text('Detalles'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('los filtros de formato y estado acotan la biblioteca', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, format) in [
      ('Novela leída', BookFormat.epub),
      ('Novela a medias', BookFormat.epub),
      ('Manual nuevo', BookFormat.pdf),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: id,
          filePath: '/Libros/$id',
          format: format,
        ),
      );
    }
    await db.saveProgress(bookId: 'Novela leída', percent: 1);
    await db.saveProgress(bookId: 'Novela a medias', percent: 0.4);

    await _pumpApp(tester, db);
    Finder tile(String title) => find.descendant(
      of: find.byType(BookGridTile),
      matching: find.text(title),
    );
    Future<void> pick(String option) async {
      await tester.tap(
        find.descendant(
          of: find.byType(FiltersPanel),
          matching: find.text(option),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(find.byType(FiltersPanel), findsOneWidget);
    await pick('EPUB');
    expect(tile('Novela leída'), findsWidgets);
    expect(tile('Novela a medias'), findsWidgets);
    expect(tile('Manual nuevo'), findsNothing);

    await pick('Terminados');
    expect(tile('Novela leída'), findsWidgets);
    expect(tile('Novela a medias'), findsNothing);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.byType(FiltersPanel), findsNothing);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Seguir leyendo'.toUpperCase()), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await pick('PDF');
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Ningún libro coincide con los filtros'), findsOneWidget);

    await tester.tap(find.text('Quitar filtros'));
    await tester.pumpAndSettle();
    for (final title in ['Novela leída', 'Novela a medias', 'Manual nuevo']) {
      expect(tile(title), findsWidgets, reason: title);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el panel de filtros se adapta al cambiar la ventana', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
      ),
    );

    await _pumpApp(tester, db);
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FiltersPanel),
        matching: find.text('EPUB'),
      ),
    );
    await tester.pumpAndSettle();

    void expectPopover() {
      final button = tester.getRect(find.byType(FiltersButton));
      final panel = tester.getRect(find.byType(FiltersPanel));
      expect(panel.right, moreOrLessEquals(button.right, epsilon: 1));
      expect(panel.top, greaterThan(button.bottom));
    }

    bool epubSelected() => tester
        .widget<FilterPill>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(FiltersPanel),
              matching: find.text('EPUB'),
            ),
            matching: find.byType(FilterPill),
          ),
        )
        .selected;

    expectPopover();
    tester.view.physicalSize = const Size(1000, 760);
    await tester.pumpAndSettle();
    expectPopover();

    tester.view.physicalSize = const Size(500, 700);
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(FiltersPanel));
    expect(sheet.bottom, moreOrLessEquals(700, epsilon: 1));
    expect(sheet.width, moreOrLessEquals(500, epsilon: 1));
    expect(epubSelected(), isTrue);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expectPopover();
    expect(epubSelected(), isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el panel flotante no se corta en una ventana baja', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
      ),
    );

    await _pumpApp(tester, db, size: const Size(1000, 420));
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find
          .ancestor(
            of: find.byType(FiltersPanel),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(panel.bottom, lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Listo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('en pantalla estrecha los filtros salen como hoja inferior', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/a.epub',
        format: BookFormat.epub,
      ),
    );

    await _pumpApp(tester, db, size: const Size(400, 860));
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(FiltersPanel));
    expect(panel.bottom, moreOrLessEquals(860, epsilon: 1));
    expect(panel.width, moreOrLessEquals(400, epsilon: 1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('los tomos de una serie se agrupan y se abren en un modal', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, path) in [
      ('n2', 'Naruto Vol. 2.cbz'),
      ('n10', 'Naruto Vol. 10.cbz'),
      ('n1', 'Naruto Vol. 1.cbz'),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Tomo $id',
          filePath: '/Libros/$path',
          format: BookFormat.comic,
          relativePath: Value(path),
          series: const Value('Naruto'),
        ),
      );
    }
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'r',
        title: 'Rayuela',
        filePath: '/Libros/Rayuela.epub',
        format: BookFormat.epub,
      ),
    );
    await db.saveProgress(bookId: 'n1', percent: 1);

    await _pumpApp(tester, db);

    expect(find.text('Naruto'), findsOneWidget);
    expect(find.text('3 tomos'), findsOneWidget);
    expect(find.text('Rayuela'), findsWidgets);
    expect(find.text('Tomo n2'), findsNothing);
    expect(find.text('Tomo n10'), findsNothing);

    await tester.tap(find.text('Naruto'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('3 tomos · 1 leídos'), findsOneWidget);
    final order = [
      for (final id in ['n1', 'n2', 'n10'])
        tester.getTopLeft(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.text('Tomo $id'),
              )
              .last,
        ),
    ];
    expect(order[0].dx < order[1].dx && order[1].dx < order[2].dx, isTrue);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'naruto 10');
    await tester.pumpAndSettle();

    expect(find.text('Tomo n10'), findsWidgets);
    expect(find.text('Tomo n2'), findsNothing);
    expect(find.text('3 tomos'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('un libro archivado se recupera con Deshacer y desde Ajustes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addFolder(
      LibraryFoldersCompanion.insert(
        id: 'libros',
        location: '/Libros',
        name: 'Libros',
      ),
    );
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/Libros/Rayuela.epub',
        format: BookFormat.epub,
        folderId: const Value('libros'),
        relativePath: const Value('Rayuela.epub'),
      ),
    );
    await db.saveProgress(bookId: 'a', percent: 0.4);

    await _pumpApp(tester, db);
    Future<void> archive() async {
      await tester.longPress(find.text('Rayuela').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ajustes → Libros archivados'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Archivar'));
      await tester.pumpAndSettle();
    }

    await archive();
    expect(find.text('Rayuela'), findsNothing);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('Rayuela'), findsWidgets);

    await archive();
    expect(find.text('Rayuela'), findsNothing);
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Deshacer'), findsNothing);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Libros archivados · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Libros archivados · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Libros · Rayuela.epub'), findsOneWidget);

    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay libros archivados'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Libros archivados'), findsNothing);

    final book = await tester.runAsync(() => db.findBook('a'));
    expect(book?.hidden, isFalse);
    final progress = await tester.runAsync(() => db.readProgress('a'));
    expect(progress?.percent, 0.4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('un libro archivado se elimina del dispositivo tras confirmar', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addFolder(
      LibraryFoldersCompanion.insert(
        id: 'libros',
        location: '/Libros',
        name: 'Libros',
      ),
    );
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'a',
        title: 'Rayuela',
        filePath: '/Libros/Rayuela.epub',
        format: BookFormat.epub,
        folderId: const Value('libros'),
        relativePath: const Value('Rayuela.epub'),
        hidden: const Value(true),
      ),
    );

    await _pumpApp(tester, db);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Libros archivados · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Libros archivados · 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar del dispositivo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Rayuela» del dispositivo?'), findsOneWidget);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Libros · Rayuela.epub'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar del dispositivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay libros archivados'), findsOneWidget);
    expect(find.text('«Rayuela» eliminado del dispositivo'), findsOneWidget);
    expect(await tester.runAsync(() => db.findBook('a')), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('las series se renombran, se fusionan y se separan a mano', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, path, series) in [
      ('a1', 'NARUTO 1-27/Tomo 01.cbr', 'NARUTO 1-27'),
      ('a2', 'NARUTO 1-27/Tomo 02.cbr', 'NARUTO 1-27'),
      ('b28', 'NARUTO 28-72/Tomo 28.cbr', 'NARUTO 28-72'),
      ('b29', 'NARUTO 28-72/Tomo 29.cbr', 'NARUTO 28-72'),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Tomo $id',
          filePath: '/Libros/$path',
          format: BookFormat.comic,
          relativePath: Value(path),
          series: Value(series),
        ),
      );
    }

    await _pumpApp(tester, db);
    Future<void> renameTo(String series, String name) async {
      await tester.tap(find.text(series).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones de la serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar serie'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(EditableText),
        ),
        name,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();
    }

    await renameTo('NARUTO 1-27', 'Naruto');
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Naruto')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await renameTo('NARUTO 28-72', 'naruto');
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('4 tomos')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('4 tomos'), findsOneWidget);
    expect(find.textContaining('NARUTO'), findsNothing);

    await tester.tap(find.text('4 tomos'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.longPress(
      find
          .descendant(of: find.byType(Dialog), matching: find.text('Tomo b29'))
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serie…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la serie'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('3 tomos')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Opciones de la serie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Separar tomos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('3 tomos')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Opciones de la serie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Separar tomos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Separar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('3 tomos'), findsNothing);

    Future<Map<String, String?>> series() async {
      final rows = await tester.runAsync(() => db.select(db.books).get());
      return {for (final b in rows!) b.id: b.series};
    }

    expect(await series(), {'a1': '', 'a2': '', 'b28': '', 'b29': ''});

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(await series(), {
      'a1': 'Naruto',
      'a2': 'Naruto',
      'b28': 'naruto',
      'b29': '',
    });
    expect(find.text('3 tomos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('varios cómics se mueven a una serie de una vez', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, format, series) in [
      ('c1', BookFormat.comic, null),
      ('c2', BookFormat.comic, null),
      ('c3', BookFormat.comic, 'Akira'),
      ('e1', BookFormat.epub, null),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Libro $id',
          filePath: '/Libros/$id',
          format: format,
          series: Value(series),
        ),
      );
    }

    await _pumpApp(tester, db);
    await tester.longPress(find.text('Libro c1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionado'), findsOneWidget);

    await tester.tap(find.text('Libro c2').last);
    await tester.tap(find.text('Libro c3').last);
    await tester.tap(find.text('Libro e1').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('3 seleccionados'), findsOneWidget);

    await tester.tap(find.text('Mover a serie'));
    await tester.pumpAndSettle();
    expect(find.text('Mover 3 tomos a una serie'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(EditableText),
      ),
      'Akira',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();

    Future<Map<String, String?>> series() async {
      final rows = await tester.runAsync(() => db.select(db.books).get());
      return {for (final b in rows!) b.id: b.series};
    }

    expect(await series(), {
      'c1': 'Akira',
      'c2': 'Akira',
      'c3': 'Akira',
      'e1': null,
    });
    expect(find.text('Biblioteca'), findsWidgets);
    expect(find.text('3 tomos'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(await series(), {'c1': null, 'c2': null, 'c3': 'Akira', 'e1': null});

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('cada portada lleva la etiqueta de su formato', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, path, format) in [
      ('e', 'Novela.epub', BookFormat.epub),
      ('p', 'Manual.pdf', BookFormat.pdf),
      ('r', 'Manga/Tomo 01.cbr', BookFormat.comic),
      ('z', 'Manga/Tomo 02.cbz', BookFormat.comic),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Libro $id',
          filePath: '/Libros/$path',
          format: format,
          relativePath: Value(path),
        ),
      );
    }

    await _pumpApp(tester, db);

    for (final label in ['EPUB', 'PDF', 'CBR', 'CBZ']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('un libro marcado como favorito aparece en Favoritos', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, title) in [('a', 'Rayuela'), ('b', 'Kafka en la orilla')]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: title,
          filePath: '/$id.epub',
          format: BookFormat.epub,
        ),
      );
    }

    await _pumpApp(tester, db);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.longPress(find.text('Rayuela').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir a favoritos'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Rayuela'), findsWidgets);
    expect(find.text('Kafka en la orilla'), findsNothing);

    await tester.longPress(find.text('Rayuela').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Rayuela'), findsNothing);
    expect(find.textContaining('Todavía no tienes favoritos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('la búsqueda encuentra un tomo por su carpeta y archivo', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, path) in [
      ('t9', 'Manga/Boku dake ga Inai Machi/Tomo 09.cbr'),
      ('t1', 'Manga/Boku dake ga Inai Machi/Tomo 01.cbr'),
      ('ak', 'Manga/Akira/Tomo 09.cbz'),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Título $id',
          filePath: '/Libros/$path',
          format: BookFormat.comic,
          relativePath: Value(path),
        ),
      );
    }

    await _pumpApp(tester, db);
    await tester.enterText(find.byType(EditableText), 'boku 09');
    await tester.pumpAndSettle();

    expect(find.text('Título t9'), findsWidgets);
    expect(find.text('Título t1'), findsNothing);
    expect(find.text('Título ak'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('una serie completa se archiva tras confirmar y se deshace', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, series) in [
      ('n1', 'Naruto'),
      ('n2', 'Naruto'),
      ('n3', 'Naruto'),
      ('a1', 'Akira'),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Tomo $id',
          filePath: '/Libros/$id.cbz',
          format: BookFormat.comic,
          series: Value(series),
        ),
      );
    }

    await _pumpApp(tester, db);
    Future<void> archiveSeries({required bool confirm}) async {
      await tester.tap(find.text('3 tomos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Opciones de la serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar serie'));
      await tester.pumpAndSettle();
      expect(find.text('¿Archivar «Naruto»?'), findsOneWidget);
      await tester.tap(
        confirm
            ? find.widgetWithText(FilledButton, 'Archivar')
            : find.text('Cancelar'),
      );
      await tester.pumpAndSettle();
    }

    Future<Set<String>> hidden() async {
      final rows = await tester.runAsync(() => db.select(db.books).get());
      return {
        for (final b in rows!)
          if (b.hidden) b.id,
      };
    }

    await archiveSeries(confirm: false);
    expect(await hidden(), isEmpty);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await archiveSeries(confirm: true);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('3 tomos'), findsNothing);
    expect(await hidden(), {'n1', 'n2', 'n3'});

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(await hidden(), isEmpty);
    expect(find.text('3 tomos'), findsOneWidget);

    await archiveSeries(confirm: true);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Libros archivados · 3'));
    expect(find.text('Libros archivados · 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('la búsqueda muestra primero las series y luego los libros', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (final (id, title, format, series) in [
      ('guia', 'Naruto, guía oficial', BookFormat.epub, null),
      ('n1', 'Tomo 1', BookFormat.comic, 'Naruto'),
      ('n2', 'Tomo 2', BookFormat.comic, 'Naruto'),
      ('r', 'Rayuela', BookFormat.epub, null),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: title,
          filePath: '/Libros/$id',
          format: format,
          series: Value(series),
          addedAt: Value(DateTime(2026, 1, id == 'guia' ? 9 : 1)),
        ),
      );
    }

    await _pumpApp(tester, db);
    await tester.enterText(find.byType(EditableText), 'naruto');
    await tester.pumpAndSettle();

    expect(find.byType(SeriesGridTile), findsOneWidget);
    expect(find.byType(BookGridTile), findsOneWidget);
    expect(find.text('Rayuela'), findsNothing);
    expect(
      tester.getTopLeft(find.byType(SeriesGridTile)).dx,
      lessThan(tester.getTopLeft(find.byType(BookGridTile)).dx),
    );

    await tester.tap(find.text('2 tomos'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Tomo 2')),
      findsWidgets,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Ctrl+F y / llevan al buscador, Esc lo limpia', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpApp(tester, db);

    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText));
    expect(field().focusNode.hasFocus, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(field().focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(EditableText), 'kafka');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(field().focusNode.hasFocus, isFalse);
    expect(field().controller.text, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
    await tester.pump();
    expect(field().focusNode.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('en pantalla estrecha usa NavigationBar y no desborda', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpApp(tester, db, size: const Size(400, 860));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Animación de paso de página'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final size in const [Size(980, 800), Size(1280, 800), Size(1680, 900)]) {
    testWidgets('el grid no desborda a ${size.width.toInt()}px', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      for (var i = 0; i < 12; i++) {
        await db.upsertBook(
          BooksCompanion.insert(
            id: 'b$i',
            title: 'Un título bastante largo número $i para probar el ajuste',
            filePath: '/libros/b$i.epub',
            format: BookFormat.epub,
            author: Value('Autor $i'),
          ),
        );
      }

      await _pumpApp(tester, db, size: size);

      expect(find.textContaining('Un título bastante largo'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
