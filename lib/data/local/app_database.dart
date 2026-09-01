// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/book_format.dart';
import 'tables.dart';

part 'app_database.g.dart';

class BookWithProgress {
  const BookWithProgress(this.book, this.progress);
  final Book book;
  final ReadingProgressData progress;
}

@DriftDatabase(
  tables: [Books, ReadingProgress, ReaderPrefs, BookLocations, Bookmarks],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lanna'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(readingProgress, readingProgress.chapterIndex);
        await m.createTable(readerPrefs);
      }
      if (from < 3) {
        await m.addColumn(readerPrefs, readerPrefs.columns);
      }
      if (from < 4) {
        await m.createTable(bookLocations);
      }
      if (from < 5) {
        await m.addColumn(readerPrefs, readerPrefs.pageAnimation);
        await m.addColumn(readerPrefs, readerPrefs.edgeTaps);
        await m.addColumn(readerPrefs, readerPrefs.keepAwake);
      }
      if (from < 6) {
        await m.createTable(bookmarks);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<Book>> watchLibrary() {
    return (select(
      books,
    )..orderBy([(b) => OrderingTerm.desc(b.addedAt)])).watch();
  }

  Stream<List<BookWithProgress>> watchContinueReading({int limit = 4}) {
    final query =
        select(books).join([
            innerJoin(
              readingProgress,
              readingProgress.bookId.equalsExp(books.id),
            ),
          ])
          ..where(readingProgress.percent.isSmallerThanValue(0.99))
          ..orderBy([OrderingTerm.desc(readingProgress.updatedAt)])
          ..limit(limit);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => BookWithProgress(
              r.readTable(books),
              r.readTable(readingProgress),
            ),
          )
          .toList(),
    );
  }

  Future<Book?> findBook(String id) {
    return (select(books)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertBook(BooksCompanion book) {
    return into(books).insertOnConflictUpdate(book);
  }

  Future<void> deleteBook(String id) {
    return (delete(books)..where((b) => b.id.equals(id))).go();
  }

  Future<void> touchLastOpened(String id) {
    return (update(books)..where((b) => b.id.equals(id))).write(
      BooksCompanion(lastOpenedAt: Value(DateTime.now())),
    );
  }

  Stream<ReadingProgressData?> watchProgress(String bookId) {
    return (select(
      readingProgress,
    )..where((p) => p.bookId.equals(bookId))).watchSingleOrNull();
  }

  Future<ReadingProgressData?> readProgress(String bookId) {
    return (select(
      readingProgress,
    )..where((p) => p.bookId.equals(bookId))).getSingleOrNull();
  }

  Future<void> saveProgress({
    required String bookId,
    String? locator,
    required double percent,
    int? chapterIndex,
  }) {
    return into(readingProgress).insertOnConflictUpdate(
      ReadingProgressCompanion(
        bookId: Value(bookId),
        locator: Value(locator),
        percent: Value(percent),
        chapterIndex: Value(chapterIndex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> readLocations(String bookId) async {
    final row = await (select(
      bookLocations,
    )..where((l) => l.bookId.equals(bookId))).getSingleOrNull();
    return row?.data;
  }

  Future<void> saveLocations(String bookId, String data) {
    return into(bookLocations).insertOnConflictUpdate(
      BookLocationsCompanion.insert(
        bookId: bookId,
        data: data,
        generatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<Bookmark>> watchBookmarks(String bookId) {
    return (select(bookmarks)
          ..where((b) => b.bookId.equals(bookId))
          ..orderBy([(b) => OrderingTerm.asc(b.percent)]))
        .watch();
  }

  Future<void> addBookmark(BookmarksCompanion bookmark) {
    return into(bookmarks).insert(bookmark);
  }

  Future<void> deleteBookmark(String id) {
    return (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  Stream<ReaderPref?> watchReaderPrefs() {
    return (select(
      readerPrefs,
    )..where((p) => p.id.equals(0))).watchSingleOrNull();
  }

  Future<void> saveReaderPrefs(ReaderPrefsCompanion prefs) {
    return into(readerPrefs)
        .insertOnConflictUpdate(prefs.copyWith(id: const Value(0)));
  }
}
