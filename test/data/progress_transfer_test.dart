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
