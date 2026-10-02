// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:archive/archive.dart';

abstract final class Woff {
  static const _signature = 0x774F4646;

  static bool isWoff(Uint8List bytes) =>
      bytes.length >= 44 &&
      ByteData.sublistView(bytes).getUint32(0) == _signature;

  static Uint8List? toSfnt(Uint8List woff) {
    if (!isWoff(woff)) return null;
    try {
      return _convert(woff);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _convert(Uint8List woff) {
    final head = ByteData.sublistView(woff);
    final flavor = head.getUint32(4);
    final tables = head.getUint16(12);
    if (tables == 0) throw const FormatException('WOFF sin tablas');

    final entries = <_Entry>[];
    for (var i = 0; i < tables; i++) {
      final at = 44 + i * 20;
      entries.add(
        _Entry(
          tag: head.getUint32(at),
          offset: head.getUint32(at + 4),
          compLength: head.getUint32(at + 8),
          origLength: head.getUint32(at + 12),
          checksum: head.getUint32(at + 16),
        ),
      );
    }
    entries.sort((a, b) => a.tag.compareTo(b.tag));

    var cursor = 12 + entries.length * 16;
    final bodies = <Uint8List>[];
    for (final entry in entries) {
      final raw = Uint8List.sublistView(
        woff,
        entry.offset,
        entry.offset + entry.compLength,
      );
      final body = entry.compLength < entry.origLength
          ? Uint8List.fromList(const ZLibDecoder().decodeBytes(raw))
          : raw;
      if (body.length != entry.origLength) {
        throw const FormatException('tabla WOFF con longitud inesperada');
      }
      bodies.add(body);
      entry.sfntOffset = cursor;
      cursor += (body.length + 3) & ~3;
    }

    final out = Uint8List(cursor);
    final view = ByteData.sublistView(out);
    final searchRange = _highestPowerOfTwo(entries.length) * 16;

    view.setUint32(0, flavor);
    view.setUint16(4, entries.length);
    view.setUint16(6, searchRange);
    view.setUint16(8, _log2(entries.length));
    view.setUint16(10, entries.length * 16 - searchRange);

    for (var i = 0; i < entries.length; i++) {
      final at = 12 + i * 16;
      view.setUint32(at, entries[i].tag);
      view.setUint32(at + 4, entries[i].checksum);
      view.setUint32(at + 8, entries[i].sfntOffset);
      view.setUint32(at + 12, entries[i].origLength);
      out.setRange(
        entries[i].sfntOffset,
        entries[i].sfntOffset + bodies[i].length,
        bodies[i],
      );
    }
    return out;
  }

  static int _highestPowerOfTwo(int n) {
    var value = 1;
    while (value * 2 <= n) {
      value *= 2;
    }
    return value;
  }

  static int _log2(int n) {
    var bits = 0;
    var value = 1;
    while (value * 2 <= n) {
      value *= 2;
      bits++;
    }
    return bits;
  }
}

class _Entry {
  _Entry({
    required this.tag,
    required this.offset,
    required this.compLength,
    required this.origLength,
    required this.checksum,
  });

  final int tag;
  final int offset;
  final int compLength;
  final int origLength;
  final int checksum;
  int sfntOffset = 0;
}
