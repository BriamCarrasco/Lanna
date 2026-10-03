// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/stats/stats_screen.dart';

void main() {
  Future<AppDatabase> seeded() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'b',
        title: 'Misery',
        filePath: '/libros/misery.epub',
        format: BookFormat.epub,
      ),
    );
    return db;
  }

  Future<void> pump(
    WidgetTester tester,
    AppDatabase db, {
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addMinutes(AppDatabase db, int daysAgo, int minutes) {
    final now = DateTime.now();
    return db.addReadingSession(
      ReadingSessionsCompanion.insert(
        bookId: 'b',
        startedAt: DateTime(now.year, now.month, now.day - daysAgo, 0, 1),
        seconds: minutes * 60,
      ),
    );
  }

  testWidgets('sin sesiones explica desde cuándo se mide', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await pump(tester, db);

    expect(find.textContaining('empieza a medir desde ahora'), findsOneWidget);
    expect(find.text('Sin racha'), findsOneWidget);
    expect(find.text('Faltan 20 min'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('muestra el día, la racha y el calendario', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await addMinutes(db, 0, 25);
    await addMinutes(db, 1, 30);
    await addMinutes(db, 2, 5);
    await db.markFinished('b');
    await pump(tester, db);

    expect(find.textContaining('empieza a medir'), findsNothing);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('Meta cumplida'), findsOneWidget);
    expect(find.text('2 días'), findsOneWidget);
    expect(find.text('1 libro terminado'), findsOneWidget);
    expect(find.text('Hoy · 25 min'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('cambiar la meta recalcula la racha', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await addMinutes(db, 0, 25);
    await pump(tester, db);
    expect(find.text('1 día'), findsOneWidget);

    await tester.tap(find.text('Meta: 20 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min al día').last);
    await tester.pumpAndSettle();

    expect(find.text('Meta: 30 min'), findsOneWidget);
    expect(find.text('Sin racha'), findsOneWidget);
    expect(find.text('Faltan 5 min'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  for (final width in [360.0, 700.0]) {
    testWidgets('no desborda a ${width.toInt()} px', (tester) async {
      final db = await seeded();
      addTearDown(db.close);
      await addMinutes(db, 3, 40);
      await pump(tester, db, width: width);

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
