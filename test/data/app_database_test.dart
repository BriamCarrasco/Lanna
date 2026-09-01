// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  BooksCompanion sampleBook(String id) => BooksCompanion.insert(
    id: id,
    title: 'Libro $id',
    filePath: '/libros/$id.epub',
    format: BookFormat.epub,
    author: const Value('Autora'),
  );

  test('upsert e inserción en la biblioteca', () async {
    await db.upsertBook(sampleBook('a'));
    final books = await db.watchLibrary().first;
    expect(books, hasLength(1));
    expect(books.single.title, 'Libro a');
    expect(books.single.format, BookFormat.epub);
  });

  test('watchLibrary ordena por addedAt descendente', () async {
    await db.upsertBook(
      sampleBook('viejo').copyWith(addedAt: Value(DateTime(2020))),
    );
    await db.upsertBook(
      sampleBook('nuevo').copyWith(addedAt: Value(DateTime(2026))),
    );
    final books = await db.watchLibrary().first;
    expect(books.map((b) => b.id), ['nuevo', 'viejo']);
  });

  test('saveProgress hace upsert de una fila por libro', () async {
    await db.upsertBook(sampleBook('a'));

    await db.saveProgress(bookId: 'a', locator: 'cfi/1', percent: 0.1);
    await db.saveProgress(bookId: 'a', locator: 'cfi/2', percent: 0.5);

    final progress = await db.watchProgress('a').first;
    expect(progress, isNotNull);
    expect(progress!.locator, 'cfi/2');
    expect(progress.percent, 0.5);
  });

  test('borrar un libro elimina su progreso en cascada', () async {
    await db.upsertBook(sampleBook('a'));
    await db.saveProgress(bookId: 'a', percent: 0.3);

    await db.deleteBook('a');

    expect(await db.watchLibrary().first, isEmpty);
    expect(await db.watchProgress('a').first, isNull);
  });

  test('cache de locations: guardar y leer, upsert por libro', () async {
    await db.upsertBook(sampleBook('a'));

    expect(await db.readLocations('a'), isNull);
    await db.saveLocations('a', '["cfi1","cfi2"]');
    await db.saveLocations('a', '["cfi1","cfi2","cfi3"]');

    expect(await db.readLocations('a'), '["cfi1","cfi2","cfi3"]');

    await db.deleteBook('a');
    expect(await db.readLocations('a'), isNull);
  });

  test('marcadores: añadir, ordenar por porcentaje, borrar en cascada', () async {
    await db.upsertBook(sampleBook('a'));

    expect(await db.watchBookmarks('a').first, isEmpty);

    await db.addBookmark(
      BookmarksCompanion.insert(
        id: 'm2',
        bookId: 'a',
        cfi: 'cfi/2',
        percent: const Value(0.6),
        label: const Value('Capítulo 6'),
      ),
    );
    await db.addBookmark(
      BookmarksCompanion.insert(
        id: 'm1',
        bookId: 'a',
        cfi: 'cfi/1',
        percent: const Value(0.2),
      ),
    );

    final list = await db.watchBookmarks('a').first;
    expect(list.map((b) => b.id), ['m1', 'm2']);
    expect(list.last.label, 'Capítulo 6');

    await db.deleteBookmark('m1');
    expect((await db.watchBookmarks('a').first).map((b) => b.id), ['m2']);

    await db.deleteBook('a');
    expect(await db.watchBookmarks('a').first, isEmpty);
  });

  test(
    'watchContinueReading: empezados y no terminados, por recencia',
    () async {
      for (final id in ['a', 'b', 'c', 'sin-empezar']) {
        await db.upsertBook(sampleBook(id));
      }
      Future<void> progress(String id, double pct, DateTime at) => db
          .into(db.readingProgress)
          .insertOnConflictUpdate(
            ReadingProgressCompanion.insert(
              bookId: id,
              percent: Value(pct),
              updatedAt: Value(at),
            ),
          );
      await progress('a', 0.2, DateTime(2026, 1, 1));
      await progress('b', 0.5, DateTime(2026, 3, 1));
      await progress('c', 0.999, DateTime(2026, 6, 1));

      final list = await db.watchContinueReading().first;
      expect(list.map((e) => e.book.id), ['b', 'a']);
      expect(list.first.progress.percent, 0.5);
    },
  );
}
