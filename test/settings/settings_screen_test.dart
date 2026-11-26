// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';

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

  for (final size in const [
    Size(400, 860),
    Size(1275, 800),
    Size(1919, 1000),
    Size(2560, 1400),
  ]) {
    testWidgets('a ${size.width.toInt()}px Ajustes agrupa sin cajas', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.localesTestValue = const [Locale('es')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
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
      await tester.tap(find.text('Ajustes').last);
      await tester.pumpAndSettle();

      expect(find.text('Lectura'), findsOneWidget);
      expect(find.text('LECTURA'), findsNothing);
      expect(find.text('Respaldo'), findsOneWidget);
      expect(find.text('Exportar'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final heading = tester.getRect(find.text('Lectura'));
      final row = tester.getRect(find.text('Animación de paso de página'));
      expect(row.top, greaterThan(heading.bottom));
      expect(row.left, moreOrLessEquals(heading.left, epsilon: 1));
      final backup = tester.getRect(find.text('Respaldo'));
      expect(backup.left, moreOrLessEquals(heading.left, epsilon: 1));
      expect(backup.top, greaterThan(row.bottom));

      final folders = tester.getRect(find.text('Carpetas de la biblioteca'));
      final about = tester.getRect(find.text('Acerca de'));
      if (size.width >= 1275) {
        expect(about.left, greaterThan(folders.right));
        expect(about.top, moreOrLessEquals(folders.top, epsilon: 1));
      } else {
        expect(about.top, greaterThan(folders.bottom));
      }

      await shot(tester, 'ajustes-${size.width.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
