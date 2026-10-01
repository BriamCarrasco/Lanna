// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../storage/random_source.dart';

const fingerprintChunk = 256 * 1024;

String fingerprintSync(String path) {
  final source = FileSource(path);
  try {
    return fingerprintSource(source);
  } finally {
    source.close();
  }
}

String fingerprintSource(RandomSource source) {
  final size = source.length;
  final header = ByteData(8)..setUint64(0, size);
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink)
    ..add(header.buffer.asUint8List());
  if (size <= fingerprintChunk * 2) {
    input.add(source.read(0, size));
  } else {
    input.add(source.read(0, fingerprintChunk));
    input.add(source.read(size - fingerprintChunk, fingerprintChunk));
  }
  input.close();
  return sink.value.toString();
}

Future<String> fingerprintFile(String path) =>
    Isolate.run(() => fingerprintSync(path));

Future<List<String?>> fingerprintFiles(List<String> paths) => Isolate.run(
  () => [
    for (final path in paths)
      if (File(path).existsSync()) fingerprintSync(path) else null,
  ],
);

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
