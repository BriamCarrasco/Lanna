// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';

void main() {
  Future<bool> hasTable(AppDatabase db, String name) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          variables: [Variable.withString(name)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<List<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.data['name'] as String];
  }

  Future<AppDatabase> atSchema9({bool withDeadTable = true}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('ALTER TABLE books DROP COLUMN content_hash');
    await db.customStatement('ALTER TABLE books DROP COLUMN reading_direction');
    if (withDeadTable) {
      await db.customStatement(
        'CREATE TABLE book_locations ('
        'book_id TEXT NOT NULL PRIMARY KEY, data TEXT NOT NULL)',
      );
      await db.customStatement(
        "INSERT INTO book_locations VALUES ('a', '[\"cfi\"]')",
      );
    }
    return db;
  }

  test(
    'de v9 a la actual: cae la tabla muerta y llegan las columnas nuevas',
    () async {
      final db = await atSchema9();
      addTearDown(db.close);
      expect(await hasTable(db, 'book_locations'), isTrue);
      expect(await columns(db, 'books'), isNot(contains('content_hash')));

      await db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion);

      expect(await hasTable(db, 'book_locations'), isFalse);
      expect(
        await columns(db, 'books'),
        containsAll(['content_hash', 'reading_direction']),
      );
    },
  );

  test('si book_locations nunca existió, la migración no revienta', () async {
    final db = await atSchema9(withDeadTable: false);
    addTearDown(db.close);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion),
      completes,
    );
    expect(await columns(db, 'books'), contains('content_hash'));
  });

  test('las tablas vivas siguen ahí tras migrar', () async {
    final db = await atSchema9();
    addTearDown(db.close);

    await db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion);

    for (final name in const [
      'books',
      'reading_progress',
      'reader_prefs',
      'bookmarks',
      'collections',
      'collection_entries',
      'highlights',
    ]) {
      expect(await hasTable(db, name), isTrue, reason: 'falta $name');
    }
  });

  test('de v12 a v13 llega la dirección de lectura', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('ALTER TABLE books DROP COLUMN reading_direction');

    await db.migration.onUpgrade(Migrator(db), 12, 13);

    expect(await columns(db, 'books'), contains('reading_direction'));
  });

  test('una base ya en la versión actual no se toca', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final version = db.schemaVersion;

    await expectLater(
      db.migration.onUpgrade(Migrator(db), version, version),
      completes,
    );
    expect(
      await columns(db, 'books'),
      containsAll(['content_hash', 'reading_direction']),
    );
  });
}
