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

  TextColumn get contentHash => text().nullable()();

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

class Bookmarks extends Table {
  TextColumn get id => text()();

  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  TextColumn get cfi => text()();

  IntColumn get chapterIndex => integer().nullable()();

  RealColumn get percent => real().withDefault(const Constant(0))();

  TextColumn get label => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Highlights extends Table {
  TextColumn get id => text()();

  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  TextColumn get cfi => text()();

  TextColumn get content => text().withDefault(const Constant(''))();

  TextColumn get color => text().withDefault(const Constant('yellow'))();

  TextColumn get note => text().nullable()();

  IntColumn get chapterIndex => integer().nullable()();

  RealColumn get percent => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Collections extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CollectionEntries extends Table {
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();

  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {collectionId, bookId};
}

class ReaderPrefs extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  TextColumn get theme => text().withDefault(const Constant('dark'))();

  IntColumn get fontScale => integer().withDefault(const Constant(110))();

  TextColumn get fontFamily => text().withDefault(const Constant('serif'))();

  RealColumn get lineHeight => real().withDefault(const Constant(1.6))();

  TextColumn get columns => text().withDefault(const Constant('auto'))();

  TextColumn get pageAnimation => text().withDefault(const Constant('slide'))();

  BoolColumn get edgeTaps => boolean().withDefault(const Constant(true))();

  BoolColumn get keepAwake => boolean().withDefault(const Constant(false))();

  TextColumn get engine => text().withDefault(const Constant('webview'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
