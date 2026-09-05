// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_document.dart';
import 'package:lanna/data/epub/epub_package.dart';
import 'package:lanna/features/reader/native/paginator.dart';

const arabe = 'الفصل الأول';
const arabeLargo = 'كان يا مكان في قديم الزمان';
const hebreo = 'שלום עולם';

Uint8List epubConSpine(String spineAttrs) {
  const opf = 'OEBPS/content.opf';
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?>'
            '<container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="$opf" '
            'media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        opf,
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:title>T</dc:title></metadata>'
        '<manifest><item id="c1" href="c1.xhtml" '
        'media-type="application/xhtml+xml"/></manifest>'
        '<spine $spineAttrs><itemref idref="c1"/></spine>'
        '</package>',
      ),
    )
    ..addFile(ArchiveFile.string('OEBPS/c1.xhtml', '<html><body/></html>'));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EpubDocument doc(String html, {bool rtl = false}) =>
      EpubDocumentParser.parse(html, spineIndex: 0, href: 'c1.xhtml', rtl: rtl);

  group('dirección declarada', () {
    test('page-progression-direction rtl marca el libro', () {
      expect(
        EpubPackage.parse(epubConSpine('page-progression-direction="rtl"')).rtl,
        isTrue,
      );
      expect(
        EpubPackage.parse(epubConSpine('page-progression-direction="ltr"')).rtl,
        isFalse,
      );
      expect(EpubPackage.parse(epubConSpine('')).rtl, isFalse);
    });

    test('dir en html marca el documento y sus bloques', () {
      final d = doc('<html dir="rtl"><body><p>$arabe</p></body></html>');

      expect(d.rtl, isTrue);
      expect(d.blocks.single.rtl, isTrue);
    });

    test('un dir por bloque gana sobre el del libro', () {
      final d = doc(
        '<html><body><p>uno</p><p dir="rtl">$hebreo</p></body></html>',
        rtl: false,
      );

      expect(d.blocks[0].rtl, isFalse);
      expect(d.blocks[1].rtl, isTrue);
    });

    test('un bloque ltr dentro de un libro rtl vuelve a la izquierda', () {
      final d = doc(
        '<html><body><p>$arabe</p><p dir="ltr">latin</p></body></html>',
        rtl: true,
      );

      expect(d.blocks[0].rtl, isTrue);
      expect(d.blocks[1].rtl, isFalse);
    });

    test('un contenedor con dir lo propaga a sus hijos', () {
      final d = doc(
        '<html><body><div dir="rtl"><p>$arabe</p>'
        '<p>$arabe</p></div></body></html>',
      );

      expect(d.blocks.map((b) => b.rtl), [true, true]);
    });

    test('el dir del libro llega si el documento no dice nada', () {
      expect(doc('<p>$arabe</p>', rtl: true).blocks.single.rtl, isTrue);
      expect(doc('<p>hola</p>').blocks.single.rtl, isFalse);
    });
  });

  group('composición rtl', () {
    test('la dirección del bloque llega al painter', () {
      final d = doc('<p dir="rtl">$arabe</p>');

      expect(directionOf(d.blocks.single), ui.TextDirection.rtl);
      expect(directionOf(doc('<p>x</p>').blocks.single), ui.TextDirection.ltr);
    });

    test('la alineación por defecto es relativa, no izquierda', () {
      const style = PaginationStyle(justify: false);
      final block = doc('<p dir="rtl">$arabe</p>').blocks.single;

      expect(style.alignFor(block), TextAlign.start);
    });

    test('un texto árabe se pagina y se cubre entero', () {
      final d = doc('<p dir="rtl">${'$arabeLargo ' * 120}</p>');
      final result = Paginator(
        style: const PaginationStyle(fontSize: 18),
        metrics: const PaginationMetrics(size: Size(400, 600)),
      ).paginate(d);

      expect(result.pages, isNotEmpty);
      var prev = result.pages.first.start;
      for (final page in result.pages) {
        expect(page.start, prev);
        prev = page.end;
      }
      expect(result.pages.last.end, d.length);
    });

    test('rtl y ltr del mismo texto ocupan lo mismo', () {
      final texto = '$arabeLargo ' * 40;
      DocumentPagination pag(bool rtl) => Paginator(
        style: const PaginationStyle(fontSize: 18),
        metrics: const PaginationMetrics(size: Size(400, 600)),
      ).paginate(doc('<p>$texto</p>', rtl: rtl));

      expect(pag(true).pageCount, pag(false).pageCount);
    });
  });
}
