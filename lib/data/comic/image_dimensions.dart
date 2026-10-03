// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

typedef ImageDimensions = ({int width, int height});

ImageDimensions? imageDimensions(Uint8List bytes) {
  if (bytes.length < 16) return null;
  final data = ByteData.sublistView(bytes);
  if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) return _png(data);
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return _jpeg(bytes, data);
  if (_startsWith(bytes, const [0x47, 0x49, 0x46])) return _gif(data);
  if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(bytes.sublist(8), const [0x57, 0x45, 0x42, 0x50])) {
    return _webp(bytes, data);
  }
  return null;
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

ImageDimensions? _valid(int width, int height) =>
    width > 0 && height > 0 ? (width: width, height: height) : null;

ImageDimensions? _png(ByteData data) {
  if (data.lengthInBytes < 24) return null;
  return _valid(data.getUint32(16), data.getUint32(20));
}

ImageDimensions? _gif(ByteData data) =>
    _valid(data.getUint16(6, Endian.little), data.getUint16(8, Endian.little));

ImageDimensions? _jpeg(Uint8List bytes, ByteData data) {
  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final length = data.getUint16(i + 2);
    final frame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (frame) return _valid(data.getUint16(i + 7), data.getUint16(i + 5));
    i += 2 + length;
  }
  return null;
}

ImageDimensions? _webp(Uint8List bytes, ByteData data) {
  if (bytes.length < 30) return null;
  final chunk = String.fromCharCodes(bytes.sublist(12, 16));
  switch (chunk) {
    case 'VP8 ':
      return _valid(
        data.getUint16(26, Endian.little) & 0x3FFF,
        data.getUint16(28, Endian.little) & 0x3FFF,
      );
    case 'VP8L':
      final bits = data.getUint32(21, Endian.little);
      return _valid((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8X':
      int read24(int at) =>
          bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16);
      return _valid(read24(24) + 1, read24(27) + 1);
  }
  return null;
}
