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

const _sections = ['Colecciones', 'Autores', 'Estadísticas', 'Ajustes'];

void main() {
  for (final size in const [Size(1400, 900), Size(760, 900), Size(400, 900)]) {
    final w = size.width.toInt();

    testWidgets('las secciones no desbordan a ${w}px', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 4; i++) {
        await db.upsertBook(
          BooksCompanion.insert(
            id: 'b$i',
            title: 'Un título de libro bastante largo número $i',
            filePath: '/libros/b$i.epub',
            format: BookFormat.epub,
            author: Value('Autor $i'),
          ),
        );
      }

      tester.view.physicalSize = size;
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
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
      expect(tester.takeException(), isNull, reason: 'Biblioteca a ${w}px');

      for (final label in _sections) {
        if (find.text(label).evaluate().isEmpty) {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(Icons.menu_book_outlined),
            ),
          );
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(label).first);
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label a ${w}px');
      }

      expect(find.text('Animación de paso de página'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
