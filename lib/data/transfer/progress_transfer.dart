// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/text_search.dart';
import '../local/app_database.dart';
import '../models/book_format.dart';

const progressFileKind = 'lanna-progress';
const progressFileVersion = 2;
const maxProgressFileBytes = 32 * 1024 * 1024;
const _maxSessionSeconds = 24 * 60 * 60;
const _maxSessionPages = 100000;

enum ProgressFileError { tooLarge, invalid, notLanna, noBooks }

class ProgressFileException implements Exception {
  const ProgressFileException(this.kind);

  final ProgressFileError kind;

  @override
  String toString() => kind.name;
}

class ProgressImportReport {
  const ProgressImportReport({
    this.applied = 0,
    this.upToDate = 0,
    this.unmatched = 0,
    this.invalid = 0,
  });

  final int applied;
  final int upToDate;
  final int unmatched;
  final int invalid;

  int get total => applied + upToDate + unmatched + invalid;
}

class ProgressSession {
  const ProgressSession({
    required this.startedAt,
    required this.seconds,
    this.startPercent = 0,
    this.endPercent = 0,
    this.pages = 0,
  });

  final DateTime startedAt;
  final int seconds;
  final double startPercent;
  final double endPercent;
  final int pages;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'seconds': seconds,
    'startPercent': startPercent,
    'endPercent': endPercent,
    'pages': pages,
  };

  static ProgressSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final startedAt = _date(json['startedAt']);
    final seconds = json['seconds'];
    if (startedAt == null ||
        seconds is! int ||
        seconds <= 0 ||
        seconds > _maxSessionSeconds) {
      return null;
    }
    final pages = json['pages'];
    return ProgressSession(
      startedAt: startedAt,
      seconds: seconds,
      startPercent: _percent(json['startPercent']),
      endPercent: _percent(json['endPercent']),
      pages: pages is int && pages >= 0 && pages <= _maxSessionPages
          ? pages
          : 0,
    );
  }
}

class ProgressEntry {
  const ProgressEntry({
    this.hash,
    this.title,
    this.author,
    this.format,
    this.locator,
    this.percent = 0,
    this.chapterIndex,
    this.updatedAt,
    this.finishedAt,
    this.sessions = const [],
  });

  final String? hash;
  final String? title;
  final String? author;
  final BookFormat? format;
  final String? locator;
  final double percent;
  final int? chapterIndex;
  final DateTime? updatedAt;
  final DateTime? finishedAt;
  final List<ProgressSession> sessions;

  bool get hasProgress => updatedAt != null;

  Map<String, Object?> toJson() => {
    'hash': ?hash,
    'title': ?title,
    'author': ?author,
    'format': ?format?.name,
    if (updatedAt case final at?)
      'progress': {
        'locator': ?locator,
        'percent': percent,
        'chapterIndex': ?chapterIndex,
        'updatedAt': at.toUtc().toIso8601String(),
      },
    if (finishedAt case final at?) 'finishedAt': at.toUtc().toIso8601String(),
    if (sessions.isNotEmpty) 'sessions': [for (final s in sessions) s.toJson()],
  };

  static ProgressEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final hash = _hash(json['hash']);
    final title = _text(json['title'], 512);
    if (hash == null && title == null) return null;
    final format = _format(json['format']);
    final progress = switch (json['progress']) {
      final Map<Object?, Object?> map => map,
      _ => null,
    };
    final finishedAt = _date(json['finishedAt']);
    final updatedAt = _date(progress?['updatedAt']);
    final sessions = switch (json['sessions']) {
      final List<Object?> list => [
        for (final raw in list) ?ProgressSession.fromJson(raw),
      ],
      _ => const <ProgressSession>[],
    };
    if (updatedAt == null && finishedAt == null && sessions.isEmpty) {
      return null;
    }
    return ProgressEntry(
      hash: hash,
      title: title,
      author: _text(json['author'], 512),
      format: format,
      locator: updatedAt == null
          ? null
          : _locator(progress?['locator'], format),
      percent: updatedAt == null ? 0 : _percent(progress?['percent']),
      chapterIndex: updatedAt == null
          ? null
          : _index(progress?['chapterIndex']),
      updatedAt: updatedAt,
      finishedAt: finishedAt,
      sessions: sessions,
    );
  }
}

