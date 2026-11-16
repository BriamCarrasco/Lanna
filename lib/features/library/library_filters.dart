// SPDX-License-Identifier: GPL-3.0-or-later
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import '../../l10n/l10n.dart';

const finishedThreshold = 0.99;

enum FormatFilter {
  all,
  epub,
  pdf,
  comic;

  String label(AppLocalizations l10n) => switch (this) {
    all => l10n.filterAll,
    epub => 'EPUB',
    pdf => 'PDF',
    comic => l10n.filterComics,
  };
}

enum ReadFilter {
  all,
  unread,
  reading,
  finished;

  String label(AppLocalizations l10n) => switch (this) {
    all => l10n.filterAll,
    unread => l10n.filterUnread,
    reading => l10n.filterReading,
    finished => l10n.filterFinished,
  };
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
