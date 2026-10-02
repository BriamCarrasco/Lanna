// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../import/fingerprint.dart';
import '../models/book_format.dart';
import 'tables.dart';

part 'app_database.g.dart';

class BookWithProgress {
  const BookWithProgress(this.book, this.progress);
  final Book book;
  final ReadingProgressData progress;
}

class CollectionWithCount {
  const CollectionWithCount(this.collection, this.bookCount);
  final Collection collection;
  final int bookCount;
}

@DriftDatabase(
  tables: [
    LibraryFolders,
    Books,
    ReadingProgress,
    ReaderPrefs,
    Bookmarks,
    Collections,
    CollectionEntries,
    Highlights,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'lanna'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

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
      if (from < 5) {
        await m.addColumn(readerPrefs, readerPrefs.pageAnimation);
        await m.addColumn(readerPrefs, readerPrefs.edgeTaps);
        await m.addColumn(readerPrefs, readerPrefs.keepAwake);
      }
      if (from < 6) {
        await m.createTable(bookmarks);
      }
      if (from < 7) {
        await m.createTable(collections);
        await m.createTable(collectionEntries);
      }
      if (from < 8) {
        await m.createTable(highlights);
      }
      if (from < 9) {
        await m.addColumn(readerPrefs, readerPrefs.engine);
      }
      if (from < 10) {
        await customStatement('DROP TABLE IF EXISTS book_locations');
      }
      if (from < 11) {
        await m.addColumn(books, books.contentHash);
      }
      if (from < 12) {
        await refreshFingerprints();
      }
      if (from < 13) {
        await m.addColumn(books, books.readingDirection);
      }
      if (from < 14) {
        await m.createTable(libraryFolders);
        await m.addColumn(books, books.folderId);
        await m.addColumn(books, books.relativePath);
        await m.addColumn(books, books.fileModified);
        await m.addColumn(books, books.available);
        await m.addColumn(books, books.hidden);
      }
      if (from < 15) {
        await m.addColumn(books, books.favoritedAt);
      }
      if (from < 16) {
        await m.addColumn(books, books.series);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<Book>> watchLibrary() {
    return (select(books)
          ..where((b) => b.hidden.equals(false))
          ..orderBy([(b) => OrderingTerm.desc(b.addedAt)]))
        .watch();
  }

  Future<void> setSeries(List<String> ids, String series) {
    return transaction(() async {
      for (final id in ids) {
        await updateBook(id, BooksCompanion(series: Value(series)));
      }
    });
  }

  Stream<List<Book>> watchArchived() {
    return (select(books)
          ..where((b) => b.hidden.equals(true))
          ..orderBy([(b) => OrderingTerm.asc(b.title)]))
        .watch();
  }

  Stream<List<Book>> watchFavorites() {
    return (select(books)
          ..where((b) => b.hidden.equals(false) & b.favoritedAt.isNotNull())
          ..orderBy([(b) => OrderingTerm.desc(b.favoritedAt)]))
        .watch();
  }

  Future<void> setFavorite(String id, bool favorite) {
    return updateBook(
      id,
      BooksCompanion(favoritedAt: Value(favorite ? DateTime.now() : null)),
    );
  }

  Stream<List<LibraryFolder>> watchFolders() {
    return (select(
      libraryFolders,
    )..orderBy([(f) => OrderingTerm.asc(f.addedAt)])).watch();
  }

  Future<List<LibraryFolder>> allFolders() => select(libraryFolders).get();

  Future<LibraryFolder?> findFolderByLocation(String location) {
    return (select(
      libraryFolders,
    )..where((f) => f.location.equals(location))).getSingleOrNull();
  }

  Future<void> addFolder(LibraryFoldersCompanion folder) {
    return into(libraryFolders).insert(folder);
  }

  Future<void> deleteFolder(String id) {
    return (delete(libraryFolders)..where((f) => f.id.equals(id))).go();
  }

  Future<List<Book>> booksInFolder(String folderId) {
    return (select(books)..where((b) => b.folderId.equals(folderId))).get();
  }

  Future<void> updateBook(String id, BooksCompanion changes) {
    return (update(books)..where((b) => b.id.equals(id))).write(changes);
  }

  Stream<List<BookWithProgress>> watchContinueReading({int limit = 4}) {
    final query =
        select(books).join([
            innerJoin(
              readingProgress,
              readingProgress.bookId.equalsExp(books.id),
            ),
          ])
          ..where(
            readingProgress.percent.isSmallerThanValue(0.99) &
                books.hidden.equals(false),
          )
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

  Future<Book?> findBookByHash(String hash) {
    return (select(books)
          ..where((b) => b.contentHash.equals(hash))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> setReadingDirection(String bookId, String? direction) {
    return (update(books)..where((b) => b.id.equals(bookId))).write(
      BooksCompanion(readingDirection: Value(direction)),
    );
  }

  Future<void> refreshFingerprints() async {
    final rows = await (selectOnly(
      books,
    )..addColumns([books.id, books.filePath])).get();
    final ids = [for (final r in rows) r.read(books.id)!];
    final paths = [for (final r in rows) r.read(books.filePath)!];
    final prints = await fingerprintFiles(paths);
    for (var i = 0; i < ids.length; i++) {
      await (update(books)..where((b) => b.id.equals(ids[i]))).write(
        BooksCompanion(contentHash: Value(prints[i])),
      );
    }
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

  Stream<Map<String, double>> watchAllProgress() {
    return select(readingProgress)
        .watch()
        .map((rows) => {for (final r in rows) r.bookId: r.percent});
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

  Stream<List<Highlight>> watchHighlights(String bookId) {
    return (select(highlights)
          ..where((h) => h.bookId.equals(bookId))
          ..orderBy([(h) => OrderingTerm.asc(h.percent)]))
        .watch();
  }

  Future<void> addHighlight(HighlightsCompanion highlight) {
    return into(highlights).insertOnConflictUpdate(highlight);
  }

  Future<void> updateHighlight(
    String id, {
    String? color,
    Value<String?> note = const Value.absent(),
  }) {
    return (update(highlights)..where((h) => h.id.equals(id))).write(
      HighlightsCompanion(
        color: color == null ? const Value.absent() : Value(color),
        note: note,
      ),
    );
  }

  Future<void> deleteHighlight(String id) {
    return (delete(highlights)..where((h) => h.id.equals(id))).go();
  }

  Stream<List<CollectionWithCount>> watchCollections() {
    final count = collectionEntries.bookId.count();
    final query = select(collections).join([
      leftOuterJoin(
        collectionEntries,
        collectionEntries.collectionId.equalsExp(collections.id),
      ),
    ]);
    query
      ..addColumns([count])
      ..groupBy([collections.id])
      ..orderBy([OrderingTerm.asc(collections.name)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => CollectionWithCount(
              r.readTable(collections),
              r.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<Collection?> findCollection(String id) {
    return (select(
      collections,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> createCollection(String id, String name) {
    return into(collections)
        .insert(CollectionsCompanion.insert(id: id, name: name));
  }

  Future<void> renameCollection(String id, String name) {
    return (update(collections)..where((c) => c.id.equals(id))).write(
      CollectionsCompanion(name: Value(name)),
    );
  }

  Future<void> deleteCollection(String id) {
    return (delete(collections)..where((c) => c.id.equals(id))).go();
  }

  Stream<List<Book>> watchCollectionBooks(String collectionId) {
    final query =
        select(books).join([
            innerJoin(
              collectionEntries,
              collectionEntries.bookId.equalsExp(books.id),
            ),
          ])
          ..where(collectionEntries.collectionId.equals(collectionId))
          ..orderBy([OrderingTerm.desc(collectionEntries.addedAt)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(books)).toList(),
    );
  }

  Stream<Set<String>> watchCollectionIdsForBook(String bookId) {
    return (select(collectionEntries)..where((e) => e.bookId.equals(bookId)))
        .watch()
        .map((rows) => rows.map((e) => e.collectionId).toSet());
  }

  Future<void> addBookToCollection(String collectionId, String bookId) {
    return into(collectionEntries).insertOnConflictUpdate(
      CollectionEntriesCompanion.insert(
        collectionId: collectionId,
        bookId: bookId,
      ),
    );
  }

  Future<void> removeBookFromCollection(String collectionId, String bookId) {
    return (delete(collectionEntries)..where(
          (e) => e.collectionId.equals(collectionId) & e.bookId.equals(bookId),
        ))
        .go();
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
