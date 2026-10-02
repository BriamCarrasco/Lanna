// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/native/page_estimate.dart';

void main() {
  test('sin capítulos paginados no hay estimación', () {
    expect(
      estimatePage(
        chapter: 0,
        pageInChapter: 0,
        weights: const [100, 100],
        knownPages: const {},
      ),
      isNull,
    );
  });

  test('con todo paginado los números son exactos', () {
    final e = estimatePage(
      chapter: 2,
      pageInChapter: 3,
      weights: const [100, 300, 200],
      knownPages: const {0: 4, 1: 10, 2: 8},
    )!;
    expect(e.current, 4 + 10 + 4);
    expect(e.total, 22);
  });

  test('los capítulos sin paginar se estiman por su peso', () {
    final e = estimatePage(
      chapter: 1,
      pageInChapter: 0,
      weights: const [1000, 1000, 2000, 500],
      knownPages: const {1: 10},
    )!;
    expect(e.current, 10 + 1);
    expect(e.total, 10 + 10 + 20 + 5);
  });

  test('un capítulo diminuto cuenta al menos una página', () {
    final e = estimatePage(
      chapter: 1,
      pageInChapter: 0,
      weights: const [1, 1000],
      knownPages: const {1: 10},
    )!;
    expect(e.current, 2);
    expect(e.total, 11);
  });

  test('el total nunca queda por debajo de la página actual', () {
    final e = estimatePage(
      chapter: 0,
      pageInChapter: 40,
      weights: const [1000, 100],
      knownPages: const {1: 1},
    )!;
    expect(e.total, greaterThanOrEqualTo(e.current));
  });
}
