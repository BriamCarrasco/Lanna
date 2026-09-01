// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
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
