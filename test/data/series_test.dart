// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/library/series.dart';

void main() {
  test('quita la marca de tomo y lo que sigue', () {
    expect(
      seriesFromFileName('Boku dake ga Inai Machi - Tomo 01 (#001-006).cbr'),
      'Boku dake ga Inai Machi',
    );
    expect(
      seriesFromFileName('Boku dake ga Inai Machi Re - Tomo 09 (#001-005).cbr'),
      'Boku dake ga Inai Machi Re',
    );
  });

  test('reconoce las formas habituales de numerar volúmenes', () {
    for (final (name, series) in [
      ('Naruto Vol. 3.cbz', 'Naruto'),
      ('Naruto vol 03.cbz', 'Naruto'),
      ('Naruto v03.cbz', 'Naruto'),
      ('Naruto Volumen 12.cbz', 'Naruto'),
      ('Naruto Volume 1.cbz', 'Naruto'),
      ('One Piece #45.cbr', 'One Piece'),
      ('Berserk T05.cbr', 'Berserk'),
      ('Monster Nº 4.cbr', 'Monster'),
      ('Saga 001.cbz', 'Saga'),
      ('Saga_002.cbz', 'Saga'),
      ('Akira - 02 (2001).cbz', 'Akira'),
      ('[Grupo] Akira Volumen 2 (2001).cbz', 'Akira'),
    ]) {
      expect(seriesFromFileName(name), series, reason: name);
    }
  });

  test('un título sin número queda tal cual', () {
    expect(seriesFromFileName('Watchmen.cbz'), 'Watchmen');
    expect(seriesFromFileName('Maus (edición completa).cbz'), 'Maus');
  });

  test('si el archivo es solo un número, la serie es su carpeta', () {
    expect(seriesFromFileName('Manga/Akira/Tomo 01.cbz'), 'Akira');
    expect(seriesFromFileName('Manga/Akira/01.cbz'), 'Akira');
    expect(seriesFromFileName('Tomo 01.cbz'), isNull);
  });

  test('no confunde una palabra que empieza con v o t', () {
    expect(seriesFromFileName('Vagabond 05.cbr'), 'Vagabond');
    expect(seriesFromFileName('Tokyo Ghoul 3.cbr'), 'Tokyo Ghoul');
  });
}
