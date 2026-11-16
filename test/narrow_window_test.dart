// SPDX-License-Identifier: GPL-3.0-or-later
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
  setUpAll(() async {
    final manrope = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await manrope.load();
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
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const LannaApp(),
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

  for (final width in const [320.0, 360.0, 400.0, 480.0, 600.0]) {
    testWidgets('a ${width}px la barra no parte etiquetas en dos líneas', (
      tester,
    ) async {
      await pumpApp(tester, Size(width, 800));
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      if (bar.labelBehavior == NavigationDestinationLabelBehavior.alwaysHide) {
        expect(width, lessThan(420));
        await unmount(tester);
        return;
      }
      final labels = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Estadísticas'),
      );
      for (final element in labels.evaluate()) {
        final label = element.renderObject! as RenderParagraph;
        if (!label.hasSize || label.size.isEmpty) continue;
        final fontSize = label.text.style!.fontSize!;
        expect(label.size.height, lessThan(fontSize * 2));
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('a ${width}px el calendario cabe sin desplazarse', (
      tester,
    ) async {
      await pumpApp(tester, Size(width, 800));
      expect(find.textContaining(RegExp(r'^ÚLTIMOS \d+ MESES$')), findsOne);
      expect(find.text('ÚLTIMOS 12 MESES'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CustomPaint),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  for (final width in const [1100.0, 1400.0, 1920.0, 2200.0]) {
    testWidgets('a ${width}px se ven los 12 meses y el resumen', (
      tester,
    ) async {
      await pumpApp(tester, Size(width, 1000));
      expect(find.text('ÚLTIMOS 12 MESES'), findsOne);
      final grid = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_CalendarPainter',
        ),
      );
      final legend = tester.getRect(find.text('Más'));
      expect(legend.right - grid.right, lessThan(4));
      final panel = tester.getRect(find.text('Tiempo por mes'));
      if (width >= 1300) {
        expect(panel.left, greaterThan(grid.right));
        expect(panel.top, lessThan(grid.bottom));
        expect(panel.left - grid.right, lessThan(2 * 28 + 6));
      } else {
        expect(panel.top, greaterThan(grid.bottom));
      }
      await unmount(tester);
    });
  }
}
