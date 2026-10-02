// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/reader/native/page_canvas.dart';
import 'package:lanna/features/reader/reader_screen.dart';
import 'package:lanna/features/reader/reader_theme.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/support/reader_harness.dart' show buildReaderEpub;

double _pct(List<double> xs, double q) {
  final i = ((xs.length - 1) * q).round().clamp(0, xs.length - 1);
  return xs[i];
}

String _ms(double us) => (us / 1000).toStringAsFixed(2);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  String words(int count) =>
      List.generate(count, (i) => 'palabra${i % 10}').join(' ');

  Future<AppDatabase> seed(String animacion) async {
    final dir = await getApplicationSupportDirectory();
    File(p.join(dir.path, 'perf.epub')).writeAsBytesSync(
      buildReaderEpub(
        chapters: [
          for (var i = 0; i < 6; i++)
            '<h2>Capítulo $i</h2><p>${words(1200)}</p>',
        ],
        title: 'Banco de pruebas',
      ),
    );

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.upsertBook(
      BooksCompanion.insert(
        id: 'perf',
        title: 'Banco de pruebas',
        filePath: p.join(dir.path, 'perf.epub'),
        format: BookFormat.epub,
        author: const Value('Autora'),
      ),
    );
    await db.saveReaderPrefs(
      const ReaderSettings().copyWith(pageAnimation: animacion).toCompanion(),
    );
    return db;
  }

  Future<void> medir(WidgetTester tester, String animacion) async {
    final db = await seed(animacion);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ReaderScreen(bookId: 'perf')),
      ),
    );
    final limite = DateTime.now().add(const Duration(seconds: 30));
    while (find.byType(NativePage).evaluate().isEmpty &&
        DateTime.now().isBefore(limite)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(find.byType(NativePage), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final centro = tester.getCenter(find.byType(NativePage));
    final frames = <FrameTiming>[];
    void recoger(List<FrameTiming> t) => frames.addAll(t);

    binding.addTimingsCallback(recoger);
    for (var i = 0; i < 14; i++) {
      await tester.timedDragFrom(
        centro,
        const Offset(-260, 0),
        const Duration(milliseconds: 320),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    }
    binding.removeTimingsCallback(recoger);

    final build =
        frames.map((f) => f.buildDuration.inMicroseconds.toDouble()).toList()
          ..sort();
    final raster =
        frames.map((f) => f.rasterDuration.inMicroseconds.toDouble()).toList()
          ..sort();
    final total =
        frames.map((f) => f.totalSpan.inMicroseconds.toDouble()).toList()
          ..sort();
    final perdidos = total.where((t) => t > 16666).length;

    debugPrint(
      'MEDIDA[$animacion] frames=${frames.length} '
      'build p50=${_ms(_pct(build, 0.5))} p90=${_ms(_pct(build, 0.9))} '
      'p99=${_ms(_pct(build, 0.99))} max=${_ms(build.last)} | '
      'raster p50=${_ms(_pct(raster, 0.5))} p90=${_ms(_pct(raster, 0.9))} '
      'p99=${_ms(_pct(raster, 0.99))} max=${_ms(raster.last)} | '
      'total p90=${_ms(_pct(total, 0.9))} '
      'fuera_de_presupuesto=$perdidos '
      '(${(perdidos * 100 / frames.length).toStringAsFixed(1)}%)',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
  }

  for (final animacion in ['slide', 'fade', 'none']) {
    testWidgets('pasar página · $animacion', (tester) async {
      await medir(tester, animacion);
    });
  }
}
