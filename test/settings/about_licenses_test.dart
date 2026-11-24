// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';

void main() {
  testWidgets('las licencias se abren desde la versión, sin enlace propio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1275, 800);
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
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    final version = find.textContaining('GPL-3.0-or-later');
    await tester.scrollUntilVisible(
      version,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Licencias'), findsNothing);
    expect(find.text('De dónde viene Lanna'), findsOneWidget);

    await tester.tap(version);
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
