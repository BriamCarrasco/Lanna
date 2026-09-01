// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/core/text_search.dart';

void main() {
  test('foldForSearch quita acentos y pasa a minúsculas', () {
    expect(foldForSearch('  Cortázar '), 'cortazar');
    expect(foldForSearch('Ñandú'), 'nandu');
    expect(foldForSearch('RÉQUIEM'), 'requiem');
  });

  test('matchesQuery ignora acentos y mayúsculas', () {
    expect(matchesQuery('Julio Cortázar', foldForSearch('cortazar')), isTrue);
    expect(matchesQuery('Rayuela', foldForSearch('yue')), isTrue);
    expect(matchesQuery('Rayuela', foldForSearch('kafka')), isFalse);
  });

  test('query vacía siempre coincide', () {
    expect(matchesQuery('cualquier cosa', ''), isTrue);
  });
}
