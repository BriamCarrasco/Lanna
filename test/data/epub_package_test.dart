// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_package.dart';

Uint8List buildEpub({
  required String opfPath,
  required String opfXml,
  Map<String, String> textFiles = const {},
  Map<String, List<int>> binaryFiles = const {},
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<?xml version="1.0"?>'
            '<container version="1.0" '
            'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
            '<rootfiles><rootfile full-path="$opfPath" '
            'media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    )
    ..addFile(ArchiveFile.string(opfPath, opfXml));

  textFiles.forEach((name, content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  binaryFiles.forEach((name, bytes) {
    archive.addFile(ArchiveFile.bytes(name, bytes));
  });

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

void main() {
  test('EPUB3: metadata, portada, manifest, spine y TOC (nav doc)', () {
    final bytes = buildEpub(
      opfPath: 'OEBPS/content.opf',
      opfXml: '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>La sombra del viento</dc:title>
    <dc:creator>Carlos Ruiz Zafón</dc:creator>
    <dc:language>es</dc:language>
    <dc:identifier>urn:isbn:9788408079}</dc:identifier>
  </metadata>
  <manifest>
    <item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="c2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
''',
      textFiles: {
        'OEBPS/nav.xhtml': '''
<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<body>
  <nav epub:type="toc">
    <ol>
      <li><a href="c1.xhtml">Uno</a>
        <ol><li><a href="c1.xhtml#s2">Uno punto dos</a></li></ol>
      </li>
      <li><a href="c2.xhtml">Dos</a></li>
    </ol>
  </nav>
</body>
</html>
''',
        'OEBPS/c1.xhtml': '<html><body>c1</body></html>',
        'OEBPS/c2.xhtml': '<html><body>c2</body></html>',
      },
      binaryFiles: {'OEBPS/images/cover.png': _png},
    );

    final book = EpubPackage.parse(bytes);

    expect(book.metadata.title, 'La sombra del viento');
    expect(book.metadata.author, 'Carlos Ruiz Zafón');
    expect(book.metadata.language, 'es');
    expect(book.metadata.coverBytes, isNotNull);
    expect(book.metadata.coverFileName, 'cover.png');

    expect(book.manifest, hasLength(4));
    expect(book.itemById('c1')!.href, 'OEBPS/c1.xhtml');

    expect(book.spine.map((s) => s.href), ['OEBPS/c1.xhtml', 'OEBPS/c2.xhtml']);
    expect(book.spine.first.index, 0);
    expect(book.chapterCount, 2);

    expect(book.toc.map((e) => e.label), ['Uno', 'Dos']);
    expect(book.toc.first.href, 'OEBPS/c1.xhtml');
    expect(book.toc.first.children.single.label, 'Uno punto dos');
    expect(book.toc.first.children.single.href, 'OEBPS/c1.xhtml#s2');
  });

  test('EPUB2: portada por meta, TOC por NCX, linear=no se marca', () {
    final bytes = buildEpub(
      opfPath: 'content.opf',
      opfXml: '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Rayuela</dc:title>
    <dc:creator>Julio Cortázar</dc:creator>
    <meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="cover-img" href="cover.jpeg" media-type="image/jpeg"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="notes" href="notes.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="notes" linear="no"/>
  </spine>
</package>
''',
      textFiles: {
        'toc.ncx': '''
<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint><navLabel><text>Capítulo 1</text></navLabel><content src="ch1.xhtml"/></navPoint>
  </navMap>
</ncx>
''',
        'ch1.xhtml': '<html><body>ch1</body></html>',
        'notes.xhtml': '<html><body>notes</body></html>',
      },
      binaryFiles: {'cover.jpeg': _png},
    );

    final book = EpubPackage.parse(bytes);
    expect(book.metadata.coverFileName, 'cover.jpeg');
    expect(book.spine.map((s) => s.linear), [true, false]);
    expect(book.chapterCount, 1);
    expect(book.toc.single.label, 'Capítulo 1');
    expect(book.toc.single.href, 'ch1.xhtml');
  });

  test('sin portada ni TOC declarados', () {
    final bytes = buildEpub(
      opfPath: 'content.opf',
      opfXml: '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Desnudo</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c1"/></spine>
</package>
''',
      textFiles: {'c1.xhtml': '<html><body>c1</body></html>'},
    );

    final book = EpubPackage.parse(bytes);
    expect(book.metadata.title, 'Desnudo');
    expect(book.metadata.author, isNull);
    expect(book.metadata.coverBytes, isNull);
    expect(book.toc, isEmpty);
    expect(book.spine, hasLength(1));
  });

  test('bytes que no son ZIP lanzan FormatException', () {
    expect(
      () => EpubPackage.parse(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<FormatException>()),
    );
  });
}
