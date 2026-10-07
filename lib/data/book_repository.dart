// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'library/book_metadata.dart';
import 'library/folder_access.dart';
import 'library/library_scanner.dart';
import 'local/app_database.dart';
import 'local/database_provider.dart';
import 'transfer/progress_transfer.dart';

Future<LibraryDirs> defaultLibraryDirs() async {
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  return (
    covers: p.join(support.path, 'library', 'covers'),
    cache: cache.path,
    legacyBooks: p.join(support.path, 'library', 'books'),
  );
}

class BookRepository {
  BookRepository(
    this._db,
    this._access, {
    Future<LibraryDirs> Function() dirs = defaultLibraryDirs,
  }) : _dirs = dirs,
       _scanner = LibraryScanner(_db, _access, dirs);

  final AppDatabase _db;
  final Future<LibraryDirs> Function() _dirs;
  final FolderAccess _access;
  final LibraryScanner _scanner;

  FolderAccess get folderAccess => _access;

  Stream<List<LibraryFolder>> watchFolders() => _db.watchFolders();

  Future<LibraryFolder?> pickFolder() async {
    final picked = await _access.pick();
    if (picked == null) return null;
    final existing = await _db.findFolderByLocation(picked.location);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _db.addFolder(
      LibraryFoldersCompanion.insert(
        id: id,
        location: picked.location,
        name: picked.name,
      ),
    );
    return (await _db.findFolderByLocation(picked.location))!;
  }

  Future<void> removeFolder(LibraryFolder folder) async {
    final books = await _db.booksInFolder(folder.id);
    await _db.deleteFolder(folder.id);
    try {
      await _access.release(folder.location);
    } catch (_) {}
    for (final book in books) {
      await _discardDerived(book);
    }
  }

  Future<ScanReport> scan({void Function(int done, int total)? onProgress}) =>
      _scanner.scanAll(onProgress: onProgress);

  Future<OpenedFile> openBookFile(Book book) => _access.open(book.filePath);

  Future<Uint8List> exportProgress() => ProgressTransfer(_db).export();

  Future<ProgressImportReport> importProgress(Uint8List bytes) =>
      ProgressTransfer(_db).import(bytes);

  Future<int> shrinkCovers() async {
    final dirs = await _dirs();
    final marker = File(p.join(dirs.covers, '.miniaturas-$coverWidth'));
    if (marker.existsSync()) return 0;
    var shrunk = 0;
    for (final book in await _db.select(_db.books).get()) {
      final cover = book.coverPath;
      if (cover == null || !File(cover).existsSync()) continue;
      try {
        final smaller = await shrinkCover(cover, book.id, dirs.covers);
        if (smaller == null || smaller == cover) continue;
        await _db.updateBook(
          book.id,
          BooksCompanion(coverPath: Value(smaller)),
        );
        await File(cover).delete();
        shrunk++;
      } catch (_) {}
    }
    try {
      await marker.parent.create(recursive: true);
      await marker.writeAsString('');
    } catch (_) {}
    return shrunk;
  }

  Stream<List<Book>> watchFavorites() => _db.watchFavorites();

  Future<void> setFavorite(String id, bool favorite) =>
      _db.setFavorite(id, favorite);

  Stream<List<Book>> watchArchived() => _db.watchArchived();

  Future<void> setSeries(List<String> ids, String? name) =>
      _db.setSeries(ids, name?.trim() ?? '');

  Future<void> restoreSeries(Map<String, String?> seriesById) =>
      _db.setSeriesById(seriesById);

  Future<void> restoreBook(String id) =>
      _db.updateBook(id, const BooksCompanion(hidden: Value(false)));

  Future<void> hideBook(String id) =>
      _db.updateBook(id, const BooksCompanion(hidden: Value(true)));

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

  Future<void> markFinished(String bookId) => _db.markFinished(bookId);

  Future<void> setFinished(String bookId, {required bool finished}) =>
      _db.setFinished(bookId, finished: finished);

  Future<void> addReadingSession({
    required String bookId,
    required DateTime startedAt,
    required int seconds,
    required double startPercent,
    required double endPercent,
    required int pages,
  }) => _db.addReadingSession(
    ReadingSessionsCompanion.insert(
      bookId: bookId,
      startedAt: startedAt,
      seconds: seconds,
      startPercent: Value(startPercent),
      endPercent: Value(endPercent),
      pages: Value(pages),
    ),
  );

