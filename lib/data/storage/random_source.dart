// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef SourceSpec = ({String? path, int? fd});

SourceSpec pathSpec(String path) => (path: path, fd: null);

abstract interface class RandomSource {
  int get length;

  int readInto(Uint8List dest, int offset);

  void close();
}

extension RandomSourceRead on RandomSource {
  Uint8List read(int offset, int count) {
    final out = Uint8List(count);
    var filled = 0;
    while (filled < count) {
      final n = readInto(Uint8List.sublistView(out, filled), offset + filled);
      if (n <= 0) break;
      filled += n;
    }
    return filled == count ? out : Uint8List.sublistView(out, 0, filled);
  }

  Uint8List readAll() => read(0, length);
}

RandomSource openSource(SourceSpec spec) {
  if (spec.fd case final fd?) return FdSource(fd);
  return FileSource(spec.path!);
}

class FileSource implements RandomSource {
  FileSource(String path) : _file = File(path).openSync() {
    length = _file.lengthSync();
  }

  final RandomAccessFile _file;

  @override
  late final int length;

  @override
  int readInto(Uint8List dest, int offset) {
    _file.setPositionSync(offset);
    var filled = 0;
    while (filled < dest.length) {
      final n = _file.readIntoSync(dest, filled);
      if (n <= 0) break;
      filled += n;
    }
    return filled;
  }

  @override
  void close() => _file.closeSync();
}

class FdSource implements RandomSource {
  FdSource(this.fd) : length = _Libc.instance.lseek(fd, 0, 2) {
    if (length < 0) {
      throw const FileSystemException('No se pudo leer el archivo');
    }
  }

  final int fd;

  @override
  final int length;

  static const _scratchSize = 1 << 18;
  Pointer<Uint8> _scratch = nullptr;

  @override
  int readInto(Uint8List dest, int offset) {
    if (_scratch == nullptr) _scratch = malloc<Uint8>(_scratchSize);
    var filled = 0;
    while (filled < dest.length) {
      final want = math.min(dest.length - filled, _scratchSize);
      final n = _Libc.instance.pread(fd, _scratch, want, offset + filled);
      if (n < 0) {
        throw const FileSystemException('Error de lectura en el archivo');
      }
      if (n == 0) break;
      dest.setRange(filled, filled + n, _scratch.asTypedList(n));
      filled += n;
    }
    return filled;
  }

  @override
  void close() {
    if (_scratch != nullptr) {
      malloc.free(_scratch);
      _scratch = nullptr;
    }
  }

  static void release(int fd) => _Libc.instance.close(fd);
}

final class _Libc {
  _Libc(DynamicLibrary lib)
    : pread = lib
          .lookupFunction<
            IntPtr Function(Int32, Pointer<Uint8>, Size, Int64),
            int Function(int, Pointer<Uint8>, int, int)
          >('pread64'),
      lseek = lib
          .lookupFunction<
            Int64 Function(Int32, Int64, Int32),
            int Function(int, int, int)
          >('lseek64'),
      close = lib.lookupFunction<Int32 Function(Int32), int Function(int)>(
        'close',
      );

  final int Function(int, Pointer<Uint8>, int, int) pread;
  final int Function(int, int, int) lseek;
  final int Function(int) close;

  static final _Libc instance = _Libc(
    DynamicLibrary.open(Platform.isAndroid ? 'libc.so' : 'libc.so.6'),
  );
}
