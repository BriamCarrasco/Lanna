// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _NewC = Pointer<Void> Function();
typedef _ArchiveC = Int32 Function(Pointer<Void>);
typedef _ArchiveDart = int Function(Pointer<Void>);
typedef _OpenC = Int32 Function(Pointer<Void>, Pointer<Void>, Size);
typedef _OpenDart = int Function(Pointer<Void>, Pointer<Void>, int);
typedef _NextHeaderC = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _NextHeaderDart = int Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _EntryStringC = Pointer<Void> Function(Pointer<Void>);
typedef _EntrySizeC = Int64 Function(Pointer<Void>);
typedef _EntrySizeDart = int Function(Pointer<Void>);
typedef _ReadDataC = IntPtr Function(Pointer<Void>, Pointer<Uint8>, Size);
typedef _ReadDataDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _ErrorC = Pointer<Utf8> Function(Pointer<Void>);

const _ok = 0;
const _eof = 1;
const _warn = -20;

final class LibArchive {
  LibArchive._(DynamicLibrary lib)
    : _new = lib.lookupFunction<_NewC, _NewC>('archive_read_new'),
      _supportRar = lib.lookupFunction<_ArchiveC, _ArchiveDart>(
        'archive_read_support_format_rar',
      ),
      _supportRar5 = lib.lookupFunction<_ArchiveC, _ArchiveDart>(
        'archive_read_support_format_rar5',
      ),
      _open = lib.lookupFunction<_OpenC, _OpenDart>(
        Platform.isWindows
            ? 'archive_read_open_filename_w'
            : 'archive_read_open_filename',
      ),
      _nextHeader = lib.lookupFunction<_NextHeaderC, _NextHeaderDart>(
        'archive_read_next_header',
      ),
      _pathnameW = Platform.isWindows
          ? lib.lookupFunction<_EntryStringC, _EntryStringC>(
              'archive_entry_pathname_w',
            )
          : null,
      _pathnameUtf8 = lib.lookupFunction<_EntryStringC, _EntryStringC>(
        'archive_entry_pathname_utf8',
      ),
      _entrySize = lib.lookupFunction<_EntrySizeC, _EntrySizeDart>(
        'archive_entry_size',
      ),
      _readData = lib.lookupFunction<_ReadDataC, _ReadDataDart>(
        'archive_read_data',
      ),
      _free = lib.lookupFunction<_ArchiveC, _ArchiveDart>('archive_read_free'),
      _error = lib.lookupFunction<_ErrorC, _ErrorC>('archive_error_string');

  final Pointer<Void> Function() _new;
  final _ArchiveDart _supportRar;
  final _ArchiveDart _supportRar5;
  final _OpenDart _open;
  final _NextHeaderDart _nextHeader;
  final Pointer<Void> Function(Pointer<Void>)? _pathnameW;
  final Pointer<Void> Function(Pointer<Void>) _pathnameUtf8;
  final _EntrySizeDart _entrySize;
  final _ReadDataDart _readData;
  final _ArchiveDart _free;
  final Pointer<Utf8> Function(Pointer<Void>) _error;

  static final LibArchive? instance = _load();

  static LibArchive? _load() {
    final name = Platform.isWindows
        ? 'archiveint.dll'
        : Platform.isMacOS
        ? '/usr/lib/libarchive.2.dylib'
        : Platform.isLinux
        ? 'libarchive.so.13'
        : Platform.isAndroid
        ? 'librar_native.so'
        : null;
    if (name == null) return null;
    try {
      return LibArchive._(DynamicLibrary.open(name));
    } catch (_) {
      return null;
    }
  }
}

class LibArchiveException implements Exception {
  const LibArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RarReader {
  RarReader(this.path, [LibArchive? api])
    : _api = api ?? LibArchive.instance! {
    try {
      _reopen();
      final names = <String>[];
      while (_advance()) {
        names.add(_entryName());
      }
      this.names = names;
    } catch (_) {
      close();
      rethrow;
    }
  }

  final String path;
  final LibArchive _api;
  late final List<String> names;

  Pointer<Void> _archive = nullptr;
  final Pointer<Pointer<Void>> _entry = calloc<Pointer<Void>>();
  int _position = -1;
  bool _atEnd = false;

  void _reopen() {
    _release();
    final archive = _api._new();
    if (archive == nullptr) {
      throw const LibArchiveException('libarchive no pudo reservar memoria');
    }
    _archive = archive;
    _api._supportRar(archive);
    _api._supportRar5(archive);
    final native = Platform.isWindows
        ? path.toNativeUtf16().cast<Void>()
        : path.toNativeUtf8().cast<Void>();
    try {
      final result = _api._open(archive, native, 1 << 16);
      if (result != _ok && result != _warn) throw _failure();
    } finally {
      calloc.free(native);
    }
    _position = -1;
    _atEnd = false;
  }

  bool _advance() {
    if (_atEnd) return false;
    final result = _api._nextHeader(_archive, _entry);
    if (result == _eof) {
      _atEnd = true;
      return false;
    }
    if (result != _ok && result != _warn) throw _failure();
    _position++;
    return true;
  }

  String _entryName() {
    final entry = _entry.value;
    final wide = _api._pathnameW?.call(entry) ?? nullptr;
    if (wide != nullptr) return wide.cast<Utf16>().toDartString();
    final utf8 = _api._pathnameUtf8(entry);
    if (utf8 != nullptr) return utf8.cast<Utf8>().toDartString();
    return '';
  }

  Uint8List read(int index) {
    if (index < 0 || index >= names.length) {
      throw RangeError.index(index, names, 'index');
    }
    if (index <= _position || _atEnd) _reopen();
    while (_position < index) {
      if (!_advance()) {
        throw LibArchiveException('Falta la entrada ${names[index]}');
      }
    }
    final expected = _api._entrySize(_entry.value);
    final out = BytesBuilder(copy: false);
    const chunk = 1 << 18;
    final buffer = malloc<Uint8>(chunk);
    try {
      while (true) {
        final read = _api._readData(_archive, buffer, chunk);
        if (read < 0) throw _failure();
        if (read == 0) break;
        out.add(Uint8List.fromList(buffer.asTypedList(read)));
      }
    } finally {
      malloc.free(buffer);
    }
    final bytes = out.takeBytes();
    if (expected > 0 && bytes.length != expected) {
      throw LibArchiveException('La entrada ${names[index]} está incompleta');
    }
    return bytes;
  }

  LibArchiveException _failure() {
    final message = _api._error(_archive);
    return LibArchiveException(
      message == nullptr ? 'Error de libarchive' : message.toDartString(),
    );
  }

  void _release() {
    if (_archive != nullptr) {
      _api._free(_archive);
      _archive = nullptr;
    }
  }

  void close() {
    _release();
    calloc.free(_entry);
  }
}
