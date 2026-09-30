// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/import/fingerprint.dart';
import 'package:lanna/data/local/app_database.dart';
import 'package:lanna/data/models/book_format.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('lanna_dedupe_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  File write(String name, List<int> bytes) =>
      File(p.join(tmp.path, name))..writeAsBytesSync(bytes);

  test('la huella distingue contenidos y coincide para copias', () async {
    final a = write('a.epub', List.generate(2048, (i) => i % 251));
    final b = write('b.epub', List.generate(2048, (i) => i % 251));
    final c = write('c.epub', List.generate(2048, (i) => i % 250));

    final ha = await fingerprintFile(a.path);
    final hb = await fingerprintFile(b.path);
    final hc = await fingerprintFile(c.path);

    expect(ha, hb, reason: 'dos copias iguales dieron huellas distintas');
    expect(ha, isNot(hc));
    expect(ha, hasLength(64));
  });

  test('en archivos grandes mira el tamaño, el inicio y el final', () async {
    const size = fingerprintChunk * 3;
    List<int> bytes({int at = -1, int extra = 0}) => [
      for (var i = 0; i < size + extra; i++) i == at ? 7 : i % 251,
    ];
    final base = fingerprintSync(write('base', bytes()).path);

    expect(fingerprintSync(write('copia', bytes()).path), base);
    expect(fingerprintSync(write('inicio', bytes(at: 10)).path), isNot(base));
    expect(
      fingerprintSync(write('final', bytes(at: size - 10)).path),
      isNot(base),
    );
    expect(fingerprintSync(write('largo', bytes(extra: 1)).path), isNot(base));
  });

  test('la migración recalcula las huellas de la biblioteca', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final file = write('uno.epub', List.generate(4096, (i) => i % 13));
    for (final (id, path) in [
      ('uno', file.path),
      ('perdido', p.join(tmp.path, 'no-existe.epub')),
    ]) {
      await db.upsertBook(
        BooksCompanion.insert(
          id: id,
          title: id,
          filePath: path,
          format: BookFormat.epub,
          contentHash: const Value('sha256-del-archivo-entero'),
        ),
      );
    }

    await db.refreshFingerprints();

    final found = await db.findBookByHash(await fingerprintFile(file.path));
    expect(found?.id, 'uno');
    expect((await db.findBook('perdido'))?.contentHash, isNull);
  });

  test('findBookByHash encuentra el libro ya importado', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.findBookByHash('abc'), isNull);

    await db.upsertBook(
      BooksCompanion.insert(
        id: 'uno',
        title: 'Uno',
        filePath: '/libros/uno.epub',
        format: BookFormat.epub,
        contentHash: const Value('abc'),
      ),
    );

    final found = await db.findBookByHash('abc');
    expect(found?.id, 'uno');
    expect(await db.findBookByHash('otro'), isNull);
  });
}
