// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_book.dart';
import 'package:lanna/data/epub/epub_package.dart';

void main() {
  Uint8List buildEpub({required String ncx}) {
    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('mimetype', 'application/epub+zip');
    add(
      'META-INF/container.xml',
      '<?xml version="1.0"?><container version="1.0" '
          'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
          '<rootfiles><rootfile full-path="OEBPS/content.opf" '
          'media-type="application/oebps-package+xml"/></rootfiles></container>',
    );
    add(
      'OEBPS/content.opf',
      '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" '
          'version="2.0" unique-identifier="id">'
          '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
          '<dc:title>T</dc:title><dc:identifier id="id">x</dc:identifier>'
          '</metadata>'
          '<manifest>'
          '<item id="ncx" href="toc.ncx" '
          'media-type="application/x-dtbncx+xml"/>'
          '<item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>'
          '<item id="c2" href="c2.xhtml" media-type="application/xhtml+xml"/>'
          '</manifest>'
          '<spine toc="ncx"><itemref idref="c1"/><itemref idref="c2"/></spine>'
          '</package>',
    );
    add('OEBPS/c1.xhtml', '<html><body><p>uno</p></body></html>');
    add('OEBPS/c2.xhtml', '<html><body><p>dos</p></body></html>');
    add('OEBPS/toc.ncx', ncx);

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  String ncx(String navMap) =>
      '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" '
      'version="2005-1"><navMap>$navMap</navMap></ncx>';

  String point(String label, String src, [String children = '']) =>
      '<navPoint><navLabel><text>$label</text></navLabel>'
      '<content src="$src"/>$children</navPoint>';

  List<String> flatLabels(List<EpubTocEntry> toc) {
    final out = <String>[];
    void walk(List<EpubTocEntry> items) {
      for (final e in items) {
        out.add(e.label);
        walk(e.children);
      }
    }

    walk(toc);
    return out;
  }

  test('quita las entradas que son solo un número bajo un título', () {
    final book = EpubPackage.parse(
      buildEpub(
        ncx: ncx(
          point('LA RAÍZ DEL MAL', 'c1.xhtml', point('1', 'c1.xhtml#a')) +
              point(
                'EL RELOJ DEL DRAGÓN',
                'c2.xhtml',
                point('2', 'c2.xhtml#b'),
              ),
        ),
      ),
    );

    expect(flatLabels(book.toc), ['LA RAÍZ DEL MAL', 'EL RELOJ DEL DRAGÓN']);
  });

  test('no toca etiquetas que solo empiezan por un número', () {
    final book = EpubPackage.parse(
      buildEpub(
        ncx: ncx(
          point('1. La primera discusión', 'c1.xhtml') +
              point('2. A la mañana siguiente', 'c2.xhtml'),
        ),
      ),
    );

    expect(flatLabels(book.toc), [
      '1. La primera discusión',
      '2. A la mañana siguiente',
    ]);
  });

  test('si TODAS las entradas son números, no borra nada', () {
    final book = EpubPackage.parse(
      buildEpub(ncx: ncx(point('1', 'c1.xhtml') + point('2', 'c2.xhtml'))),
    );

    expect(flatLabels(book.toc), ['1', '2']);
  });

  test('quita un hijo con el mismo título que su padre', () {
    final book = EpubPackage.parse(
      buildEpub(
        ncx: ncx(
          point(
                'Introducción',
                'c1.xhtml',
                point('Introducción', 'c1.xhtml#dup'),
              ) +
              point('Final', 'c2.xhtml'),
        ),
      ),
    );

    expect(flatLabels(book.toc), ['Introducción', 'Final']);
  });

  test('conserva un número que tiene subcapítulos con título', () {
    final book = EpubPackage.parse(
      buildEpub(
        ncx: ncx(
          point('Parte I', 'c1.xhtml') +
              point('3', 'c2.xhtml', point('La huida', 'c2.xhtml#h')),
        ),
      ),
    );

    expect(flatLabels(book.toc), ['Parte I', '3', 'La huida']);
  });

  test('los hrefs de las entradas que quedan no cambian', () {
    final book = EpubPackage.parse(
      buildEpub(
        ncx: ncx(
          point('Cap uno', 'c1.xhtml', point('1', 'c1.xhtml#x')) +
              point('Cap dos', 'c2.xhtml'),
        ),
      ),
    );

    expect(book.toc.first.href, 'OEBPS/c1.xhtml');
    expect(book.toc.first.children, isEmpty);
  });
}
