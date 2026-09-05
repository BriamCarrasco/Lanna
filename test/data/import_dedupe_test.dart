// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/import/book_importer.dart';
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

  test('el hash distingue contenidos y coincide para copias', () async {
    final a = write('a.epub', List.generate(2048, (i) => i % 251));
    final b = write('b.epub', List.generate(2048, (i) => i % 251));
    final c = write('c.epub', List.generate(2048, (i) => i % 250));

    final ha = await hashFile(a.path);
    final hb = await hashFile(b.path);
    final hc = await hashFile(c.path);

    expect(ha, hb, reason: 'dos copias iguales dieron hashes distintos');
    expect(ha, isNot(hc));
    expect(ha, hasLength(64));
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
