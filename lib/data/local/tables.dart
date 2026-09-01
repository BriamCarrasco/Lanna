// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart';

import '../models/book_format.dart';

class Books extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 512)();

  TextColumn get author => text().nullable()();

  TextColumn get filePath => text()();

  TextColumn get format => textEnum<BookFormat>()();

  TextColumn get coverPath => text().nullable()();

  IntColumn get fileSizeBytes => integer().nullable()();

  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReadingProgress extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  TextColumn get locator => text().nullable()();

  RealColumn get percent => real().withDefault(const Constant(0))();

  IntColumn get chapterIndex => integer().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class BookLocations extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  TextColumn get data => text()();

  DateTimeColumn get generatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

class ReaderPrefs extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  TextColumn get theme => text().withDefault(const Constant('dark'))();

  IntColumn get fontScale => integer().withDefault(const Constant(110))();

  TextColumn get fontFamily => text().withDefault(const Constant('serif'))();

  RealColumn get lineHeight => real().withDefault(const Constant(1.6))();

  TextColumn get columns => text().withDefault(const Constant('auto'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
