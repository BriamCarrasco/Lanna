// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';

const _bookColumnsSince = {
  11: ['content_hash'],
  13: ['reading_direction'],
  14: ['folder_id', 'relative_path', 'file_modified', 'available', 'hidden'],
};

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

  Future<AppDatabase> atSchema(
    int version, {
    bool withDeadTable = false,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final newer = {
      for (final entry in _bookColumnsSince.entries)
        if (entry.key > version) ...entry.value,
    };
    final keep = [
      for (final c in await columns(db, 'books'))
        if (!newer.contains(c)) c,
    ].join(', ');
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'CREATE TABLE books_old AS SELECT $keep FROM books',
    );
    await db.customStatement('DROP TABLE books');
    await db.customStatement('ALTER TABLE books_old RENAME TO books');
    if (version < 14) await db.customStatement('DROP TABLE library_folders');
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
      final db = await atSchema(9, withDeadTable: true);
      addTearDown(db.close);
      expect(await hasTable(db, 'book_locations'), isTrue);
      expect(await columns(db, 'books'), isNot(contains('content_hash')));

      await db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion);

      expect(await hasTable(db, 'book_locations'), isFalse);
      expect(await hasTable(db, 'library_folders'), isTrue);
      expect(await columns(db, 'books'), containsAll(_allNewColumns));
    },
  );

  test('si book_locations nunca existió, la migración no revienta', () async {
    final db = await atSchema(9);
    addTearDown(db.close);

    await expectLater(
      db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion),
      completes,
    );
    expect(await columns(db, 'books'), contains('content_hash'));
  });

  test('las tablas vivas siguen ahí tras migrar', () async {
    final db = await atSchema(9, withDeadTable: true);
    addTearDown(db.close);

    await db.migration.onUpgrade(Migrator(db), 9, db.schemaVersion);

    for (final name in const [
      'books',
      'library_folders',
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
    final db = await atSchema(12);
    addTearDown(db.close);

    await db.migration.onUpgrade(Migrator(db), 12, 13);

    expect(await columns(db, 'books'), contains('reading_direction'));
  });

  test('de v13 a v14 llegan las carpetas y los libros siguen ahí', () async {
    final db = await atSchema(13);
    addTearDown(db.close);
    await db.customStatement(
      'INSERT INTO books (id, title, file_path, format, added_at) '
      "VALUES ('uno', 'Uno', '/libros/uno.epub', 'epub', 0)",
    );

    await db.migration.onUpgrade(Migrator(db), 13, 14);

    expect(await hasTable(db, 'library_folders'), isTrue);
    final book = await db.findBook('uno');
    expect(book?.available, isTrue);
    expect(book?.hidden, isFalse);
    expect(book?.folderId, isNull);
  });

  test('una base ya en la versión actual no se toca', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final version = db.schemaVersion;

    await expectLater(
      db.migration.onUpgrade(Migrator(db), version, version),
      completes,
    );
    expect(await columns(db, 'books'), containsAll(_allNewColumns));
  });
}

final _allNewColumns = [for (final c in _bookColumnsSince.values) ...c];
