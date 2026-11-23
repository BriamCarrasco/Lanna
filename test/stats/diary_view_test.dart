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
import 'package:lanna/features/stats/diary_view.dart';
import 'package:lanna/features/stats/stats_screen.dart';

ReadingSession _session(
  String bookId,
  DateTime start,
  int minutes, {
  int pages = 0,
  double from = 0,
  double to = 0,
}) => ReadingSession(
  id: 0,
  bookId: bookId,
  startedAt: start,
  seconds: minutes * 60,
  startPercent: from,
  endPercent: to,
  pages: pages,
);

void main() {
  final shotsDir = Platform.environment['LANNA_SHOTS'];
  final boundary = GlobalKey();

  group('diaryEntries', () {
    test(
      'junta las sesiones del mismo libro y día, lo más reciente primero',
      () {
        final day = DateTime(2026, 11, 20);
        final entries = diaryEntries([
          _session('a', day.add(const Duration(hours: 21)), 10, pages: 4),
          _session('a', day.add(const Duration(hours: 8)), 15, pages: 6),
          _session(
            'b',
            day.add(const Duration(hours: 12)),
            5,
            from: 0.1,
            to: 0.13,
          ),
          _session('a', day.add(const Duration(days: 1, hours: 9)), 20),
        ], since: DateTime(2026, 11));

        expect(entries, hasLength(3));
        expect(entries.first.day, DateTime(2026, 11, 21));
        final a = entries.firstWhere((e) => e.bookId == 'a' && e.day == day);
        expect(a.seconds, 25 * 60);
        expect(a.pages, 10);
        expect(a.startedAt, day.add(const Duration(hours: 8)));
        final b = entries.firstWhere((e) => e.bookId == 'b');
        expect(b.progressed, closeTo(0.03, 1e-9));
      },
    );

    test('deja fuera lo anterior a la fecha y respeta el límite', () {
      final sessions = [
        for (var i = 0; i < 12; i++)
          _session('b$i', DateTime(2026, 11, 1 + i, 20), 10),
      ];
      final entries = diaryEntries(
        sessions,
        since: DateTime(2026, 11, 3),
        limit: 5,
      );
      expect(entries, hasLength(5));
      expect(
        entries.every((e) => !e.day.isBefore(DateTime(2026, 11, 3))),
        isTrue,
      );
    });
  });

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
    for (final id in ['a', 'b']) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: 'Libro de prueba $id',
          filePath: '/libros/$id.epub',
          format: BookFormat.epub,
          finishedAt: Value(id == 'b' ? now : null),
        ),
      );
    }
    await db.addReadingSession(
      ReadingSessionsCompanion.insert(
        bookId: 'a',
        startedAt: DateTime(now.year, now.month, now.day, 0, 5),
        seconds: 25 * 60,
        pages: const Value(18),
      ),
    );
    return db;
  }

  Future<void> pumpStats(WidgetTester tester, AppDatabase db, Size size) async {
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
    await tester.tap(find.byIcon(Icons.insights_outlined).first);
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final size in const [
    Size(400, 860),
    Size(1275, 800),
    Size(1919, 1000),
    Size(2560, 1400),
  ]) {
    testWidgets('a ${size.width.toInt()}px el diario es la vista por defecto', (
      tester,
    ) async {
      final db = await seeded();
      addTearDown(db.close);
      await pumpStats(tester, db, size);

      expect(tester.takeException(), isNull);
      expect(find.byType(DiaryView), findsOneWidget);
      expect(find.byType(StatsViewToggle), findsOneWidget);
      expect(
        find.textContaining('Esta semana leíste', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Lo que leíste'), findsOneWidget);
      expect(find.text('25 min · 18 páginas'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^0?0:05$')), findsOneWidget);
      expect(find.text('Hoy'), findsWidgets);
      expect(find.text('Terminados en ${DateTime.now().year}'), findsOneWidget);
      expect(find.textContaining('dispositivo'), findsNothing);

      if (shotsDir != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$shotsDir/diario-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      await unmount(tester);
    });
  }

  testWidgets('la elección de vista se guarda', (tester) async {
    final db = await seeded();
    addTearDown(db.close);
    await pumpStats(tester, db, const Size(1275, 800));

    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryView), findsNothing);
    expect(find.text('Tiempo por mes'), findsOneWidget);
    final prefs = await db.select(db.readerPrefs).getSingle();
    expect(prefs.statsView, 'summary');

    await tester.tap(find.text('Diario'));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryView), findsOneWidget);
    await unmount(tester);
  });
}
