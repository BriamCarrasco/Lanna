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
const _maxNoteLength = 10000;

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
    this.collections = 0,
  });

  final int applied;
  final int upToDate;
  final int unmatched;
  final int invalid;
  final int collections;

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
    this.series,
    this.hidden,
    this.favoritedAt,
    this.bookmarks = const [],
    this.highlights = const [],
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
  final String? series;
  final bool? hidden;
  final DateTime? favoritedAt;
  final List<ProgressBookmark> bookmarks;
  final List<ProgressHighlight> highlights;

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
    'series': ?series,
    'hidden': ?hidden,
    if (favoritedAt case final at?) 'favoritedAt': at.toUtc().toIso8601String(),
    if (bookmarks.isNotEmpty)
      'bookmarks': [for (final b in bookmarks) b.toJson()],
    if (highlights.isNotEmpty)
      'highlights': [for (final h in highlights) h.toJson()],
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
    final series = _text(json['series'], 512);
    final hidden = switch (json['hidden']) {
      final bool value => value,
      _ => null,
    };
    final favoritedAt = _date(json['favoritedAt']);
    final bookmarks = switch (json['bookmarks']) {
      final List<Object?> list => [
        for (final raw in list) ?ProgressBookmark.fromJson(raw, format),
      ],
      _ => const <ProgressBookmark>[],
    };
    final highlights = switch (json['highlights']) {
      final List<Object?> list => [
        for (final raw in list) ?ProgressHighlight.fromJson(raw, format),
      ],
      _ => const <ProgressHighlight>[],
    };
    if (updatedAt == null &&
        finishedAt == null &&
        sessions.isEmpty &&
        series == null &&
        hidden == null &&
        favoritedAt == null &&
        bookmarks.isEmpty &&
        highlights.isEmpty) {
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
      series: series,
      hidden: hidden,
      favoritedAt: favoritedAt,
      bookmarks: bookmarks,
      highlights: highlights,
    );
  }
}

class ProgressBookmark {
  const ProgressBookmark({
    required this.id,
    required this.cfi,
    this.chapterIndex,
    this.percent = 0,
    this.label,
    this.createdAt,
  });

  final String id;
  final String cfi;
  final int? chapterIndex;
  final double percent;
  final String? label;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'cfi': cfi,
    'chapterIndex': ?chapterIndex,
    'percent': percent,
    'label': ?label,
    if (createdAt case final at?) 'createdAt': at.toUtc().toIso8601String(),
  };

  static ProgressBookmark? fromJson(Object? json, BookFormat? format) {
    if (json is! Map) return null;
    final id = _id(json['id']);
    final cfi = _locator(json['cfi'], format);
    if (id == null || cfi == null) return null;
    return ProgressBookmark(
      id: id,
      cfi: cfi,
      chapterIndex: _index(json['chapterIndex']),
      percent: _percent(json['percent']),
      label: _text(json['label'], 512),
      createdAt: _date(json['createdAt']),
    );
  }
}

class ProgressHighlight {
  const ProgressHighlight({
    required this.id,
    required this.cfi,
    this.content = '',
    this.color = 'yellow',
    this.note,
    this.chapterIndex,
    this.percent = 0,
    this.createdAt,
  });

  final String id;
  final String cfi;
  final String content;
  final String color;
  final String? note;
  final int? chapterIndex;
  final double percent;
  final DateTime? createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'cfi': cfi,
    'content': content,
    'color': color,
    'note': ?note,
    'chapterIndex': ?chapterIndex,
    'percent': percent,
    if (createdAt case final at?) 'createdAt': at.toUtc().toIso8601String(),
  };

  static ProgressHighlight? fromJson(Object? json, BookFormat? format) {
    if (json is! Map) return null;
    final id = _id(json['id']);
    final cfi = _locator(json['cfi'], format);
    if (id == null || cfi == null) return null;
    final color = json['color'];
    return ProgressHighlight(
      id: id,
      cfi: cfi,
      content: _text(json['content'], _maxNoteLength) ?? '',
      color: color is String && _colorPattern.hasMatch(color)
          ? color
          : 'yellow',
      note: _text(json['note'], _maxNoteLength),
      chapterIndex: _index(json['chapterIndex']),
      percent: _percent(json['percent']),
      createdAt: _date(json['createdAt']),
    );
  }
}

class CollectionMember {
  const CollectionMember({
    this.hash,
    this.title,
    this.author,
    this.format,
    this.addedAt,
  });

  final String? hash;
  final String? title;
  final String? author;
  final BookFormat? format;
  final DateTime? addedAt;

  Map<String, Object?> toJson() => {
    'hash': ?hash,
    'title': ?title,
    'author': ?author,
    'format': ?format?.name,
    if (addedAt case final at?) 'addedAt': at.toUtc().toIso8601String(),
  };

