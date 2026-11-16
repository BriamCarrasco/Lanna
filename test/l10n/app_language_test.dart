// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/app.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/local/database_provider.dart';
import 'package:lanna/features/reader/reader_settings_provider.dart';
import 'package:lanna/l10n/l10n.dart';

void main() {
  test('el idioma del dispositivo decide y lo desconocido cae en inglés', () {
    const supported = AppLocalizations.supportedLocales;
    expect(
      resolveAppLocale(const Locale('es', 'CL'), supported).languageCode,
      'es',
    );
    expect(
      resolveAppLocale(const Locale('en', 'GB'), supported).languageCode,
      'en',
    );
    expect(resolveAppLocale(const Locale('fr'), supported).languageCode, 'en');
    expect(resolveAppLocale(null, supported).languageCode, 'en');
  });

  test('los dos idiomas tienen las mismas claves y marcadores', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;
    final es = read('app_es.arb');
    final en = read('app_en.arb');
    final keys = es.keys.where((k) => !k.startsWith('@')).toSet();
    expect(en.keys.where((k) => !k.startsWith('@')).toSet(), keys);
    final marker = RegExp(r'\{(\w+)[,}]');
    Set<String> markers(Object? text) =>
        marker.allMatches(text! as String).map((m) => m[1]!).toSet();
    for (final key in keys) {
      if (key.endsWith('Pattern')) continue;
      expect(markers(en[key]), markers(es[key]), reason: key);
    }
  });

  for (final size in const [Size(1400, 900), Size(760, 900), Size(400, 900)]) {
    testWidgets('en inglés las secciones no desbordan a ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
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
      expect(tester.takeException(), isNull);

      for (final icon in const [
        Icons.favorite_border,
        Icons.folder_outlined,
        Icons.collections_bookmark_outlined,
        Icons.person_outline,
        Icons.insights_outlined,
        Icons.settings_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$icon');
      }
      expect(find.text('App language'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  testWidgets('el ajuste manda sobre el sistema y cambia la app al momento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LannaApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);

    final controller = container.read(readerSettingsControllerProvider);
    await tester.runAsync(() => controller.setLanguage('es'));
    await tester.pumpAndSettle();
    expect(find.text('Tu biblioteca está vacía'), findsOneWidget);

    await tester.runAsync(() => controller.setLanguage('system'));
    await tester.pumpAndSettle();
    expect(find.text('Your library is empty'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
