// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/epub/woff.dart';

int tag(String s) =>
    (s.codeUnitAt(0) << 24) |
    (s.codeUnitAt(1) << 16) |
    (s.codeUnitAt(2) << 8) |
    s.codeUnitAt(3);

Uint8List buildWoff(Map<String, Uint8List> tables, {bool compress = true}) {
  final entries = tables.entries.toList();
  final headerSize = 44 + entries.length * 20;
  final bodies = <Uint8List>[];
  for (final e in entries) {
    bodies.add(
      compress
          ? Uint8List.fromList(ZLibEncoder().encodeBytes(e.value))
          : e.value,
    );
  }

  var total = headerSize;
  final offsets = <int>[];
  for (final body in bodies) {
    offsets.add(total);
    total += (body.length + 3) & ~3;
  }

  final out = Uint8List(total);
  final view = ByteData.sublistView(out);
  view.setUint32(0, 0x774F4646);
  view.setUint32(4, 0x00010000);
  view.setUint32(8, total);
  view.setUint16(12, entries.length);

  for (var i = 0; i < entries.length; i++) {
    final at = 44 + i * 20;
    final original = entries[i].value;
    final body = bodies[i];
    view.setUint32(at, tag(entries[i].key));
    view.setUint32(at + 4, offsets[i]);
    view.setUint32(
      at + 8,
      body.length >= original.length ? original.length : body.length,
    );
    view.setUint32(at + 12, original.length);
    view.setUint32(at + 16, 0xDEADBEEF);
    final stored = body.length >= original.length ? original : body;
    out.setRange(offsets[i], offsets[i] + stored.length, stored);
  }
  return out;
}

Map<String, Uint8List> readSfnt(Uint8List sfnt) {
  final view = ByteData.sublistView(sfnt);
  final count = view.getUint16(4);
  final tables = <String, Uint8List>{};
  for (var i = 0; i < count; i++) {
    final at = 12 + i * 16;
    final raw = view.getUint32(at);
    final name = String.fromCharCodes([
      (raw >> 24) & 0xFF,
      (raw >> 16) & 0xFF,
      (raw >> 8) & 0xFF,
      raw & 0xFF,
    ]);
    final offset = view.getUint32(at + 8);
    final length = view.getUint32(at + 12);
    tables[name] = Uint8List.sublistView(sfnt, offset, offset + length);
  }
  return tables;
}

void main() {
  final tables = <String, Uint8List>{
    'glyf': Uint8List.fromList(List.generate(500, (i) => i % 251)),
    'cmap': Uint8List.fromList(List.generate(37, (i) => i * 3 % 256)),
    'head': Uint8List.fromList(List.generate(54, (i) => 255 - i)),
  };

  test('un WOFF comprimido vuelve a sfnt con sus tablas intactas', () {
    final sfnt = Woff.toSfnt(buildWoff(tables));

    expect(sfnt, isNotNull);
    final back = readSfnt(sfnt!);
    expect(back.keys.toSet(), tables.keys.toSet());
    for (final entry in tables.entries) {
      expect(back[entry.key], entry.value, reason: 'tabla ${entry.key}');
    }
  });

  test('las tablas sin comprimir pasan tal cual', () {
    final sfnt = Woff.toSfnt(buildWoff(tables, compress: false));

    expect(sfnt, isNotNull);
    final back = readSfnt(sfnt!);
    for (final entry in tables.entries) {
      expect(back[entry.key], entry.value, reason: 'tabla ${entry.key}');
    }
  });

  test('la cabecera sfnt declara el número de tablas', () {
    final sfnt = Woff.toSfnt(buildWoff(tables))!;
    final view = ByteData.sublistView(sfnt);

    expect(view.getUint32(0), 0x00010000);
    expect(view.getUint16(4), 3);
    expect(view.getUint16(6), 32);
    expect(view.getUint16(8), 1);
    expect(view.getUint16(10), 3 * 16 - 32);
  });

  test('las tablas quedan alineadas a 4 bytes', () {
    final sfnt = Woff.toSfnt(buildWoff(tables))!;
    final view = ByteData.sublistView(sfnt);

    for (var i = 0; i < view.getUint16(4); i++) {
      expect(view.getUint32(12 + i * 16 + 8) % 4, 0);
    }
  });

  test('lo que no es WOFF se rechaza sin lanzar', () {
    expect(Woff.toSfnt(Uint8List(10)), isNull);
    expect(Woff.toSfnt(Uint8List.fromList(List.filled(200, 7))), isNull);
    expect(Woff.isWoff(Uint8List.fromList('wOF2'.codeUnits)), isFalse);
  });

  test('un WOFF truncado devuelve null en vez de reventar', () {
    final woff = buildWoff(tables);
    expect(Woff.toSfnt(Uint8List.sublistView(woff, 0, 80)), isNull);
  });
}
