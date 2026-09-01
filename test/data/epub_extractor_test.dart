// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/epub_extractor.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('lanna_extract_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('extrae los archivos preservando rutas', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('META-INF/container.xml', '<container/>'))
      ..addFile(ArchiveFile.string('OEBPS/c1.xhtml', '<html>1</html>'))
      ..addFile(ArchiveFile.bytes('OEBPS/img/a.png', [1, 2, 3]));

    final dest = Directory(p.join(tmp.path, 'book'));
    EpubExtractor.extract(archive, dest);

    expect(
      File(p.join(dest.path, 'META-INF', 'container.xml')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(dest.path, 'OEBPS', 'c1.xhtml')).readAsStringSync(),
      '<html>1</html>',
    );
    expect(File(p.join(dest.path, 'OEBPS', 'img', 'a.png')).readAsBytesSync(), [
      1,
      2,
      3,
    ]);
  });

  test('no vuelve a extraer si el destino ya tiene contenido', () {
    final dest = Directory(p.join(tmp.path, 'book'))
      ..createSync(recursive: true);
    File(p.join(dest.path, 'marcador.txt')).writeAsStringSync('intacto');

    EpubExtractor.extract(
      Archive()..addFile(ArchiveFile.string('nuevo.txt', 'x')),
      dest,
    );

    expect(File(p.join(dest.path, 'nuevo.txt')).existsSync(), isFalse);
    expect(
      File(p.join(dest.path, 'marcador.txt')).readAsStringSync(),
      'intacto',
    );
  });

  test('ignora entradas que escaparían del destino (zip slip)', () {
    final dest = Directory(p.join(tmp.path, 'book'));
    EpubExtractor.extract(
      Archive()..addFile(ArchiveFile.string('../fuera.txt', 'malicioso')),
      dest,
    );

    expect(File(p.join(tmp.path, 'fuera.txt')).existsSync(), isFalse);
  });
}
