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
    final listed = await _listFolders();
    final tally = _Tally();
    final plan = await _plan(listed, tally);
    final total = plan.work.length;
    var done = 0;
    onProgress?.call(done, total);

    final seen = <String>{};
    for (final (folder, entry, book) in plan.work) {
      try {
        tally.record(await _scanEntry(folder, entry, book, seen));
      } catch (_) {
        tally.failed++;
      }
      onProgress?.call(++done, total);
    }
    for (final folder in plan.reachable) {
      tally.missing += await _markMissing(folder.id, seen);
    }
    return tally.report();
  }

  Future<List<(LibraryFolder, List<FolderEntry>?)>> _listFolders() async {
    final listed = <(LibraryFolder, List<FolderEntry>?)>[];
    for (final folder in await _db.allFolders()) {
      try {
        listed.add((folder, _books(await _access.list(folder.location))));
      } catch (_) {
        listed.add((folder, null));
      }
    }
    return listed;
  }

  Future<_Plan> _plan(
    List<(LibraryFolder, List<FolderEntry>?)> listed,
    _Tally tally,
  ) async {
    final claimed = <_Work>[];
    final others = <_Work>[];
    final reachable = <LibraryFolder>[];
    for (final (folder, entries) in listed) {
      if (entries == null) {
        tally.unreachable.add(folder.name);
        tally.missing += await _markMissing(folder.id, const {});
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
    return (work: [...claimed, ...others], reachable: reachable);
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
      await _refreshUnchanged(known, entry);
      return _Outcome.unchanged;
    }

    final opened = await _access.open(entry.location);
    try {
      final hash = await _fingerprint(opened.spec);
      final match = known?.contentHash == hash
          ? known
          : await _db.findBookByHash(hash);
      if (match == null) {
        final id = await _addNew(folder, entry, opened.spec, hash);
        seen.add(id);
        return _Outcome.added;
      }
      if (!seen.add(match.id)) return _Outcome.unchanged;
      await _relocate(match, folder, entry, hash);
      return _Outcome.relocated;
    } finally {
      opened.close();
    }
  }

  Future<void> _refreshUnchanged(Book known, FolderEntry entry) async {
    final series = _missingSeries(known, entry);
    if (known.available && known.filePath == entry.location && series == null) {
      return;
    }
    await _db.updateBook(
      known.id,
      BooksCompanion(
        filePath: Value(entry.location),
        available: const Value(true),
        series: _seriesValue(series),
      ),
    );
  }

  Future<String> _fingerprint(SourceSpec spec) => Isolate.run(() {
    final source = openSource(spec);
    try {
      return fingerprintSource(source);
    } finally {
      source.close();
    }
  });

  Future<void> _relocate(
    Book match,
    LibraryFolder folder,
    FolderEntry entry,
    String hash,
  ) async {
    await _db.updateBook(
      match.id,
      _location(
        folder,
        entry,
        hash,
      ).copyWith(series: _seriesValue(_missingSeries(match, entry))),
    );
    if (match.folderId == null) await _discardLegacyCopy(match.filePath);
  }

  Future<String> _addNew(
    LibraryFolder folder,
    FolderEntry entry,
    SourceSpec spec,
    String hash,
  ) async {
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
    final title = meta.title?.trim() ?? '';
    await _db.upsertBook(
      _location(folder, entry, hash).copyWith(
        id: Value(id),
        title: Value(
          title.isNotEmpty
              ? title
              : p.posix.basenameWithoutExtension(entry.relativePath),
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
    return id;
  }

  Value<String?> _seriesValue(String? series) =>
      series == null ? const Value.absent() : Value(series);

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

typedef _Work = (LibraryFolder, FolderEntry, Book?);
typedef _Plan = ({List<_Work> work, List<LibraryFolder> reachable});

class _Tally {
  int added = 0;
  int relocated = 0;
  int missing = 0;
  int failed = 0;
  final List<String> unreachable = [];

  void record(_Outcome outcome) {
    switch (outcome) {
      case _Outcome.added:
        added++;
      case _Outcome.relocated:
        relocated++;
      case _Outcome.unchanged:
        break;
    }
  }

  ScanReport report() => ScanReport(
    added: added,
    relocated: relocated,
    missing: missing,
    failed: failed,
    unreachable: unreachable,
  );
}
