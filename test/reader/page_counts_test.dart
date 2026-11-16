// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/native/page_counts.dart';

void main() {
  group('pageNumber', () {
    PageNumber? at(int chapter, int page, Map<int, int> known) => pageNumber(
      chapter: chapter,
      pageInChapter: page,
      chapterCount: 4,
      pagesOf: (c) => known[c],
    );

    test('sin los capítulos anteriores no hay número', () {
      expect(at(2, 0, {0: 5, 2: 3, 3: 1}), isNull);
    });

    test('con los anteriores hay número, aunque falte el total', () {
      final n = at(2, 1, {0: 5, 1: 4})!;
      expect(n.current, 11);
      expect(n.total, isNull);
    });

    test('con todo el libro contado da página y total', () {
      final n = at(1, 3, {0: 5, 1: 4, 2: 3, 3: 1})!;
      expect(n.current, 9);
      expect(n.total, 13);
    });

    test('en el primer capítulo el número no depende de nadie', () {
      expect(at(0, 2, {})!.current, 3);
    });
  });

  group('PageCounts', () {
    test('cuenta primero hacia atrás y después hacia adelante', () {
      final counts = PageCounts(5);
      final order = <int>[];
      for (int? c; (c = counts.nextMissing(2)) != null;) {
        order.add(c!);
        counts.record(c, 3);
      }
      expect(order, [1, 0, 2, 3, 4]);
      expect(counts.isComplete, isTrue);
      expect(counts.toList(), [3, 3, 3, 3, 3]);
    });

    test('un capítulo vacío cuenta como una página', () {
      final counts = PageCounts(1)..record(0, 0);
      expect(counts.of(0), 1);
    });

    test('no restaura cuentas de otro libro', () {
      expect(PageCounts(3).restore([4, 2]), isFalse);
      expect(PageCounts(3).restore([4, 0, 2]), isFalse);
      final counts = PageCounts(3);
      expect(counts.restore([4, 1, 2]), isTrue);
      expect(counts.isComplete, isTrue);
    });
  });

  group('PageCountStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('lanna_pages'));
    tearDown(() => dir.deleteSync(recursive: true));

    PageCountStore store() => PageCountStore(File('${dir.path}/pages.json'));

    test('guarda y recupera por disposición', () async {
      await store().write('a', [3, 4]);
      await store().write('b', [6, 8]);

      expect(await store().read('a'), [3, 4]);
      expect(await store().read('b'), [6, 8]);
      expect(await store().read('c'), isNull);
    });

    test('conserva solo las disposiciones más recientes', () async {
      for (var i = 0; i <= PageCountStore.maxLayouts; i++) {
        await store().write('k$i', [i + 1]);
      }

      expect(await store().read('k0'), isNull);
      expect(await store().read('k1'), [2]);
      expect(await store().read('k${PageCountStore.maxLayouts}'), isNotNull);
    });

    test('un archivo dañado o inexistente no rompe nada', () async {
      expect(await store().read('a'), isNull);
      File('${dir.path}/pages.json').writeAsStringSync('{no es json');
      expect(await store().read('a'), isNull);
      await store().write('a', [1]);
      expect(await store().read('a'), [1]);
    });
  });
}
