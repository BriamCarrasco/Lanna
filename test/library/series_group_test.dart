// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/series_group.dart';

Book _book(
  String id, {
  String? series,
  BookFormat format = BookFormat.comic,
  String? path,
}) => Book(
  id: id,
  title: id,
  filePath: '/Libros/${path ?? id}',
  relativePath: path ?? id,
  format: format,
  series: series,
  available: true,
  hidden: false,
  addedAt: DateTime(2026),
);

void main() {
  test('dos o más tomos de la misma serie forman una sola entrada', () {
    final entries = groupSeries([
      _book('n10', series: 'Naruto', path: 'Naruto Vol. 10.cbz'),
      _book('rayuela', format: BookFormat.epub),
      _book('n2', series: 'naruto', path: 'Naruto Vol. 2.cbz'),
      _book('n1', series: 'Naruto', path: 'Naruto Vol. 1.cbz'),
      _book('akira', series: 'Akira'),
    ]);

    expect(entries, hasLength(3));
    final series = entries.first as SeriesEntry;
    expect(series.name, 'Naruto');
    expect(series.volumes.map((b) => b.id), ['n1', 'n2', 'n10']);
    expect((entries[1] as BookEntry).book.id, 'rayuela');
    expect((entries[2] as BookEntry).book.id, 'akira');
  });

  test('una novela con serie no se agrupa', () {
    final entries = groupSeries([
      _book('hp1', series: 'Harry Potter', format: BookFormat.epub),
      _book('hp2', series: 'Harry Potter', format: BookFormat.epub),
    ]);

    expect(entries.whereType<BookEntry>(), hasLength(2));
  });

  test('la serie ignora acentos y mayúsculas al agrupar', () {
    final entries = groupSeries([
      _book('a', series: 'Pokémon Adventures'),
      _book('b', series: 'pokemon adventures'),
    ]);

    expect(entries.single, isA<SeriesEntry>());
  });
}
