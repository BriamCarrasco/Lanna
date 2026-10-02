// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/library_filters.dart';

Book _book(String id, BookFormat format) => Book(
  id: id,
  title: id,
  filePath: '/$id',
  format: format,
  available: true,
  hidden: false,
  addedAt: DateTime(2026),
);

void main() {
  final epub = _book('e', BookFormat.epub);
  final pdf = _book('p', BookFormat.pdf);
  final comic = _book('c', BookFormat.comic);

  test('sin filtros pasa todo', () {
    const filters = LibraryFilters();
    expect(filters.active, isFalse);
    for (final b in [epub, pdf, comic]) {
      expect(filters.matches(b, null), isTrue);
    }
  });

  test('el formato deja pasar solo el elegido', () {
    const filters = LibraryFilters(format: FormatFilter.comic);
    expect(filters.active, isTrue);
    expect(filters.matches(comic, null), isTrue);
    expect(filters.matches(epub, null), isFalse);
    expect(filters.matches(pdf, null), isFalse);
  });

  test('el estado usa los mismos umbrales que el resto de la app', () {
    bool read(ReadFilter f, double? p) =>
        LibraryFilters(read: f).matches(epub, p);

    expect(read(ReadFilter.unread, null), isTrue);
    expect(read(ReadFilter.unread, 0), isTrue);
    expect(read(ReadFilter.unread, 0.01), isFalse);
    expect(read(ReadFilter.reading, 0.5), isTrue);
    expect(read(ReadFilter.reading, 0.99), isFalse);
    expect(read(ReadFilter.finished, 0.99), isTrue);
    expect(read(ReadFilter.finished, 1), isTrue);
    expect(read(ReadFilter.finished, 0.5), isFalse);
  });

  test('formato y estado se combinan', () {
    const filters = LibraryFilters(
      format: FormatFilter.comic,
      read: ReadFilter.reading,
    );
    expect(filters.matches(comic, 0.3), isTrue);
    expect(filters.matches(comic, 0), isFalse);
    expect(filters.matches(epub, 0.3), isFalse);
  });
}
