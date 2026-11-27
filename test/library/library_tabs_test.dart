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
import 'package:lanna/features/library/authors_screen.dart';
import 'package:lanna/features/library/favorites_screen.dart';
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
    for (var i = 0; i < 9; i++) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: 'b$i',
          title: 'Libro de prueba $i',
          author: Value('Autora de prueba ${i % 3}'),
          filePath: '/libros/$i.epub',
          format: BookFormat.epub,
        ),
      );
    }
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

  Finder inBar(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  int selectedInBar(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  for (final width in const [320.0, 360.0, 400.0]) {
    testWidgets('a ${width}px la barra tiene 4 secciones con etiqueta', (
      tester,
    ) async {
      final db = await seeded();
      addTearDown(db.close);
      await pumpApp(tester, db, Size(width, 860));

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(4));
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      expect(find.text('Todos'), findsNothing);

      await tester.tap(inBar('Biblioteca'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Ordenar')).center.dy,
        closeTo(tester.getRect(find.byType(TextField)).center.dy, 2),
      );
      await shot(tester, 'pestanas-todos-${width.toInt()}');

      await tester.tap(find.text('Favoritos').first);
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(selectedInBar(tester), 1);

      await tester.ensureVisible(find.text('Autores').first);
      await tester.tap(find.text('Autores').first);
      await tester.pumpAndSettle();
      expect(find.byType(AuthorsScreen), findsOneWidget);
      expect(selectedInBar(tester), 1);
      expect(find.text('3 autores'), findsNothing);
      await shot(tester, 'pestanas-autores-${width.toInt()}');

      await tester.tap(find.text('Colecciones').first);
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes colecciones'), findsOneWidget);
      expect(find.text('Nueva colección'), findsOneWidget);
      expect(find.byTooltip('Nueva colección'), findsNothing);
      expect(find.text('0 colecciones'), findsNothing);
      await shot(tester, 'pestanas-colecciones-${width.toInt()}');

      await tester.tap(inBar('Biblioteca'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryScreen), findsOneWidget);

      await tester.tap(inBar('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Todos'), findsNothing);

      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('en el teléfono se pasa de sección deslizando', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await pumpApp(tester, db, const Size(400, 860));
    await tester.tap(inBar('Biblioteca'));
    await tester.pumpAndSettle();

    final page = find.byType(PageView);
    Finder selectedTab(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.selected ?? false),
      ),
    );
    expect(selectedTab('Todos'), findsOneWidget);
    final drag = await tester.startGesture(tester.getCenter(page));
    await drag.moveBy(const Offset(-40, 0));
    await drag.moveBy(const Offset(-230, 0));
    await tester.pump();
    expect(selectedTab('Favoritos'), findsOneWidget);
    expect(selectedTab('Todos'), findsNothing);
    await drag.moveBy(const Offset(230, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(selectedTab('Todos'), findsOneWidget);
    expect(find.byType(LibraryScreen), findsOneWidget);

    await tester.fling(page, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing);
    expect(find.byTooltip('Ordenar'), findsNothing);

    await tester.fling(page, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    await tester.fling(page, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes colecciones'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byTooltip('Ordenar'), findsOneWidget);

    await tester.fling(page, const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(selectedInBar(tester), 1);

    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  for (final size in const [
    Size(1275, 800),
    Size(1919, 1000),
    Size(2560, 1400),
  ]) {
    testWidgets('a ${size.width.toInt()}px sigue la barra lateral', (
      tester,
    ) async {
      final db = await seeded();
      addTearDown(db.close);
      await pumpApp(tester, db, size);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Autores'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthorsScreen), findsOneWidget);
      expect(find.text('Todos'), findsNothing);
      await shot(tester, 'pestanas-ancho-${size.width.toInt()}');
      await unmount(tester);
    });
  }
}
