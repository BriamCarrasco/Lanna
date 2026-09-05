// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/reader_screen.dart';

void main() {
  group('sentido de avance', () {
    test('en ltr, arrastrar a la izquierda avanza', () {
      expect(turnForTravel(-80, rtl: false), 1);
      expect(turnForTravel(80, rtl: false), -1);
    });

    test('en rtl, arrastrar a la derecha avanza', () {
      expect(turnForTravel(80, rtl: true), 1);
      expect(turnForTravel(-80, rtl: true), -1);
    });

    test('el toque de borde sigue al sentido del libro', () {
      expect(turnForEdge(leading: true, rtl: false), -1);
      expect(turnForEdge(leading: false, rtl: false), 1);
      expect(turnForEdge(leading: true, rtl: true), 1);
      expect(turnForEdge(leading: false, rtl: true), -1);
    });

    test('el pliegue se invierte pero el avance lógico no', () {
      expect(foldFor(1, rtl: false), 1);
      expect(foldFor(-1, rtl: false), -1);
      expect(foldFor(1, rtl: true), -1);
      expect(foldFor(-1, rtl: true), 1);
    });
  });
}
