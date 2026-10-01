// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/comic/comic_archive.dart';
import 'package:lanna/data/comic/comic_book.dart';
import 'package:lanna/data/comic/libarchive.dart';
import 'package:lanna/data/storage/random_source.dart';
import 'package:path/path.dart' as p;

import '../support/reader_harness.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('lanna_comic_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('orden natural', () {
    test('los números se comparan por valor, no por texto', () {
      final names = ['p10.jpg', 'p2.jpg', 'p1.jpg', 'p02b.jpg'];
      names.sort(compareNatural);
      expect(names, ['p1.jpg', 'p2.jpg', 'p02b.jpg', 'p10.jpg']);
    });

    test('ignora mayúsculas y ordena por carpeta', () {
      final names = ['B/001.png', 'a/010.png', 'A/002.png'];
      names.sort(compareNatural);
      expect(names, ['A/002.png', 'a/010.png', 'B/001.png']);
    });
  });

  group('ComicInfo', () {
    test('serie y número forman el título', () {
      final info = ComicInfo.parse(
        '<ComicInfo><Series>Saga</Series><Number>3</Number>'
        '<Writer>Brian</Writer></ComicInfo>',
      );
      expect(info.title, 'Saga #3');
      expect(info.writer, 'Brian');
      expect(info.rtl, isFalse);
    });

    test('manga de derecha a izquierda', () {
      final info = ComicInfo.parse(
        '<ComicInfo><Title>Uno</Title>'
        '<Manga>YesAndRightToLeft</Manga></ComicInfo>',
      );
      expect(info.title, 'Uno');
      expect(info.rtl, isTrue);
    });

    test('un XML roto no rompe', () {
      final info = ComicInfo.parse('<ComicInfo><Series>');
      expect(info.title, isNull);
    });
  });

  group('selección de entradas', () {
    test('filtra ocultas, __MACOSX y no imágenes, en orden natural', () {
      final sel = selectComicEntries([
        'dir/',
        'p10.jpg',
        r'sub\p2.jpg',
        '__MACOSX/._p1.jpg',
        '.hidden.jpg',
        './p1.jpg',
        'notes.txt',
        'ComicInfo.xml',
      ]);
      expect(sel.pages, [5, 1, 2]);
      expect(sel.info, 7);
    });
  });

  group('lectura por página', () {
    late String cache;
    setUp(() => cache = p.join(tmp.path, 'cache'));

    test('un CBZ abre sin extraer, en orden y con sus metadatos', () async {
      final cbz = File(p.join(tmp.path, 'a.cbz'))
        ..writeAsBytesSync(
          buildComicZip(
            pages: ['p10.png', 'p2.png', 'p1.png', '__MACOSX/._p1.png'],
            comicInfo:
                '<ComicInfo><Series>Saga</Series><Number>1</Number>'
                '<Manga>YesAndRightToLeft</Manga></ComicInfo>',
          ),
        );

      final comic = await ComicArchive.open(
        pathSpec(cbz.path),
        cacheDir: cache,
      );
      addTearDown(comic.close);

      expect(comic.book.pages, ['p1.png', 'p2.png', 'p10.png']);
      expect(comic.book.title, 'Saga #1');
      expect(comic.book.rtl, isTrue);
      expect(await comic.page(0), tinyPng);
      expect(await comic.page(0), tinyPng);
      expect(Directory(cache).existsSync(), isFalse);
    });

    test('lee páginas comprimidas y en paralelo', () async {
      final archive = Archive();
      for (var i = 1; i <= 6; i++) {
        archive.addFile(
          ArchiveFile.bytes('$i.jpg', List<int>.filled(5000, i))
            ..compression = CompressionType.deflate,
        );
      }
      final cbz = File(p.join(tmp.path, 'd.cbz'))
        ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));

      final comic = await ComicArchive.open(
        pathSpec(cbz.path),
        cacheDir: cache,
      );
      addTearDown(comic.close);

      final pages = await Future.wait([
        for (var i = 5; i >= 0; i--) comic.page(i),
      ]);
      for (var i = 0; i < 6; i++) {
        expect(pages[5 - i], List<int>.filled(5000, i + 1));
      }
    });

    test('borra la extracción que dejaban las versiones anteriores', () async {
      final cbz = File(p.join(tmp.path, 'a.cbz'))
        ..writeAsBytesSync(buildComicZip(pages: ['1.png']));
      File(p.join(cache, '1.png'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(tinyPng);

      final comic = await ComicArchive.open(
        pathSpec(cbz.path),
        cacheDir: cache,
      );
      await comic.close();
      for (var i = 0; i < 50 && Directory(cache).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(Directory(cache).existsSync(), isFalse);
    });

    test('un archivo que no es cómic avisa con un mensaje claro', () async {
      final bad = File(p.join(tmp.path, 'x.cbz'))
        ..writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(
        () => ComicArchive.open(pathSpec(bad.path), cacheDir: cache),
        throwsA(isA<ComicFormatException>()),
      );
    });

    test('un zip dañado avisa con un mensaje claro', () async {
      final bad = File(p.join(tmp.path, 'x.cbz'))
        ..writeAsBytesSync([0x50, 0x4B, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(
        () => ComicArchive.open(pathSpec(bad.path), cacheDir: cache),
        throwsA(isA<ComicFormatException>()),
      );
    });

    test('un zip sin imágenes no es un cómic', () async {
      final empty = File(p.join(tmp.path, 'e.cbz'))
        ..writeAsBytesSync(buildComicZip(pages: const []));
      expect(
        () => ComicArchive.open(pathSpec(empty.path), cacheDir: cache),
        throwsA(isA<ComicFormatException>()),
      );
    });

    for (final (label, fixture) in [('RAR5', _rar5), ('RAR4', _rar4)]) {
      test('un CBR $label se lee por página con libarchive', () async {
        final cbr = File(p.join(tmp.path, 'a.cbr'))
          ..writeAsBytesSync(base64Decode(fixture));
        final comic = await ComicArchive.open(
          pathSpec(cbr.path),
          cacheDir: cache,
        );
        addTearDown(comic.close);

        expect(comic.book.pages, ['p1.png', 'p2.png', 'p10.png']);
        expect(comic.book.title, 'Prueba #7');
        expect(await comic.page(2), tinyPng);
        expect(await comic.page(0), tinyPng);
        expect(Directory(cache).existsSync(), isFalse);
      }, skip: LibArchive.instance == null ? 'sin libarchive' : false);
    }

    test('distingue zip de rar por la firma', () {
      final zip = File(p.join(tmp.path, 'z'))
        ..writeAsBytesSync(buildComicZip(pages: ['1.png']));
      final rar = File(p.join(tmp.path, 'r'))
        ..writeAsBytesSync([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00]);
      expect(sniffComic(zip.path), ComicContainer.zip);
      expect(sniffComic(rar.path), ComicContainer.rar);
    });
  });
}

const _rar5 =
    'UmFyIRoHAQAzkrXlCgEFBgAFAQGAgADnUDRNIgIDC8QABMQAIK/I0FeAAAAGcDEucG5nCgMCIubtKnNQ3QGJUE5HDQoaCgAAAA1JSERSAAAAAQAAAAEIBAAAALUcDAIAAAALSURBVHjaY2RgAAAABgACMIHQLwAAAABJRU5ErkJggodxyngiAgMLxAAExAAgr8jQV4AAAAZwMi5wbmcKAwIvDe4qc1DdAYlQTkcNChoKAAAADUlIRFIAAAABAAAAAQgEAAAAtRwMAgAAAAtJREFUeNpjZGAAAAAGAAIwgdAvAAAAAElFTkSuQmCC1iwQWSMCAwvEAATEACCvyNBXgAAAB3AxMC5wbmcKAwIvDe4qc1DdAYlQTkcNChoKAAAADUlIRFIAAAABAAAAAQgEAAAAtRwMAgAAAAtJREFUeNpjZGAAAAAGAAIwgdAvAAAAAElFTkSuQmCCNIzzBCkCAwvBAATCACAYbmDAgAMADUNvbWljSW5mby54bWwKAwLglu8qc1DdAcOnPiRAMvozvQcWbGmEpamlEHAlSINCoRHf65TAce//D8p6jssCHNZvHeOCFCPJdGZ+K1QcrBL2rEYvSKigfdrAHXdWUQMFBAA=';

const _rar4 =
    'UmFyIRoHAM+QcwAADQAAAAAAAABnr3QgkCsARAAAAEQAAAACr8jQVw2sPV0dMAYAIAAAAHAxLnBuZwCwIt0oiVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYIL3yXQgkCsARAAAAEQAAAACr8jQVw2sPV0dMAYAIAAAAHAyLnBuZwCwLwQpiVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYIL2EnQgkCwARAAAAEQAAAACr8jQVw2sPV0dMAcAIAAAAHAxMC5wbmcAsC8EKYlQTkcNChoKAAAADUlIRFIAAAABAAAAAQgEAAAAtRwMAgAAAAtJREFUeNpjZGAAAAAGAAIwgdAvAAAAAElFTkSuQmCCZSp0IJAyAD8AAABCAAAAAhhuYMANrD1dHTMNACAAAABDb21pY0luZm8ueG1sALDgjSoJVBC+iO6DizRjx0WTFEHAlTkGCoKO/tVrwOH//D2S+h7HQZi1ZtvTAhAs1LQvzspRBR8Dt2l1CvwnPR9SjiDEPXsAQAcA';
