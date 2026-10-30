// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/core/theme/app_theme.dart';
import 'package:lanna/data/epub/epub_book.dart';
import 'package:lanna/data/epub/epub_document.dart';
import 'package:lanna/data/epub/epub_styles.dart';
import 'package:lanna/features/reader/native/book_source.dart';
import 'package:lanna/features/reader/native/page_canvas.dart';
import 'package:lanna/features/reader/native/paginator.dart';

void main() {
  testWidgets('cada fragmento pintado cabe en el alto que midió el paginador', (
    tester,
  ) async {
    final text = List.filled(600, 'aaaa').join(' ');
    final document = EpubDocumentParser.parse(
      '<html><body><p>$text</p><p><i>$text</i></p></body></html>',
      spineIndex: 0,
      href: 'OEBPS/cap1.xhtml',
      styles: EpubStyles.parse(const ['']),
    );
    const style = PaginationStyle(fontFamily: 'Newsreader', fontSize: 10);
    const metrics = PaginationMetrics(size: Size(7 * 50 - 10 + 48, 640));
    final pagination = Paginator(
      style: style,
      metrics: metrics,
    ).paginate(document);
    final source = NativeBookSource(
      root: Directory.systemTemp,
      book: const EpubBook(
        opfPath: 'OEBPS/content.opf',
        metadata: EpubMetadata(),
        manifest: [],
        spine: [],
        toc: [],
      ),
    );

    for (final page in pagination.pages) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: metrics.size,
                child: NativePage(
                  page: page,
                  style: style,
                  metrics: metrics,
                  source: source,
                  foreground: Colors.white,
                  linkColor: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      )) {
        final length = paragraph.text.toPlainText().length;
        final caret = TextPosition(offset: length);
        final bottom =
            paragraph.getOffsetForCaret(caret, Rect.zero).dy +
            paragraph.getFullHeightForCaret(caret);
        expect(
          bottom,
          lessThanOrEqualTo(paragraph.size.height + 0.5),
          reason: 'la página ${page.index} recorta la última línea',
        );
      }
    }
  });
}