class ProgressTransfer {
  ProgressTransfer(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<Uint8List> export() async {
    final books = await _db.select(_db.books).get();
    final progress = {
      for (final p in await _db.select(_db.readingProgress).get()) p.bookId: p,
    };
    final sessions = <String, List<ProgressSession>>{};
    for (final s in await _db.select(_db.readingSessions).get()) {
      sessions
          .putIfAbsent(s.bookId, () => [])
          .add(
            ProgressSession(
              startedAt: s.startedAt,
              seconds: s.seconds,
              startPercent: s.startPercent,
              endPercent: s.endPercent,
              pages: s.pages,
            ),
          );
    }
    final entries = [
      for (final book in books)
        if (progress[book.id] != null ||
            book.finishedAt != null ||
            sessions[book.id] != null)
          ProgressEntry(
            hash: book.contentHash,
            title: book.title,
            author: book.author,
            format: book.format,
            locator: progress[book.id]?.locator,
            percent: progress[book.id]?.percent ?? 0,
            chapterIndex: progress[book.id]?.chapterIndex,
            updatedAt: progress[book.id]?.updatedAt,
            finishedAt: book.finishedAt,
            sessions: sessions[book.id] ?? const [],
          ),
    ];
    final document = {
      'kind': progressFileKind,
      'version': progressFileVersion,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'books': [for (final e in entries) e.toJson()],
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
  }

  Future<ProgressImportReport> import(Uint8List bytes) async {
    final rawEntries = decodeProgressFile(bytes);
    final books = await _db.select(_db.books).get();
    final byHash = <String, Book>{};
    final byTitle = <String, List<Book>>{};
    for (final book in books) {
      if (book.contentHash case final hash?) {
        byHash.putIfAbsent(hash, () => book);
      }
      final key = _titleKey(book.title, book.author, book.format);
      byTitle.putIfAbsent(key, () => []).add(book);
    }
    final progress = {
      for (final p in await _db.select(_db.readingProgress).get()) p.bookId: p,
    };
    final finished = {for (final b in books) b.id: b.finishedAt};
    final sessionStarts = <String, Set<int>>{};
    for (final s in await _db.select(_db.readingSessions).get()) {
      sessionStarts
          .putIfAbsent(s.bookId, () => {})
          .add(s.startedAt.millisecondsSinceEpoch ~/ 1000);
    }
    final now = _clock();
    DateTime? notAfterNow(DateTime? at) =>
        at != null && at.isAfter(now) ? now : at;

    var applied = 0;
    var upToDate = 0;
    var unmatched = 0;
    var invalid = 0;
    await _db.transaction(() async {
      for (final raw in rawEntries) {
        final ProgressEntry? entry;
        try {
          entry = ProgressEntry.fromJson(raw);
        } catch (_) {
          invalid++;
          continue;
        }
        if (entry == null) {
          invalid++;
          continue;
        }
        final exact = entry.hash == null ? null : byHash[entry.hash];
        final book = exact ?? _uniqueByTitle(byTitle, entry);
        if (book == null) {
          unmatched++;
          continue;
        }
        var changed = false;
        final local = progress[book.id];
        if (notAfterNow(entry.updatedAt) case final at?
            when local == null || at.isAfter(local.updatedAt)) {
          final row = ReadingProgressCompanion(
            bookId: Value(book.id),
            locator: Value(exact != null ? entry.locator : null),
            percent: Value(entry.percent),
            chapterIndex: Value(exact != null ? entry.chapterIndex : null),
            updatedAt: Value(at),
          );
          await _db.into(_db.readingProgress).insertOnConflictUpdate(row);
          progress[book.id] = ReadingProgressData(
            bookId: book.id,
            locator: row.locator.value,
            percent: entry.percent,
            chapterIndex: row.chapterIndex.value,
            updatedAt: at,
          );
          changed = true;
        }
        if (notAfterNow(entry.finishedAt) case final at?
            when finished[book.id] == null) {
          await _db.updateBook(book.id, BooksCompanion(finishedAt: Value(at)));
          finished[book.id] = at;
          changed = true;
        }
        final starts = sessionStarts.putIfAbsent(book.id, () => {});
        for (final session in entry.sessions) {
          if (session.startedAt.isAfter(now)) continue;
          if (!starts.add(session.startedAt.millisecondsSinceEpoch ~/ 1000)) {
            continue;
          }
          await _db.addReadingSession(
            ReadingSessionsCompanion.insert(
              bookId: book.id,
              startedAt: session.startedAt,
              seconds: session.seconds,
              startPercent: Value(session.startPercent),
              endPercent: Value(session.endPercent),
              pages: Value(session.pages),
            ),
          );
          changed = true;
        }
        changed ? applied++ : upToDate++;
      }
    });
    return ProgressImportReport(
      applied: applied,
      upToDate: upToDate,
      unmatched: unmatched,
      invalid: invalid,
    );
  }

  Book? _uniqueByTitle(Map<String, List<Book>> byTitle, ProgressEntry entry) {
    final title = entry.title;
    final format = entry.format;
    if (title == null || format == null) return null;
    final candidates = byTitle[_titleKey(title, entry.author, format)];
    return candidates != null && candidates.length == 1
        ? candidates.single
        : null;
  }
}

List<Object?> decodeProgressFile(Uint8List bytes) {
  if (bytes.length > maxProgressFileBytes) {
    throw const ProgressFileException(ProgressFileError.tooLarge);
  }
  final Object? document;
  try {
    document = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ProgressFileException(ProgressFileError.invalid);
  }
  if (document is! Map || document['kind'] != progressFileKind) {
    throw const ProgressFileException(ProgressFileError.notLanna);
  }
  final books = document['books'];
  if (books is! List) {
    throw const ProgressFileException(ProgressFileError.noBooks);
  }
  return books;
}

String _titleKey(String title, String? author, BookFormat format) =>
    '${format.name}\u0000${foldForSearch(title)}\u0000'
    '${foldForSearch(author ?? '')}';

final _hashPattern = RegExp(r'^[0-9a-f]{64}$');

String? _hash(Object? value) =>
    value is String && _hashPattern.hasMatch(value) ? value : null;

String? _text(Object? value, int max) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text.length > max ? null : text;
}

BookFormat? _format(Object? value) {
  for (final format in BookFormat.values) {
    if (format.name == value) return format;
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  final date = DateTime.tryParse(value);
  if (date == null || date.year < 2000 || date.year > 9999) return null;
  return date;
}

double _percent(Object? value) {
  if (value is! num || !value.isFinite) return 0;
  return value.toDouble().clamp(0.0, 1.0);
}

int? _index(Object? value) => value is int && value >= 0 ? value : null;

String? _locator(Object? value, BookFormat? format) {
  final locator = _text(value, 512);
  if (locator == null) return null;
  final valid = switch (format) {
    BookFormat.epub =>
      locator.startsWith('spine:') || locator.startsWith('page:'),
    BookFormat.pdf || BookFormat.comic => locator.startsWith('page:'),
    null => false,
  };
  return valid ? locator : null;
}