  static CollectionMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final hash = _hash(json['hash']);
    final title = _text(json['title'], 512);
    if (hash == null && title == null) return null;
    return CollectionMember(
      hash: hash,
      title: title,
      author: _text(json['author'], 512),
      format: _format(json['format']),
      addedAt: _date(json['addedAt']),
    );
  }
}

class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.name,
    this.createdAt,
    this.members = const [],
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final List<CollectionMember> members;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (createdAt case final at?) 'createdAt': at.toUtc().toIso8601String(),
    'books': [for (final m in members) m.toJson()],
  };

  static CollectionEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = _text(json['name'], 120);
    if (id is! String || !_idPattern.hasMatch(id) || name == null) {
      return null;
    }
    return CollectionEntry(
      id: id,
      name: name,
      createdAt: _date(json['createdAt']),
      members: switch (json['books']) {
        final List<Object?> list => [
          for (final raw in list) ?CollectionMember.fromJson(raw),
        ],
        _ => const [],
      },
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
    final bookmarks = <String, List<ProgressBookmark>>{};
    for (final b in await _db.select(_db.bookmarks).get()) {
      bookmarks
          .putIfAbsent(b.bookId, () => [])
          .add(
            ProgressBookmark(
              id: b.id,
              cfi: b.cfi,
              chapterIndex: b.chapterIndex,
              percent: b.percent,
              label: b.label,
              createdAt: b.createdAt,
            ),
          );
    }
    final highlights = <String, List<ProgressHighlight>>{};
    for (final h in await _db.select(_db.highlights).get()) {
      highlights
          .putIfAbsent(h.bookId, () => [])
          .add(
            ProgressHighlight(
              id: h.id,
              cfi: h.cfi,
              content: h.content,
              color: h.color,
              note: h.note,
              chapterIndex: h.chapterIndex,
              percent: h.percent,
              createdAt: h.createdAt,
            ),
          );
    }
    final entries = [
      for (final book in books)
        if (progress[book.id] != null ||
            book.finishedAt != null ||
            sessions[book.id] != null ||
            book.series != null ||
            book.hidden ||
            book.favoritedAt != null ||
            bookmarks[book.id] != null ||
            highlights[book.id] != null)
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
            series: book.series,
            hidden: book.hidden,
            favoritedAt: book.favoritedAt,
            bookmarks: bookmarks[book.id] ?? const [],
            highlights: highlights[book.id] ?? const [],
          ),
    ];
    final byId = {for (final book in books) book.id: book};
    final members = <String, List<CollectionMember>>{};
    for (final e in await _db.select(_db.collectionEntries).get()) {
      final book = byId[e.bookId];
      if (book == null) continue;
      members
          .putIfAbsent(e.collectionId, () => [])
          .add(
            CollectionMember(
              hash: book.contentHash,
              title: book.title,
              author: book.author,
              format: book.format,
              addedAt: e.addedAt,
            ),
          );
    }
    final collections = [
      for (final c in await _db.select(_db.collections).get())
        CollectionEntry(
          id: c.id,
          name: c.name,
          createdAt: c.createdAt,
          members: members[c.id] ?? const [],
        ),
    ];
    final document = {
      'kind': progressFileKind,
      'version': progressFileVersion,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'books': [for (final e in entries) e.toJson()],
      'collections': [for (final c in collections) c.toJson()],
    };
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
  }

  Future<ProgressImportReport> import(Uint8List bytes) async {
    final (books: rawEntries, collections: rawCollections) = decodeProgressFile(
      bytes,
    );
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
    final bookmarkIds = <String>{};
    final bookmarkSpots = <String>{};
    for (final b in await _db.select(_db.bookmarks).get()) {
      bookmarkIds.add(b.id);
      bookmarkSpots.add('${b.bookId}\u0000${b.cfi}');
    }
    final highlightIds = <String>{};
    final highlightSpots = <String>{};
    for (final h in await _db.select(_db.highlights).get()) {
      highlightIds.add(h.id);
      highlightSpots.add('${h.bookId}\u0000${h.cfi}');
    }
    final now = _clock();
    DateTime? notAfterNow(DateTime? at) =>
        at != null && at.isAfter(now) ? now : at;
    Book? match(
      String? hash,
      String? title,
      String? author,
      BookFormat? format,
    ) =>
        (hash == null ? null : byHash[hash]) ??
        _uniqueByTitle(byTitle, title, author, format);

    var applied = 0;
    var upToDate = 0;
    var unmatched = 0;
    var invalid = 0;
    var collectionsChanged = 0;
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
        final book =
            exact ??
            _uniqueByTitle(byTitle, entry.title, entry.author, entry.format);
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
        final series = exact != null && entry.series != null
            ? entry.series
            : book.series;
        final hidden = exact != null && entry.hidden != null
            ? entry.hidden!
            : book.hidden;
        final favoritedAt = book.favoritedAt ?? notAfterNow(entry.favoritedAt);
        if (series != book.series ||
            hidden != book.hidden ||
            favoritedAt != book.favoritedAt) {
          await _db.updateBook(
            book.id,
            BooksCompanion(
              series: Value(series),
              hidden: Value(hidden),
              favoritedAt: Value(favoritedAt),
            ),
          );
          changed = true;
        }
        if (exact != null) {
          for (final mark in entry.bookmarks) {
            final spot = '${book.id}\u0000${mark.cfi}';
            if (bookmarkIds.contains(mark.id) || !bookmarkSpots.add(spot)) {
              continue;
            }
            bookmarkIds.add(mark.id);
            await _db.addBookmark(
              BookmarksCompanion.insert(
                id: mark.id,
                bookId: book.id,
                cfi: mark.cfi,
                chapterIndex: Value(mark.chapterIndex),
                percent: Value(mark.percent),
                label: Value(mark.label),
                createdAt: Value(notAfterNow(mark.createdAt) ?? now),
              ),
            );
            changed = true;
          }
          for (final mark in entry.highlights) {
            final spot = '${book.id}\u0000${mark.cfi}';
            if (highlightIds.contains(mark.id) || !highlightSpots.add(spot)) {
              continue;
            }
            highlightIds.add(mark.id);
            await _db.addHighlight(
              HighlightsCompanion.insert(
                id: mark.id,
                bookId: book.id,
                cfi: mark.cfi,
                content: Value(mark.content),
                color: Value(mark.color),
                note: Value(mark.note),
                chapterIndex: Value(mark.chapterIndex),
                percent: Value(mark.percent),
                createdAt: Value(notAfterNow(mark.createdAt) ?? now),
              ),
            );
            changed = true;
          }
        }
        changed ? applied++ : upToDate++;
      }

      final localCollections = await _db.select(_db.collections).get();
      final collectionIds = {for (final c in localCollections) c.id};
      final collectionByName = <String, String>{};
      for (final c in localCollections) {
        collectionByName.putIfAbsent(foldForSearch(c.name), () => c.id);
      }
      final memberships = {
        for (final e in await _db.select(_db.collectionEntries).get())
          '${e.collectionId}\u0000${e.bookId}',
      };
      for (final raw in rawCollections) {
        final CollectionEntry? collection;
        try {
          collection = CollectionEntry.fromJson(raw);
        } catch (_) {
          continue;
        }
        if (collection == null) continue;
        var changed = false;
        final nameKey = foldForSearch(collection.name);
        var id = collectionIds.contains(collection.id)
            ? collection.id
            : collectionByName[nameKey];
        if (id == null) {
          id = collection.id;
          await _db
              .into(_db.collections)
              .insert(
                CollectionsCompanion.insert(
                  id: id,
                  name: collection.name,
                  createdAt: Value(notAfterNow(collection.createdAt) ?? now),
                ),
              );
          collectionIds.add(id);
          collectionByName[nameKey] = id;
          changed = true;
        }
        for (final member in collection.members) {
          final book = match(
            member.hash,
            member.title,
            member.author,
            member.format,
          );
          if (book == null) continue;
          if (!memberships.add('$id\u0000${book.id}')) continue;
          await _db
              .into(_db.collectionEntries)
              .insert(
                CollectionEntriesCompanion.insert(
                  collectionId: id,
                  bookId: book.id,
                  addedAt: Value(notAfterNow(member.addedAt) ?? now),
                ),
              );
          changed = true;
        }
        if (changed) collectionsChanged++;
      }
    });
    return ProgressImportReport(
      applied: applied,
      upToDate: upToDate,
      unmatched: unmatched,
      invalid: invalid,
      collections: collectionsChanged,
    );
  }

  Book? _uniqueByTitle(
    Map<String, List<Book>> byTitle,
    String? title,
    String? author,
    BookFormat? format,
  ) {
    if (title == null || format == null) return null;
    final candidates = byTitle[_titleKey(title, author, format)];
    return candidates != null && candidates.length == 1
        ? candidates.single
        : null;
  }
}

({List<Object?> books, List<Object?> collections}) decodeProgressFile(
  Uint8List bytes,
) {
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
  return (
    books: books,
    collections: switch (document['collections']) {
      final List<Object?> list => list,
      _ => const [],
    },
  );
}

String _titleKey(String title, String? author, BookFormat format) =>
    '${format.name}\u0000${foldForSearch(title)}\u0000'
    '${foldForSearch(author ?? '')}';

final _hashPattern = RegExp(r'^[0-9a-f]{64}$');
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _colorPattern = RegExp(r'^[a-z]{1,20}$');

String? _id(Object? value) =>
    value is String && _idPattern.hasMatch(value) ? value : null;

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
