// SPDX-License-Identifier: GPL-3.0-or-later
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';

const finishedThreshold = 0.99;

enum FormatFilter {
  all('Todos'),
  epub('EPUB'),
  pdf('PDF'),
  comic('Cómics');

  const FormatFilter(this.label);
  final String label;
}

enum ReadFilter {
  all('Todos'),
  unread('Sin empezar'),
  reading('Leyendo'),
  finished('Terminados');

  const ReadFilter(this.label);
  final String label;
}

class LibraryFilters {
  const LibraryFilters({
    this.format = FormatFilter.all,
    this.read = ReadFilter.all,
  });

  final FormatFilter format;
  final ReadFilter read;

  bool get active => format != FormatFilter.all || read != ReadFilter.all;

  LibraryFilters copyWith({FormatFilter? format, ReadFilter? read}) =>
      LibraryFilters(format: format ?? this.format, read: read ?? this.read);

  bool matches(Book book, double? progress) {
    final formatOk = switch (format) {
      FormatFilter.all => true,
      FormatFilter.epub => book.format == BookFormat.epub,
      FormatFilter.pdf => book.format == BookFormat.pdf,
      FormatFilter.comic => book.format == BookFormat.comic,
    };
    if (!formatOk) return false;
    final value = progress ?? 0;
    return switch (read) {
      ReadFilter.all => true,
      ReadFilter.unread => value <= 0,
      ReadFilter.reading => value > 0 && value < finishedThreshold,
      ReadFilter.finished => value >= finishedThreshold,
    };
  }
}
