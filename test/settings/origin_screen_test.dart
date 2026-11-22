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
import 'package:lanna/features/settings/origin_screen.dart';

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

  Future<void> pumpApp(WidgetTester tester, Size size) async {
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
  }

  Future<void> openOrigin(WidgetTester tester) async {
    final settings = find.byIcon(Icons.settings_outlined);
    await tester.tap(settings.first);
    await tester.pumpAndSettle();
    final link = find.text('De dónde viene Lanna');
    await tester.scrollUntilVisible(
      link,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(link);
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
    testWidgets('a ${size.width.toInt()}px la historia se ve completa', (
      tester,
    ) async {
      await pumpApp(tester, size);
      await openOrigin(tester);

      expect(find.byType(OriginScreen), findsOneWidget);
      expect(find.text('El nombre'), findsOneWidget);
      expect(find.text('El logo'), findsOneWidget);
      expect(find.text('Foto de Lanna'), findsOneWidget);
      expect(find.text('Foto de Zoe'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final name = tester.getRect(find.text('Foto de Lanna'));
      final logo = tester.getRect(find.text('Foto de Zoe'));
      if (size.width >= 720 + 260) {
        expect(name.center.dy, closeTo(logo.center.dy, 1));
      } else {
        expect(logo.top, greaterThan(name.bottom));
      }

      if (shotsDir != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$shotsDir/origen-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      }

      await tester.tap(find.byIcon(Icons.chevron_left).first);
      await tester.pumpAndSettle();
      expect(find.byType(OriginScreen), findsNothing);
      await unmount(tester);
    });
  }
}
