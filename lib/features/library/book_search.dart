// SPDX-License-Identifier: GPL-3.0-or-later
import '../../core/text_search.dart';
import '../../data/local/app_database.dart';

bool bookMatches(Book book, String foldedQuery) => matchesQuery(
  '${book.title} ${book.author ?? ''} ${book.relativePath ?? ''}',
  foldedQuery,
);