  Future<void> setReadingDirection(String bookId, String? direction) =>
      _db.setReadingDirection(bookId, direction);

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

  Stream<List<Highlight>> watchHighlights(String bookId) =>
      _db.watchHighlights(bookId);

  Future<void> addHighlight({
    required String bookId,
    required String cfi,
    required String text,
    required String color,
    int? chapterIndex,
    required double percent,
  }) => _db.addHighlight(
    HighlightsCompanion.insert(
      id: const Uuid().v4(),
      bookId: bookId,
      cfi: cfi,
      content: Value(text),
      color: Value(color),
      chapterIndex: Value(chapterIndex),
      percent: Value(percent),
    ),
  );

  Future<void> setHighlightColor(String id, String color) =>
      _db.updateHighlight(id, color: color);

  Future<void> setHighlightNote(String id, String? note) =>
      _db.updateHighlight(id, note: Value(note));

  Future<void> deleteHighlight(String id) => _db.deleteHighlight(id);

  Stream<List<CollectionWithCount>> watchCollections() =>
      _db.watchCollections();

  Future<Collection?> findCollection(String id) => _db.findCollection(id);

  Future<String> createCollection(String name) async {
    final id = const Uuid().v4();
    await _db.createCollection(id, name.trim());
    return id;
  }

  Future<void> renameCollection(String id, String name) =>
      _db.renameCollection(id, name.trim());

  Future<void> deleteCollection(String id) => _db.deleteCollection(id);

  Stream<List<Book>> watchCollectionBooks(String id) =>
      _db.watchCollectionBooks(id);

  Stream<Set<String>> watchCollectionIdsForBook(String bookId) =>
      _db.watchCollectionIdsForBook(bookId);

  Future<void> addBookToCollection(String collectionId, String bookId) =>
      _db.addBookToCollection(collectionId, bookId);

  Future<void> removeBookFromCollection(String collectionId, String bookId) =>
      _db.removeBookFromCollection(collectionId, bookId);

  Future<void> deleteBook(String id) async {
    final book = await _db.findBook(id);
    if (book == null) return;
    if (book.folderId != null) return hideBook(id);
    await _db.deleteBook(id);
    final file = File(book.filePath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await _discardDerived(book);
  }

  Future<void> deleteFromDevice(String id) async {
    final book = await _db.findBook(id);
    if (book == null) return;
    if (book.folderId == null) return deleteBook(id);
    await _access.delete(book.filePath);
    await _db.deleteBook(id);
    await _discardDerived(book);
  }

  Future<void> _discardDerived(Book book) async {
    if (book.coverPath case final cover?) {
      try {
        final file = File(cover);
        if (file.existsSync()) await file.delete();
      } catch (_) {}
    }
    try {
      final cache = await getApplicationCacheDirectory();
      final extracted = Directory(p.join(cache.path, 'reader', book.id));
      if (extracted.existsSync()) await extracted.delete(recursive: true);
    } catch (_) {}
  }
}

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(folderAccessProvider),
  );
});

final libraryFoldersProvider = StreamProvider<List<LibraryFolder>>((ref) {
  return ref.watch(bookRepositoryProvider).watchFolders();
});

final progressByBookProvider = StreamProvider<Map<String, double>>((ref) {
  return ref.watch(appDatabaseProvider).watchAllProgress();
});

final archivedProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).watchArchived();
});

final favoritesProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).watchFavorites();
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

final highlightsProvider = StreamProvider.family<List<Highlight>, String>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).watchHighlights(bookId);
});

final collectionsProvider = StreamProvider<List<CollectionWithCount>>((ref) {
  return ref.watch(bookRepositoryProvider).watchCollections();
});

final collectionBooksProvider = StreamProvider.family<List<Book>, String>((
  ref,
  collectionId,
) {
  return ref.watch(bookRepositoryProvider).watchCollectionBooks(collectionId);
});

final bookCollectionsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).watchCollectionIdsForBook(bookId);
});

final findBookProvider = FutureProvider.family<Book?, String>((ref, bookId) {
  return ref.watch(bookRepositoryProvider).findBook(bookId);
});
