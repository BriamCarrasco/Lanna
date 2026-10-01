// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/book_repository.dart';
import 'package:lanna/data/import/fingerprint.dart';
import 'package:lanna/data/library/folder_access.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:path/path.dart' as p;

import '../support/reader_harness.dart';

class _PickingAccess extends DirectoryFolderAccess {
  _PickingAccess(this.next);

  String next;

  @override
  Future<({String location, String name})?> pick() async =>
      (location: next, name: p.basename(next));
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

  test('elegir la misma carpeta dos veces no la duplica', () async {
    await repo.pickFolder();
    await repo.pickFolder();

    expect(await db.allFolders(), hasLength(1));
  });
}
