// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/book_repository.dart';
import 'package:lanna/data/import/fingerprint.dart';
import 'package:lanna/data/library/book_metadata.dart';
import 'package:lanna/data/library/folder_access.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:path/path.dart' as p;

import '../support/reader_harness.dart';

class _PickingAccess extends DirectoryFolderAccess {
  _PickingAccess(this.next);

  String next;
  bool denyDelete = false;

  @override
  Future<({String location, String name})?> pick() async =>
      (location: next, name: p.basename(next));

  @override
  Future<void> delete(String location) async {
    if (denyDelete) throw FolderWriteDenied(location);
    return super.delete(location);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Directory libros;
  late AppDatabase db;
  late BookRepository repo;
  late _PickingAccess access;

  File epub(String relative, String title, {String author = 'Autora'}) =>
      File(p.join(libros.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(
          buildReaderEpub(
            chapters: ['<p>$title</p>'],
            title: title,
            author: author,
          ),
        );

  Future<List<Book>> allBooks() => db.select(db.books).get();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lanna_scan_');
    libros = Directory(p.join(tmp.path, 'Libros'))..createSync();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    access = _PickingAccess(libros.path);
    repo = BookRepository(
      db,
      access,
      dirs: () async => (
        covers: p.join(tmp.path, 'covers'),
        cache: p.join(tmp.path, 'cache'),
        legacyBooks: p.join(tmp.path, 'legacy'),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('una carpeta nueva aporta sus libros, también de subcarpetas', () async {
    epub('1984.epub', '1984', author: 'Orwell');
    epub('Clásicos/Dorian Gray.epub', 'El retrato de Dorian Gray');
    File(p.join(libros.path, 'notas.txt')).writeAsStringSync('hola');
    epub('.ocultos/secreto.epub', 'Secreto');

    await repo.pickFolder();
    final report = await repo.scan();

    expect(report.added, 2);
    final books = await allBooks();
    expect(
      books.map((b) => b.title),
      unorderedEquals(['1984', 'El retrato de Dorian Gray']),
    );
    final orwell = books.firstWhere((b) => b.title == '1984');
    expect(orwell.author, 'Orwell');
    expect(orwell.format, BookFormat.epub);
    expect(orwell.relativePath, '1984.epub');
    expect(orwell.filePath, p.join(libros.path, '1984.epub'));
    expect(orwell.folderId, isNotNull);
    expect(Directory(p.join(tmp.path, 'legacy')).existsSync(), isFalse);
  });

  test('volver a escanear no duplica nada', () async {
    epub('1984.epub', '1984');
    await repo.pickFolder();
    await repo.scan();

    final again = await repo.scan();

    expect(again.added + again.relocated + again.missing, 0);
    expect(await allBooks(), hasLength(1));
  });

  test('un libro movido o renombrado conserva su progreso', () async {
    final file = epub('1984.epub', '1984');
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;
    await db.saveProgress(bookId: id, percent: 0.4, locator: 'cfi');

    Directory(p.join(libros.path, 'Orwell')).createSync();
    file.renameSync(p.join(libros.path, 'Orwell', 'Mil novecientos.epub'));
    final report = await repo.scan();

    expect(report.relocated, 1);
    expect(report.added, 0);
    final book = (await allBooks()).single;
    expect(book.id, id);
    expect(book.relativePath, 'Orwell/Mil novecientos.epub');
    expect((await db.readProgress(id))?.percent, 0.4);
  });

  test('un archivo que desaparece queda no disponible y vuelve', () async {
    final file = epub('1984.epub', '1984');
    final bytes = file.readAsBytesSync();
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;

    file.deleteSync();
    expect((await repo.scan()).missing, 1);
    expect((await db.findBook(id))?.available, isFalse);

    file.writeAsBytesSync(bytes);
    await repo.scan();
    expect((await db.findBook(id))?.available, isTrue);
    expect(await allBooks(), hasLength(1));
  });

  test(
    'un libro importado antes pasa a la carpeta y se borra su copia',
    () async {
      final legacy = Directory(p.join(tmp.path, 'legacy'))..createSync();
      final original = epub('1984.epub', '1984');
      final copy = original.copySync(p.join(legacy.path, 'viejo.epub'));
      await db.upsertBook(
        BooksCompanion.insert(
          id: 'viejo',
          title: '1984',
          filePath: copy.path,
          format: BookFormat.epub,
          contentHash: Value(await fingerprintFile(copy.path)),
        ),
      );
      await db.saveProgress(bookId: 'viejo', percent: 0.7);

      await repo.pickFolder();
      final report = await repo.scan();

      expect(report.relocated, 1);
      final book = (await allBooks()).single;
      expect(book.id, 'viejo');
      expect(book.filePath, original.path);
      expect(book.folderId, isNotNull);
      expect(copy.existsSync(), isFalse);
      expect((await db.readProgress('viejo'))?.percent, 0.7);
    },
  );

  test(
    'si la carpeta ya no existe, sus libros quedan no disponibles',
    () async {
      epub('1984.epub', '1984');
      await repo.pickFolder();
      await repo.scan();

      libros.deleteSync(recursive: true);
      final report = await repo.scan();

      expect(report.unreachable, ['Libros']);
      expect((await allBooks()).single.available, isFalse);
    },
  );

  test('quitar la carpeta saca sus libros sin tocar los archivos', () async {
    final file = epub('1984.epub', '1984');
    final folder = await repo.pickFolder();
    await repo.scan();

    await repo.removeFolder(folder!);

    expect(await allBooks(), isEmpty);
    expect(file.existsSync(), isTrue);
  });

  test('quitar un libro de la biblioteca lo oculta y no vuelve', () async {
    final file = epub('1984.epub', '1984');
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;

    await repo.deleteBook(id);
    await repo.scan();

    expect((await db.findBook(id))?.hidden, isTrue);
    expect(await db.watchLibrary().first, isEmpty);
    expect(file.existsSync(), isTrue);
  });

  test(
    'eliminar un archivado borra el archivo y vuelve si se copia otra vez',
    () async {
      final file = epub('1984.epub', '1984');
      final bytes = file.readAsBytesSync();
      await repo.pickFolder();
      await repo.scan();
      final id = (await allBooks()).single.id;
      await db.saveProgress(bookId: id, percent: 0.4);
      await repo.deleteBook(id);

      await repo.deleteFromDevice(id);

      expect(file.existsSync(), isFalse);
      expect(await allBooks(), isEmpty);
      expect((await repo.scan()).added, 0);

      file.writeAsBytesSync(bytes);
      final report = await repo.scan();

      expect(report.added, 1);
      final book = (await allBooks()).single;
      expect(book.id, isNot(id));
      expect(book.hidden, isFalse);
      expect(await db.watchLibrary().first, hasLength(1));
      expect(await db.readProgress(book.id), isNull);
    },
  );

  test('si no se puede borrar el archivo, el libro sigue archivado', () async {
    epub('1984.epub', '1984');
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;
    await repo.deleteBook(id);
    access.denyDelete = true;

    await expectLater(
      repo.deleteFromDevice(id),
      throwsA(isA<FolderWriteDenied>()),
    );

    expect((await db.findBook(id))?.hidden, isTrue);
  });

  test('los cómics nuevos traen su serie, de ComicInfo o del nombre', () async {
    File comic(String name, {String? info}) => File(p.join(libros.path, name))
      ..writeAsBytesSync(buildComicZip(pages: ['$name.png'], comicInfo: info));
    comic('Naruto Vol. 1.cbz');
    comic('Naruto Vol. 2.cbz');
    comic('abc.cbz', info: '<ComicInfo><Series>Saga</Series></ComicInfo>');
    epub('Novela 1.epub', 'Novela');

    await repo.pickFolder();
    await repo.scan();

    final byPath = {for (final b in await allBooks()) b.relativePath: b};
    expect(byPath['Naruto Vol. 1.cbz']?.series, 'Naruto');
    expect(byPath['Naruto Vol. 2.cbz']?.series, 'Naruto');
    expect(byPath['abc.cbz']?.series, 'Saga');
    expect(byPath['Novela 1.epub']?.series, isNull);
  });

  test('un cómic que ya estaba recibe su serie al volver a escanear', () async {
    File(p.join(libros.path, 'Akira - Tomo 03.cbz'))
        .writeAsBytesSync(buildComicZip(pages: const ['1.png']));
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;
    await db.updateBook(id, const BooksCompanion(series: Value(null)));

    await repo.scan();

    expect((await db.findBook(id))?.series, 'Akira');
  });

  test('las portadas grandes se achican una sola vez', () async {
    final covers = Directory(p.join(tmp.path, 'covers'))..createSync();
    final big = File(p.join(covers.path, 'grande.png'))
      ..writeAsBytesSync(await _png(1200, 1800));
    final small = File(p.join(covers.path, 'chica.png'))
      ..writeAsBytesSync(await _png(300, 450));
    for (final (id, cover) in [('g', big), ('c', small)]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: id,
          filePath: '/x/$id.epub',
          format: BookFormat.epub,
          coverPath: Value(cover.path),
        ),
      );
    }

    expect(await repo.shrinkCovers(), 1);
    expect(await repo.shrinkCovers(), 0);

    final shrunk = (await db.findBook('g'))!.coverPath!;
    expect(shrunk, isNot(big.path));
    expect(big.existsSync(), isFalse);
    expect(await _width(File(shrunk)), coverWidth);
    expect((await db.findBook('c'))!.coverPath, small.path);
  });

  test('una copia idéntica en otra carpeta no le roba el lugar', () async {
    final original = epub('ERASED/Tomo 01.epub', 'Tomo 01');
    await repo.pickFolder();
    await repo.scan();
    final id = (await allBooks()).single.id;

    final descargas = Directory(p.join(tmp.path, 'Descargas'))..createSync();
    original.copySync(p.join(descargas.path, 'Tomo 01.epub'));
    original.copySync(p.join(libros.path, 'Tomo 01.epub'));
    access.next = descargas.path;
    await repo.pickFolder();

    for (var i = 0; i < 3; i++) {
      final report = await repo.scan();
      expect(report.relocated, 0, reason: 'escaneo $i');
      expect(report.missing, 0, reason: 'escaneo $i');
    }

    final book = (await allBooks()).single;
    expect(book.id, id);
    expect(book.relativePath, 'ERASED/Tomo 01.epub');
    expect(book.available, isTrue);
  });

  test(
    'un tomo que se quitó de su serie no vuelve a ella al escanear',
    () async {
      File(p.join(libros.path, 'Akira - Tomo 03.cbz'))
          .writeAsBytesSync(buildComicZip(pages: const ['1.png']));
      await repo.pickFolder();
      await repo.scan();
      final id = (await allBooks()).single.id;

      await repo.setSeries([id], null);
      await repo.scan();
      expect((await db.findBook(id))?.series, '');

      await repo.setSeries([id], '  Akira  ');
      await repo.scan();
      expect((await db.findBook(id))?.series, 'Akira');
    },
  );

  test('elegir la misma carpeta dos veces no la duplica', () async {
    await repo.pickFolder();
    await repo.pickFolder();

    expect(await db.allFolders(), hasLength(1));
  });
}

Future<List<int>> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF884422),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<int> _width(File file) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final width = descriptor.width;
  descriptor.dispose();
  buffer.dispose();
  return width;
}
