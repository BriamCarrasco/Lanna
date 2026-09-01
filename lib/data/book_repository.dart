// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'import/book_importer.dart';
import 'local/app_database.dart';
import 'local/database_provider.dart';

class BookRepository {
  BookRepository(this._db) : _importer = BookImporter(_db);

  final AppDatabase _db;
  final BookImporter _importer;

  Stream<List<Book>> watchLibrary() => _db.watchLibrary();

  Stream<List<BookWithProgress>> watchContinueReading() =>
      _db.watchContinueReading();

  Stream<ReadingProgressData?> watchProgress(String bookId) =>
      _db.watchProgress(bookId);

  Future<Book?> findBook(String id) => _db.findBook(id);

  Future<ReadingProgressData?> readProgress(String bookId) =>
      _db.readProgress(bookId);

  Future<void> saveProgress({
    required String bookId,
    String? locator,
    required double percent,
    int? chapterIndex,
  }) => _db.saveProgress(
    bookId: bookId,
    locator: locator,
    percent: percent,
    chapterIndex: chapterIndex,
  );

  Future<void> markOpened(String bookId) => _db.touchLastOpened(bookId);

  Future<String?> readLocations(String bookId) => _db.readLocations(bookId);

  Future<void> saveLocations(String bookId, String data) =>
      _db.saveLocations(bookId, data);

  Stream<List<Bookmark>> watchBookmarks(String bookId) =>
      _db.watchBookmarks(bookId);

  Future<void> addBookmark({
    required String bookId,
    required String cfi,
    int? chapterIndex,
    required double percent,
    String? label,
  }) => _db.addBookmark(
    BookmarksCompanion.insert(
      id: const Uuid().v4(),
      bookId: bookId,
      cfi: cfi,
      chapterIndex: Value(chapterIndex),
      percent: Value(percent),
      label: Value(label),
    ),
  );

  Future<void> deleteBookmark(String id) => _db.deleteBookmark(id);

  Future<ImportResult> importFile(String path) => _importer.importFile(path);

  Future<void> deleteBook(String id) async {
    final book = await _db.findBook(id);
    await _db.deleteBook(id);
    if (book == null) return;

    for (final path in [book.filePath, book.coverPath]) {
      if (path == null || path.startsWith('sample://')) continue;
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    try {
      final cache = await getApplicationCacheDirectory();
      final extracted = Directory(p.join(cache.path, 'reader', id));
      if (extracted.existsSync()) await extracted.delete(recursive: true);
    } catch (_) {}
  }
}

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(appDatabaseProvider));
});

final libraryProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).watchLibrary();
});

final continueReadingProvider = StreamProvider<List<BookWithProgress>>((ref) {
  return ref.watch(bookRepositoryProvider).watchContinueReading();
});

final bookmarksProvider = StreamProvider.family<List<Bookmark>, String>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).watchBookmarks(bookId);
});

final bookProgressProvider =
    StreamProvider.family<ReadingProgressData?, String>((ref, bookId) {
      return ref.watch(bookRepositoryProvider).watchProgress(bookId);
    });

final findBookProvider = FutureProvider.family<Book?, String>((ref, bookId) {
  return ref.watch(bookRepositoryProvider).findBook(bookId);
});
