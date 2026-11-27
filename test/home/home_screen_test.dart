// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/home/home_screen.dart';
import 'package:lanna/features/library/library_screen.dart';

void main() {
  final shotsDir = Platform.environment['LANNA_SHOTS'];
  final boundary = GlobalKey();

  setUpAll(() async {
    for (final (family, files) in const [
      ('Manrope', ['assets/fonts/Manrope.ttf']),
      (
        'Newsreader',
        ['assets/fonts/Newsreader.ttf', 'assets/fonts/Newsreader-Italic.ttf'],
      ),
    ]) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load(file));
      }
      await loader.load();
    }
  });

  Future<AppDatabase> seeded() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now();
    for (var i = 0; i < 9; i++) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: 'b$i',
          title: 'Libro de prueba $i',
          author: const Value('Autora de prueba'),
          filePath: '/libros/$i.epub',
          format: i == 2 ? BookFormat.pdf : BookFormat.epub,
          addedAt: Value(now.subtract(Duration(days: i))),
        ),
      );
    }
    await db.saveProgress(bookId: 'b1', percent: 0.2);
    await db.saveProgress(bookId: 'b2', percent: 0.4, chapterIndex: 40);
    await db.saveProgress(bookId: 'b0', percent: 0.59);
    await db.addReadingSession(
      ReadingSessionsCompanion.insert(
        bookId: 'b0',
        startedAt: DateTime(now.year, now.month, now.day, 0, 1),
        seconds: 12 * 60,
      ),
    );
    return db;
  }

  Future<void> pumpApp(WidgetTester tester, AppDatabase db, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const LannaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (shotsDir == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$shotsDir/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('sin libros, el inicio invita a elegir la carpeta', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await pumpApp(tester, db, const Size(1275, 800));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    await unmount(tester);
  });

  for (final size in const [
    Size(400, 860),
    Size(1275, 800),
    Size(1919, 1000),
    Size(2560, 1400),
  ]) {
    testWidgets(
      'a ${size.width.toInt()}px abre en el libro que se está leyendo',
      (tester) async {
        final db = await seeded();
        addTearDown(db.close);
        await pumpApp(tester, db, size);

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Libro de prueba 0'), findsWidgets);
        expect(find.text('Seguir leyendo'), findsOneWidget);
        expect(find.text('59 % leído'), findsOneWidget);
        expect(find.text('Hoy llevas 12 de tus 20 minutos'), findsOneWidget);
        expect(find.text('También tienes abiertos'), findsOneWidget);
        expect(find.text('Pág. 41 · 40 %'), findsOneWidget);
        expect(find.text('Añadidos hace poco'), findsOneWidget);
        expect(find.text('Ver la biblioteca (9)'), findsOneWidget);
        expect(
          find.text('Ver tus estadísticas'),
          size.width >= 1919 ? findsOneWidget : findsNothing,
        );
        expect(find.text('Leíste hace un momento'), findsOneWidget);
        expect(find.textContaining('dispositivo'), findsNothing);

        await shot(tester, 'inicio-${size.width.toInt()}');
        await unmount(tester);
      },
    );
  }

  testWidgets('en el teléfono, la biblioteca vacía da la bienvenida con logo', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    Finder logo() =>
        find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'Lanna');

    await pumpApp(tester, db, const Size(400, 860));
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(logo(), findsOneWidget);
    expect(find.text('Elegir carpeta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, 'inicio-vacio-400');
    await unmount(tester);

    await pumpApp(tester, db, const Size(1275, 800));
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);
    expect(logo(), findsNothing);
    await unmount(tester);
  });

  testWidgets('en el teléfono, sin nada leído se ven varias filas de libros', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: 'b$i',
          title: 'Libro de prueba $i',
          filePath: '/libros/$i.epub',
          format: BookFormat.epub,
          addedAt: Value(now.subtract(Duration(hours: i))),
        ),
      );
    }
    await pumpApp(tester, db, const Size(400, 860));

    expect(find.text('Elige un libro para empezar a leer.'), findsOneWidget);
    expect(find.text('Libro de prueba 8'), findsWidgets);
    expect(find.text('Libro de prueba 9'), findsNothing);
    final button = find.text('Ver la biblioteca (12)');
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);
    await shot(tester, 'inicio-sin-leer-400');

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'en el teléfono, con lecturas en curso las secciones son listas',
    (tester) async {
      final db = await seeded();
      addTearDown(db.close);
      await pumpApp(tester, db, const Size(400, 860));

      expect(find.text('EPUB · añadido hoy'), findsOneWidget);
      expect(find.text('EPUB · añadido ayer'), findsOneWidget);
      expect(find.text('PDF · añadido hace 2 días'), findsOneWidget);
      expect(find.text('EPUB · añadido hace 5 días'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('el enlace lleva a la biblioteca', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await pumpApp(tester, db, const Size(1275, 800));

    await tester.tap(find.text('Ver la biblioteca (9)'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('buscar desde el inicio pasa a la biblioteca con la búsqueda', (
    tester,
  ) async {
    final db = await seeded();
    addTearDown(db.close);
    await pumpApp(tester, db, const Size(1275, 800));

    await tester.enterText(find.byType(TextField).first, 'prueba 3');
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'prueba 3',
    );
    await unmount(tester);
  });
}
