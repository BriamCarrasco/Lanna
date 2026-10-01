// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../import/fingerprint.dart';
import '../local/app_database.dart';
import '../models/book_format.dart';
import '../storage/random_source.dart';
import 'book_metadata.dart';
import 'folder_access.dart';
import 'series.dart';

typedef LibraryDirs = ({String covers, String cache, String legacyBooks});

class ScanReport {
  const ScanReport({
    this.added = 0,
    this.relocated = 0,
    this.missing = 0,
    this.failed = 0,
    this.unreachable = const [],
  });

  final int added;
  final int relocated;
  final int missing;
  final int failed;
  final List<String> unreachable;
}

class LibraryScanner {
  LibraryScanner(this._db, this._access, this._dirs);

  final AppDatabase _db;
  final FolderAccess _access;
  final Future<LibraryDirs> Function() _dirs;
  final _uuid = const Uuid();

  Future<ScanReport> scanAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final folders = await _db.allFolders();
    final listed = <(LibraryFolder, List<FolderEntry>?)>[];
    for (final folder in folders) {
      try {
        listed.add((folder, _books(await _access.list(folder.location))));
      } catch (_) {
        listed.add((folder, null));
      }
    }
    final total = listed.fold<int>(0, (n, e) => n + (e.$2?.length ?? 0));
    var done = 0;
    onProgress?.call(done, total);

    var added = 0, relocated = 0, missing = 0, failed = 0;
    final unreachable = <String>[];
    final seen = <String>{};
    final claimed = <(LibraryFolder, FolderEntry, Book?)>[];
    final others = <(LibraryFolder, FolderEntry, Book?)>[];
    final reachable = <LibraryFolder>[];
    for (final (folder, entries) in listed) {
      if (entries == null) {
        unreachable.add(folder.name);
        missing += await _markMissing(folder.id, const {});
        continue;
      }
      reachable.add(folder);
      final known = {
        for (final b in await _db.booksInFolder(folder.id))
          if (b.relativePath != null) b.relativePath!: b,
      };
      for (final entry in entries) {
        final book = known[entry.relativePath];
        (book != null ? claimed : others).add((folder, entry, book));
      }
    }

    for (final (folder, entry, book) in [...claimed, ...others]) {
      try {
        switch (await _scanEntry(folder, entry, book, seen)) {
          case _Outcome.added:
            added++;
          case _Outcome.relocated:
            relocated++;
          case _Outcome.unchanged:
            break;
        }
      } catch (_) {
        failed++;
      }
      onProgress?.call(++done, total);
    }
    for (final folder in reachable) {
      missing += await _markMissing(folder.id, seen);
    }
    return ScanReport(
      added: added,
      relocated: relocated,
      missing: missing,
      failed: failed,
      unreachable: unreachable,
    );
  }

  List<FolderEntry> _books(List<FolderEntry> entries) => [
    for (final e in entries)
      if (formatForName(e.relativePath) != null &&
          !e.relativePath.split('/').any((s) => s.startsWith('.')))
        e,
  ];

  Future<_Outcome> _scanEntry(
    LibraryFolder folder,
    FolderEntry entry,
    Book? known,
    Set<String> seen,
  ) async {
    if (known != null &&
        known.fileSizeBytes == entry.size &&
        known.fileModified == entry.modified &&
        !seen.contains(known.id)) {
      seen.add(known.id);
      final series = _missingSeries(known, entry);
      if (!known.available ||
          known.filePath != entry.location ||
          series != null) {
        await _db.updateBook(
          known.id,
          BooksCompanion(
            filePath: Value(entry.location),
            available: const Value(true),
            series: series == null ? const Value.absent() : Value(series),
          ),
        );
      }
      return _Outcome.unchanged;
    }

    final opened = await _access.open(entry.location);
    try {
      final spec = opened.spec;
      final hash = await Isolate.run(() {
        final source = openSource(spec);
        try {
          return fingerprintSource(source);
        } finally {
          source.close();
        }
      });
      final match = known?.contentHash == hash
          ? known
          : await _db.findBookByHash(hash);
      if (match != null) {
        if (seen.contains(match.id)) return _Outcome.unchanged;
        seen.add(match.id);
        final series = _missingSeries(match, entry);
        await _db.updateBook(
          match.id,
          _location(folder, entry, hash).copyWith(
            series: series == null ? const Value.absent() : Value(series),
          ),
        );
        if (match.folderId == null) await _discardLegacyCopy(match.filePath);
        return _Outcome.relocated;
      }

      final id = _uuid.v4();
      final format = formatForName(entry.relativePath)!;
      final dirs = await _dirs();
      await Directory(dirs.covers).create(recursive: true);
      final meta = await readBookMeta(
        spec: spec,
        format: format,
        id: id,
        coversDir: dirs.covers,
        cacheDir: dirs.cache,
      );
      final fallback = p.posix.basenameWithoutExtension(entry.relativePath);
      await _db.upsertBook(
        _location(folder, entry, hash).copyWith(
          id: Value(id),
          title: Value(
            meta.title?.trim().isNotEmpty == true ? meta.title! : fallback,
          ),
          author: Value(meta.author),
          coverPath: Value(meta.coverPath),
          format: Value(format),
          series: Value(
            format == BookFormat.comic
                ? (meta.series ?? seriesFromFileName(entry.relativePath))
                : null,
          ),
        ),
      );
      seen.add(id);
      return _Outcome.added;
    } finally {
      opened.close();
    }
  }

  String? _missingSeries(Book book, FolderEntry entry) {
    if (book.format != BookFormat.comic || book.series != null) return null;
    return seriesFromFileName(entry.relativePath);
  }

  BooksCompanion _location(
    LibraryFolder folder,
    FolderEntry entry,
    String hash,
  ) => BooksCompanion(
    folderId: Value(folder.id),
    relativePath: Value(entry.relativePath),
    filePath: Value(entry.location),
    fileSizeBytes: Value(entry.size),
    fileModified: Value(entry.modified),
    contentHash: Value(hash),
    available: const Value(true),
  );

  Future<void> _discardLegacyCopy(String path) async {
    final dirs = await _dirs();
    if (!p.isWithin(dirs.legacyBooks, path)) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<int> _markMissing(String folderId, Set<String> seen) async {
    var count = 0;
    for (final book in await _db.booksInFolder(folderId)) {
      if (seen.contains(book.id) || !book.available) continue;
      await _db.updateBook(
        book.id,
        const BooksCompanion(available: Value(false)),
      );
      count++;
    }
    return count;
  }
}

enum _Outcome { added, relocated, unchanged }
