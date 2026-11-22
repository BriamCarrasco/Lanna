// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:lanna/data/transfer/progress_transfer.dart';

final _hashA = 'a' * 64;
final _hashB = 'b' * 64;
final _now = DateTime.utc(2026, 10, 7, 12);

void main() {
  late AppDatabase phone;
  late AppDatabase desktop;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    phone = AppDatabase.forTesting(NativeDatabase.memory());
    desktop = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await phone.close();
    await desktop.close();
  });

  Future<void> book(
    AppDatabase db,
    String id, {
    String? hash,
    String title = 'Rayuela',
    String author = 'Cortázar',
    BookFormat format = BookFormat.epub,
    String path = '/storage/emulated/0/Libros/rayuela.epub',
    DateTime? finishedAt,
  }) => db.upsertBook(
    BooksCompanion.insert(
      id: id,
      title: title,
      filePath: path,
      format: format,
      author: Value(author),
      contentHash: Value(hash),
      finishedAt: Value(finishedAt),
    ),
  );

  Future<void> progress(
    AppDatabase db,
    String id,
    double percent,
    DateTime at, {
    String? locator,
  }) => db
      .into(db.readingProgress)
      .insertOnConflictUpdate(
        ReadingProgressCompanion.insert(
          bookId: id,
          locator: Value(locator),
          percent: Value(percent),
          chapterIndex: const Value(3),
          updatedAt: Value(at),
        ),
      );

  ProgressTransfer transfer(AppDatabase db) =>
      ProgressTransfer(db, clock: () => _now);

  Uint8List file(List<Object?> books) => utf8.encode(
    jsonEncode({'kind': progressFileKind, 'version': 1, 'books': books}),
  );

  test(
    'el progreso viaja entre dispositivos por la huella del libro',
    () async {
      await book(phone, 'android-1', hash: _hashA);
      await book(
        phone,
        'android-2',
        hash: _hashB,
        title: 'Ficciones',
        finishedAt: DateTime.utc(2026, 9),
      );
      await progress(
        phone,
        'android-1',
        0.42,
        DateTime.utc(2026, 10, 1),
        locator: 'spine:3#120',
      );
      await book(
        desktop,
        'win-1',
        hash: _hashA,
        path: r'C:\Users\Ana\Libros\Rayuela.epub',
      );
      await book(desktop, 'win-2', hash: _hashB, title: 'Ficciones');

      final bytes = await transfer(phone).export();
      final json = utf8.decode(bytes);
      expect(json, isNot(contains('/storage')));
      expect(json, isNot(contains('android-1')));

      final report = await transfer(desktop).import(bytes);

      expect(report.applied, 2);
      final row = await desktop.readProgress('win-1');
      expect(row?.locator, 'spine:3#120');
      expect(row?.percent, 0.42);
      expect(row?.chapterIndex, 3);
      expect(row?.updatedAt.toUtc(), DateTime.utc(2026, 10, 1));
      expect(
        (await desktop.findBook('win-2'))?.finishedAt?.toUtc(),
        DateTime.utc(2026, 9),
      );
    },
  );

  test('gana la lectura más reciente y reimportar no cambia nada', () async {
    await book(phone, 'p', hash: _hashA);
    await progress(phone, 'p', 0.5, DateTime.utc(2026, 10, 2));
    await book(desktop, 'd', hash: _hashA);
    await progress(desktop, 'd', 0.8, DateTime.utc(2026, 10, 3));

    final older = await transfer(phone).export();
    final report = await transfer(desktop).import(older);
    expect(report.applied, 0);
    expect(report.upToDate, 1);
    expect((await desktop.readProgress('d'))?.percent, 0.8);

    await progress(phone, 'p', 0.9, DateTime.utc(2026, 10, 4));
    final newer = await transfer(phone).export();
    expect((await transfer(desktop).import(newer)).applied, 1);
    expect((await desktop.readProgress('d'))?.percent, 0.9);

    final again = await transfer(desktop).import(newer);
    expect(again.applied, 0);
    expect(again.upToDate, 1);
  });

  test('sin huella coincidente usa el título solo si es único', () async {
    await book(phone, 'p', hash: _hashA);
    await progress(
      phone,
      'p',
      0.3,
      DateTime.utc(2026, 10, 1),
      locator: 'spine:9#40',
    );
    await book(desktop, 'otra-edicion', hash: _hashB);

    final bytes = await transfer(phone).export();
    expect((await transfer(desktop).import(bytes)).applied, 1);
    final row = await desktop.readProgress('otra-edicion');
    expect(row?.percent, 0.3);
    expect(row?.locator, isNull);

    await book(desktop, 'duplicado', hash: 'c' * 64);
    await desktop.delete(desktop.readingProgress).go();
    final report = await transfer(desktop).import(bytes);
    expect(report.unmatched, 1);
    expect(await desktop.readProgress('otra-edicion'), isNull);
  });

  test('las entradas dañadas se saltan sin romper el resto', () async {
    await book(desktop, 'd', hash: _hashA);

    final report = await transfer(desktop).import(
      file([
        null,
        5,
        'texto',
        {'title': ''},
        {'hash': 'no-es-hash', 'format': 'epub'},
        {
          'hash': _hashA,
          'progress': {'percent': 'mucho', 'updatedAt': 'ayer'},
        },
        {
          'hash': 'f' * 64,
          'progress': {'updatedAt': '2026-10-01T00:00:00Z'},
        },
        {
          'hash': _hashA,
          'format': 'epub',
          'progress': {
            'locator': 'javascript:alert(1)',
            'percent': 7,
            'chapterIndex': -2,
            'updatedAt': '2999-01-01T00:00:00Z',
          },
        },
      ]),
    );

    expect(report.invalid, 6);
    expect(report.unmatched, 1);
    expect(report.applied, 1);
    final row = await desktop.readProgress('d');
    expect(row?.percent, 1.0);
    expect(row?.locator, isNull);
    expect(row?.chapterIndex, isNull);
    expect(row?.updatedAt.toUtc(), _now);
  });

  test('un archivo que no es un respaldo se rechaza con un mensaje', () async {
    Future<void> rejects(List<int> bytes) => expectLater(
      transfer(desktop).import(Uint8List.fromList(bytes)),
      throwsA(isA<ProgressFileException>()),
    );

    await rejects([0xff, 0xfe, 0x00]);
    await rejects(utf8.encode('no es json'));
    await rejects(utf8.encode('[]'));
    await rejects(utf8.encode('{"kind": "otra-app", "books": []}'));
    await rejects(utf8.encode('{"kind": "$progressFileKind", "books": {}}'));
  });

  Future<void> session(
    AppDatabase db,
    String id,
    DateTime start,
    int seconds,
  ) => db.addReadingSession(
    ReadingSessionsCompanion.insert(
      bookId: id,
      startedAt: start,
      seconds: seconds,
      startPercent: const Value(0.1),
      endPercent: const Value(0.2),
      pages: const Value(12),
    ),
  );

  Future<List<ReadingSession>> sessions(AppDatabase db) =>
      db.select(db.readingSessions).get();

  test(
    'las sesiones de lectura viajan con el progreso y no se duplican',
    () async {
      await book(phone, 'p', hash: _hashA);
      await progress(phone, 'p', 0.4, DateTime.utc(2026, 10, 2));
      await session(phone, 'p', DateTime.utc(2026, 10, 1, 8), 1200);
      await session(phone, 'p', DateTime.utc(2026, 10, 2, 21), 900);
      await book(phone, 'solo-sesiones', hash: _hashB, title: 'Ficciones');
      await session(phone, 'solo-sesiones', DateTime.utc(2026, 9, 30), 600);
      await book(desktop, 'd', hash: _hashA);
      await book(desktop, 'd2', hash: _hashB, title: 'Ficciones');
      await session(desktop, 'd', DateTime.utc(2026, 10, 1, 8), 1200);

      final bytes = await transfer(phone).export();
      final report = await transfer(desktop).import(bytes);

      expect(report.applied, 2);
      final rows = await sessions(desktop);
      expect(rows, hasLength(3));
      final added = rows.firstWhere(
        (s) => s.startedAt.toUtc() == DateTime.utc(2026, 10, 2, 21),
      );
      expect(added.bookId, 'd');
      expect(added.seconds, 900);
      expect(added.startPercent, 0.1);
      expect(added.endPercent, 0.2);
      expect(added.pages, 12);
      expect(rows.where((s) => s.bookId == 'd2').single.seconds, 600);

      final again = await transfer(desktop).import(bytes);
      expect(again.applied, 0);
      expect(again.upToDate, 2);
      expect(await sessions(desktop), hasLength(3));
    },
  );

  test('las sesiones dañadas o futuras se descartan', () async {
    await book(desktop, 'd', hash: _hashA);

    final report = await transfer(desktop).import(
      file([
        {
          'hash': _hashA,
          'format': 'epub',
          'sessions': [
            null,
            {'startedAt': 'ayer', 'seconds': 60},
            {'startedAt': '2026-10-01T10:00:00Z', 'seconds': -5},
            {'startedAt': '2026-10-01T10:00:00Z', 'seconds': 999999},
            {'startedAt': '2999-01-01T00:00:00Z', 'seconds': 60},
            {
              'startedAt': '2026-10-01T10:00:00Z',
              'seconds': 300,
              'startPercent': 'x',
              'endPercent': 3,
              'pages': -1,
            },
          ],
        },
        {
          'hash': _hashA,
          'sessions': [
            {'startedAt': 'mal', 'seconds': 1},
          ],
        },
      ]),
    );

    expect(report.applied, 1);
    expect(report.invalid, 1);
    final row = (await sessions(desktop)).single;
    expect(row.seconds, 300);
    expect(row.startPercent, 0);
    expect(row.endPercent, 1);
    expect(row.pages, 0);
  });

  Future<Set<String>> members(AppDatabase db, String collectionId) async => {
    for (final e in await (db.select(
      db.collectionEntries,
    )..where((e) => e.collectionId.equals(collectionId))).get())
      e.bookId,
  };

  test('las colecciones viajan con su id y reimportar no duplica', () async {
    await book(phone, 'p1', hash: _hashA);
    await book(phone, 'p2', hash: _hashB, title: 'Libro B', author: 'Autora B');
    await phone.createCollection('col-a', 'Colección A');
    await phone.createCollection('col-vacia', 'Pendientes');
    await phone
        .into(phone.collectionEntries)
        .insert(
          CollectionEntriesCompanion.insert(
            collectionId: 'col-a',
            bookId: 'p2',
            addedAt: Value(DateTime.utc(2026, 10, 5)),
          ),
        );
    await book(desktop, 'd1', hash: _hashA);
    await book(
      desktop,
      'd2',
      hash: 'c' * 64,
      title: 'Libro B',
      author: 'Autora B',
    );

    final bytes = await transfer(phone).export();
    final report = await transfer(desktop).import(bytes);

    expect(report.collections, 2);
    final collection = await desktop.findCollection('col-a');
    expect(collection?.name, 'Colección A');
    expect(await desktop.findCollection('col-vacia'), isNotNull);
    expect(await members(desktop, 'col-a'), {'d2'});
    final entry = await (desktop.select(
      desktop.collectionEntries,
    )..where((e) => e.bookId.equals('d2'))).getSingle();
    expect(entry.addedAt.toUtc(), DateTime.utc(2026, 10, 5));

    final again = await transfer(desktop).import(bytes);
    expect(again.collections, 0);
    expect(await desktop.select(desktop.collections).get(), hasLength(2));
    expect(await members(desktop, 'col-a'), {'d2'});
  });

  test(
    'una colección con el mismo nombre se une sin borrar lo local',
    () async {
      await book(phone, 'p1', hash: _hashA);
      await book(phone, 'p2', hash: _hashB, title: 'Libro B');
      await phone.createCollection('id-telefono', 'Pendientes de Leer');
      for (final id in ['p1', 'p2']) {
        await phone
            .into(phone.collectionEntries)
            .insert(
              CollectionEntriesCompanion.insert(
                collectionId: 'id-telefono',
                bookId: id,
              ),
            );
      }
      await book(desktop, 'd1', hash: _hashA);
      await book(desktop, 'd2', hash: _hashB, title: 'Libro B');
      await book(desktop, 'd3', hash: 'c' * 64, title: 'Libro C');
      await desktop.createCollection('id-pc', 'pendientes de leer');
      await desktop
          .into(desktop.collectionEntries)
          .insert(
            CollectionEntriesCompanion.insert(
              collectionId: 'id-pc',
              bookId: 'd3',
            ),
          );

      final report = await transfer(desktop)
          .import(await transfer(phone).export());

      expect(report.collections, 1);
      expect(await desktop.findCollection('id-telefono'), isNull);
      expect(await members(desktop, 'id-pc'), {'d1', 'd2', 'd3'});
    },
  );

  test('las colecciones dañadas se saltan sin romper el resto', () async {
    await book(desktop, 'd', hash: _hashA);

    final report = await transfer(desktop).import(
      utf8.encode(
        jsonEncode({
          'kind': progressFileKind,
          'books': <Object?>[],
          'collections': [
            null,
            {'id': 'ok', 'name': ''},
            {'id': '../../x', 'name': 'Mala'},
            {'id': 'x' * 65, 'name': 'Larga'},
            {
              'id': 'buena',
              'name': 'Buena',
              'createdAt': '2999-01-01T00:00:00Z',
              'books': [
                null,
                {'hash': 'no-es-hash'},
                {'hash': 'f' * 64, 'format': 'epub'},
                {'hash': _hashA, 'addedAt': 'ayer'},
              ],
            },
          ],
        }),
      ),
    );

    expect(report.collections, 1);
    expect(await desktop.select(desktop.collections).get(), hasLength(1));
    final buena = await desktop.findCollection('buena');
    expect(buena?.createdAt.toUtc(), _now);
    expect(await members(desktop, 'buena'), {'d'});
  });

  Future<void> mark(AppDatabase db, String id, String bookId, String cfi) =>
      db.addBookmark(
        BookmarksCompanion.insert(
          id: id,
          bookId: bookId,
          cfi: cfi,
          label: const Value('Capítulo 2'),
          createdAt: Value(DateTime.utc(2026, 10, 3)),
        ),
      );

  Future<void> highlight(
    AppDatabase db,
    String id,
    String bookId,
    String cfi,
  ) => db.addHighlight(
    HighlightsCompanion.insert(
      id: id,
      bookId: bookId,
      cfi: cfi,
      content: const Value('Texto subrayado de prueba'),
      color: const Value('pink'),
      note: const Value('releer'),
    ),
  );

  test(
    'series, ocultos, favoritos, marcadores y subrayados viajan por la huella',
    () async {
      await book(phone, 'p1', hash: _hashA, title: 'Serie A 1');
      await book(phone, 'p2', hash: _hashB, title: 'Serie A 2');
      await phone.setSeriesById({'p1': 'Serie A', 'p2': 'Serie A'});
      await phone.setHidden(['p2'], hidden: true);
      await phone.setFavorite('p1', true);
      await mark(phone, 'bm-1', 'p1', 'spine:2#100');
      await highlight(phone, 'hl-1', 'p1', 'spine:2#200-240');
      await book(desktop, 'd1', hash: _hashA, title: 'Serie A 1');
      await book(desktop, 'd2', hash: _hashB, title: 'Serie A 2');
      await desktop.setSeriesById({
        'd1': 'Serie A (parte 1)',
        'd2': 'Serie A (parte 2)',
      });
      await book(
        desktop,
        'd3',
        hash: 'c' * 64,
        title: 'Libro C',
        author: 'Autor C',
      );
      await desktop.setSeriesById({'d3': 'Serie C'});

      final bytes = await transfer(phone).export();
      final report = await transfer(desktop).import(bytes);

      expect(report.applied, 2);
      final d1 = await desktop.findBook('d1');
      final d2 = await desktop.findBook('d2');
      expect(d1?.series, 'Serie A');
      expect(d2?.series, 'Serie A');
      expect(d1?.hidden, isFalse);
      expect(d2?.hidden, isTrue);
      expect(d1?.favoritedAt, isNotNull);
      expect((await desktop.findBook('d3'))?.series, 'Serie C');
      final bookmark = (await desktop.select(desktop.bookmarks).get()).single;
      expect(bookmark.id, 'bm-1');
      expect(bookmark.bookId, 'd1');
      expect(bookmark.cfi, 'spine:2#100');
      expect(bookmark.label, 'Capítulo 2');
      expect(bookmark.createdAt.toUtc(), DateTime.utc(2026, 10, 3));
      final marked = (await desktop.select(desktop.highlights).get()).single;
      expect(marked.id, 'hl-1');
      expect(marked.color, 'pink');
      expect(marked.note, 'releer');
      expect(marked.content, 'Texto subrayado de prueba');

      final again = await transfer(desktop).import(bytes);
      expect(again.applied, 0);
      expect(await desktop.select(desktop.bookmarks).get(), hasLength(1));
      expect(await desktop.select(desktop.highlights).get(), hasLength(1));
    },
  );

  test(
    'sin huella exacta no se tocan series, ocultos ni anotaciones',
    () async {
      await book(phone, 'p', hash: _hashA);
      await phone.setSeriesById({'p': 'Serie del teléfono'});
      await phone.setHidden(['p'], hidden: true);
      await mark(phone, 'bm-1', 'p', 'spine:3#10');
      await highlight(phone, 'hl-1', 'p', 'spine:3#10-20');
      await book(desktop, 'otra-edicion', hash: _hashB);
      await desktop.setSeriesById({'otra-edicion': 'Rayuela'});
      await mark(desktop, 'bm-local', 'otra-edicion', 'spine:1#0');

      await transfer(desktop).import(await transfer(phone).export());

      final row = await desktop.findBook('otra-edicion');
      expect(row?.series, 'Rayuela');
      expect(row?.hidden, isFalse);
      expect(
        (await desktop.select(desktop.bookmarks).get()).single.id,
        'bm-local',
      );
      expect(await desktop.select(desktop.highlights).get(), isEmpty);
    },
  );

  test('las anotaciones dañadas se descartan', () async {
    await book(desktop, 'd', hash: _hashA);
    await mark(desktop, 'ya-existe', 'd', 'spine:1#0');

    await transfer(desktop).import(
      file([
        {
          'hash': _hashA,
          'format': 'epub',
          'series': '',
          'hidden': 'sí',
          'bookmarks': [
            null,
            {'id': '../x', 'cfi': 'spine:1#5'},
            {'id': 'sin-posicion'},
            {'id': 'mala-posicion', 'cfi': 'javascript:alert(1)'},
            {'id': 'ya-existe', 'cfi': 'spine:9#9'},
            {'id': 'misma-posicion', 'cfi': 'spine:1#0'},
            {'id': 'buena', 'cfi': 'spine:2#4', 'percent': 9},
          ],
          'highlights': [
            {'id': 'h', 'cfi': 'spine:2#4-8', 'color': '<b>', 'note': 7},
          ],
        },
      ]),
    );

    final marks = await desktop.select(desktop.bookmarks).get();
    expect(marks.map((b) => b.id).toSet(), {'ya-existe', 'buena'});
    expect(marks.firstWhere((b) => b.id == 'buena').percent, 1.0);
    final marked = (await desktop.select(desktop.highlights).get()).single;
    expect(marked.color, 'yellow');
    expect(marked.note, isNull);
    final row = await desktop.findBook('d');
    expect(row?.series, isNull);
    expect(row?.hidden, isFalse);
  });

  test('un respaldo de una versión futura importa lo que entiende', () async {
    await book(desktop, 'd', hash: _hashA);

    final report = await transfer(desktop).import(
      utf8.encode(
        jsonEncode({
          'kind': progressFileKind,
          'version': 99,
          'nuevoCampo': {'x': 1},
          'books': [
            {
              'hash': _hashA,
              'format': 'epub',
              'extra': true,
              'progress': {
                'percent': 0.25,
                'updatedAt': '2026-10-01T10:00:00.000Z',
              },
            },
          ],
        }),
      ),
    );

    expect(report.applied, 1);
    expect((await desktop.readProgress('d'))?.percent, 0.25);
  });
}
