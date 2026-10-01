// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/folders_screen.dart';

Book _book(String relative) => Book(
  id: relative,
  title: relative.split('/').last,
  filePath: '/Libros/$relative',
  format: BookFormat.comic,
  relativePath: relative,
  folderId: 'libros',
  available: true,
  hidden: false,
  addedAt: DateTime(2026),
);

void main() {
  final books = [
    _book('1984.epub'),
    _book('Manga/Boku dake/Tomo 10.cbr'),
    _book('Manga/Boku dake/Tomo 2.cbr'),
    _book('Manga/Boku dake/Tomo 1.cbr'),
    _book('Manga/Akira/Tomo 1.cbz'),
    _book('Clásicos/Dorian Gray.epub'),
  ];

  test('en la raíz muestra subcarpetas con su total y los libros sueltos', () {
    final level = browseFolder(books, const []);

    expect(level.folders, [
      (name: 'Clásicos', count: 1),
      (name: 'Manga', count: 4),
    ]);
    expect(level.books.map((b) => b.relativePath), ['1984.epub']);
  });

  test('dentro de una subcarpeta ordena los tomos de forma natural', () {
    final level = browseFolder(books, const ['Manga', 'Boku dake']);

    expect(level.folders, isEmpty);
    expect(level.books.map((b) => b.title), [
      'Tomo 1.cbr',
      'Tomo 2.cbr',
      'Tomo 10.cbr',
    ]);
  });

  test('un nivel intermedio solo muestra sus subcarpetas', () {
    final level = browseFolder(books, const ['Manga']);

    expect(level.folders, [
      (name: 'Akira', count: 1),
      (name: 'Boku dake', count: 3),
    ]);
    expect(level.books, isEmpty);
  });

  test('buscar dentro de una carpeta abarca todo su árbol', () {
    expect(booksUnder(books, const ['Manga']), hasLength(4));
    expect(booksUnder(books, const []), hasLength(6));
  });
}
