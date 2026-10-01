// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/features/library/widgets/book_cover.dart';

void main() {
  test('el ancho de decodificación sigue a la pantalla, en escalones', () {
    expect(coverDecodeWidth(150, 1), 192);
    expect(coverDecodeWidth(150, 2.625), 448);
    expect(coverDecodeWidth(148, 2.625), coverDecodeWidth(150, 2.625));
    expect(coverDecodeWidth(64, 1), 64);
  });

  testWidgets('la portada se decodifica al tamaño en que se muestra', (
    tester,
  ) async {
    final book = Book(
      id: 'a',
      title: 'Rayuela',
      filePath: '/a.epub',
      format: BookFormat.epub,
      coverPath: '/no/existe.png',
      available: true,
      hidden: false,
      addedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 150, child: BookCover(book: book)),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(image, isA<ResizeImage>());
    expect((image as ResizeImage).width, coverDecodeWidth(150, 3));
  });
}
