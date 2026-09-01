// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/features/reader/reader_theme.dart';

void main() {
  test('ReaderSettings.fromRow usa defaults sin fila', () {
    const s = ReaderSettings();
    final fromNull = ReaderSettings.fromRow(null);
    expect(fromNull.preset, s.preset);
    expect(fromNull.fontScale, s.fontScale);
  });

  test('ReaderThemePreset expone CSS hex de 6 dígitos', () {
    expect(ReaderThemePreset.dark.cssBackground, matches(r'#[0-9a-f]{6}$'));
    expect(ReaderThemePreset.sepia.cssForeground, '#5b4636');
    expect(ReaderThemePreset.dark.cssLink, matches(r'#[0-9a-f]{6}$'));
    expect(ReaderThemePreset.fromId('desconocido'), ReaderThemePreset.dark);
  });

  test('toPresentation lleva fondo, texto y enlace del preset', () {
    const s = ReaderSettings(preset: ReaderThemePreset.dark);
    final p = s.toPresentation();
    expect(p.background, ReaderThemePreset.dark.cssBackground);
    expect(p.foreground, ReaderThemePreset.dark.cssForeground);
    expect(p.link, ReaderThemePreset.dark.cssLink);
  });

  test('fontScale se limita al rango permitido', () {
    const s = ReaderSettings(fontScale: 110);
    expect(s.copyWith(fontScale: 999).fontScale, ReaderSettings.maxScale);
    expect(s.copyWith(fontScale: 10).fontScale, ReaderSettings.minScale);
  });

  test('preferencias del lector: una sola fila que se actualiza', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.watchReaderPrefs().first, isNull);

    await db.saveReaderPrefs(
      ReaderPrefsCompanion.insert(
        theme: const Value('sepia'),
        fontScale: const Value(130),
      ),
    );
    await db.saveReaderPrefs(
      ReaderPrefsCompanion.insert(fontFamily: const Value('sans')),
    );

    final row = await db.watchReaderPrefs().first;
    expect(row, isNotNull);
    expect(row!.fontFamily, 'sans');
    expect(row.theme, 'sepia');
    expect((await db.select(db.readerPrefs).get()).length, 1);
  });
}
