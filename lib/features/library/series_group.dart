// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/text_search.dart';
import '../../data/comic/comic_book.dart';
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import 'book_search.dart';

sealed class LibraryEntry {
  const LibraryEntry();
}

class BookEntry extends LibraryEntry {
  const BookEntry(this.book);

  final Book book;
}

class SeriesEntry extends LibraryEntry {
  const SeriesEntry({
    required this.key,
    required this.name,
    required this.volumes,
  });

  final String key;
  final String name;
  final List<Book> volumes;

  Book get first => volumes.first;
}

String? seriesKeyOf(Book book) {
  final series = book.series;
  if (book.format != BookFormat.comic || series == null) return null;
  final key = foldForSearch(series);
  return key.isEmpty ? null : key;
}

int compareVolumes(Book a, Book b) =>
    compareNatural(a.relativePath ?? a.title, b.relativePath ?? b.title);

List<Book> volumesOf(List<Book> books, String key) => [
  for (final b in books)
    if (seriesKeyOf(b) == key) b,
]..sort(compareVolumes);

List<LibraryEntry> groupSeries(List<Book> books) {
  final members = <String, List<Book>>{};
  for (final book in books) {
    final key = seriesKeyOf(book);
    if (key != null) members.putIfAbsent(key, () => []).add(book);
  }

  final placed = <String>{};
  final entries = <LibraryEntry>[];
  for (final book in books) {
    final key = seriesKeyOf(book);
    final group = key == null ? null : members[key]!;
    if (group == null || group.length < 2) {
      entries.add(BookEntry(book));
      continue;
    }
    if (!placed.add(key!)) continue;
    final volumes = [...group]..sort(compareVolumes);
    entries.add(
      SeriesEntry(key: key, name: _commonName(volumes), volumes: volumes),
    );
  }
  return entries;
}

List<Book> booksOf(List<LibraryEntry> entries) => [
  for (final entry in entries)
    ...switch (entry) {
      BookEntry(:final book) => [book],
      SeriesEntry(:final volumes) => volumes,
    },
];

List<LibraryEntry> searchEntries(List<Book> books, String foldedQuery) {
  final series = [
    for (final entry in groupSeries(books))
      if (entry is SeriesEntry && matchesQuery(entry.name, foldedQuery)) entry,
  ];
  final grouped = {
    for (final s in series)
      for (final b in s.volumes) b.id,
  };
  return [
    ...series,
    for (final book in books)
      if (!grouped.contains(book.id) && bookMatches(book, foldedQuery))
        BookEntry(book),
  ];
}

String _commonName(List<Book> volumes) {
  final counts = <String, int>{};
  for (final b in volumes) {
    counts[b.series!] = (counts[b.series!] ?? 0) + 1;
  }
  var best = volumes.first.series!;
  for (final entry in counts.entries) {
    if (entry.value > counts[best]!) best = entry.key;
  }
  return best;
}
