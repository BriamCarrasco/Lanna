// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/reader/reader_screen.dart';

void main() {
  const toolbar = Size(236, 44);

  Offset origin(Rect selection, Size viewport) => selectionToolbarOrigin(
    selection: selection,
    viewport: viewport,
    toolbar: toolbar,
  );

  test('se centra sobre la selección y queda encima', () {
    final at = origin(
      const Rect.fromLTRB(300, 400, 500, 430),
      const Size(800, 900),
    );

    expect(at.dx, 400 - toolbar.width / 2);
    expect(at.dy, 400 - toolbar.height - 10);
  });

  test('una selección arriba del todo empuja la barra debajo', () {
    final at = origin(
      const Rect.fromLTRB(300, 20, 500, 50),
      const Size(800, 900),
    );

    expect(at.dy, 60);
  });

  test('no se sale por los bordes de una ventana ancha', () {
    final left = origin(
      const Rect.fromLTRB(0, 400, 40, 430),
      const Size(800, 900),
    );
    final right = origin(
      const Rect.fromLTRB(760, 400, 800, 430),
      const Size(800, 900),
    );

    expect(left.dx, 8);
    expect(right.dx, 800 - toolbar.width - 8);
  });

  test('una ventana más estrecha que la barra no lanza', () {
    final at = origin(
      const Rect.fromLTRB(20, 30, 180, 60),
      const Size(200, 140),
    );

    expect(at.dx, 8);
    expect(at.dy, 60);
  });

  test('una ventana diminuta tampoco lanza', () {
    final at = origin(Rect.zero, const Size(1, 1));

    expect(at.dx, 8);
    expect(at.dy, 60);
  });
}
