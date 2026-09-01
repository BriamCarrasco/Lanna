// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';

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

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin resultados'), findsOneWidget);

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
