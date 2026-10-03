// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/data/comic/image_dimensions.dart';

import '../support/reader_harness.dart';

Uint8List _bytes(List<int> values) =>
    Uint8List.fromList([...values, ...List.filled(32, 0)]);

void main() {
  test('lee el tamaño de un PNG', () {
    expect(imageDimensions(solidPng(30, 12)), (width: 30, height: 12));
  });

  test('lee el tamaño de un JPEG saltando los segmentos previos', () {
    final jpeg = _bytes([
      0xFF, 0xD8, //
      0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, //
      0xFF, 0xC0, 0x00, 0x11, 0x08, 0x03, 0x20, 0x05, 0x00,
    ]);
    expect(imageDimensions(jpeg), (width: 1280, height: 800));
  });

  test('un JPEG progresivo también se mide', () {
    final jpeg = _bytes([
      0xFF, 0xD8, //
      0xFF, 0xC4, 0x00, 0x03, 0x00, //
      0xFF, 0xC2, 0x00, 0x11, 0x08, 0x00, 0x64, 0x00, 0xC8,
    ]);
    expect(imageDimensions(jpeg), (width: 200, height: 100));
  });

  test('lee el tamaño de un GIF', () {
    final gif = _bytes([
      ...'GIF89a'.codeUnits,
      0x40, 0x01, 0xF0, 0x00, //
    ]);
    expect(imageDimensions(gif), (width: 320, height: 240));
  });

  test('lee el tamaño de un WebP extendido', () {
    final webp = _bytes([
      ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, //
      ...'VP8X'.codeUnits, 10, 0, 0, 0, 0, 0, 0, 0,
      0xFF, 0x04, 0x00, 0x1F, 0x03, 0x00,
    ]);
    expect(imageDimensions(webp), (width: 1280, height: 800));
  });

  test('lee el tamaño de un WebP sin pérdida', () {
    const width = 600;
    const height = 900;
    final bits = (width - 1) | ((height - 1) << 14);
    final webp = _bytes([
      ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, //
      ...'VP8L'.codeUnits, 0, 0, 0, 0, 0x2F,
      bits & 0xFF, (bits >> 8) & 0xFF, (bits >> 16) & 0xFF, (bits >> 24) & 0xFF,
    ]);
    expect(imageDimensions(webp), (width: width, height: height));
  });

  test('un archivo que no es imagen no tiene tamaño', () {
    expect(imageDimensions(_bytes('hola mundo'.codeUnits)), isNull);
    expect(imageDimensions(Uint8List(4)), isNull);
  });
}
