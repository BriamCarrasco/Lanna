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

  test('de v9 a v11: cae la tabla muerta y llega content_hash', () async {
    final db = await atSchema9();
    addTearDown(db.close);
    expect(await hasTable(db, 'book_locations'), isTrue);
    expect(await columns(db, 'books'), isNot(contains('content_hash')));

    await db.migration.onUpgrade(Migrator(db), 9, 11);

    expect(await hasTable(db, 'book_locations'), isFalse);
    expect(await columns(db, 'books'), contains('content_hash'));
  });

  test('si book_locations nunca existió, la migración no revienta', () async {
    final db = await atSchema9(withDeadTable: false);
    addTearDown(db.close);

    await expectLater(db.migration.onUpgrade(Migrator(db), 9, 11), completes);
    expect(await columns(db, 'books'), contains('content_hash'));
  });

  test('las tablas vivas siguen ahí tras migrar', () async {
    final db = await atSchema9();
    addTearDown(db.close);

    await db.migration.onUpgrade(Migrator(db), 9, 11);

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

  test('una base ya en v11 no se toca', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await expectLater(db.migration.onUpgrade(Migrator(db), 11, 11), completes);
    expect(await columns(db, 'books'), contains('content_hash'));
  });
}
