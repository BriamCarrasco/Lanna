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

const _sections = <(String, IconData)>[
  ('Colecciones', Icons.folder_outlined),
  ('Autores', Icons.person_outline),
  ('Estadísticas', Icons.insights_outlined),
  ('Ajustes', Icons.settings_outlined),
];

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

      final narrow = size.width < 720;
      for (final (label, icon) in _sections) {
        final target = narrow
            ? find.descendant(
                of: find.byType(NavigationBar),
                matching: find.byIcon(icon),
              )
            : find.text(label);
        await tester.tap(target.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label a ${w}px');
      }

      expect(find.text('Animación de paso de página'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
