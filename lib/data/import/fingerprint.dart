// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const fingerprintChunk = 256 * 1024;

String fingerprintSync(String path) {
  final raf = File(path).openSync();
  try {
    final size = raf.lengthSync();
    final header = ByteData(8)..setUint64(0, size);
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink)
      ..add(header.buffer.asUint8List());
    if (size <= fingerprintChunk * 2) {
      input.add(raf.readSync(size));
    } else {
      input.add(raf.readSync(fingerprintChunk));
      raf.setPositionSync(size - fingerprintChunk);
      input.add(raf.readSync(fingerprintChunk));
    }
    input.close();
    return sink.value.toString();
  } finally {
    raf.closeSync();
  }
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
