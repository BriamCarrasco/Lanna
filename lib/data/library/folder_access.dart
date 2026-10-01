// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../storage/random_source.dart';

class FolderEntry {
  const FolderEntry({
    required this.location,
    required this.relativePath,
    this.size,
    this.modified,
  });

  final String location;
  final String relativePath;
  final int? size;
  final int? modified;
}

class OpenedFile {
  OpenedFile(this.spec, [this._release]);

  final SourceSpec spec;
  final void Function()? _release;
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    _release?.call();
  }
}

abstract class FolderAccess {
  Future<({String location, String name})?> pick();

  Future<List<FolderEntry>> list(String location);

  Future<void> release(String location);

  Future<OpenedFile> open(String location);
}

class DirectoryFolderAccess implements FolderAccess {
  const DirectoryFolderAccess();

  @override
  Future<({String location, String name})?> pick() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Elegir carpeta de libros',
    );
    if (path == null) return null;
    return (location: path, name: p.basename(path));
  }

  @override
  Future<List<FolderEntry>> list(String location) async {
    final root = Directory(location);
    if (!root.existsSync()) {
      throw FileSystemException('La carpeta ya no existe', location);
    }
    final entries = <FolderEntry>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = entity.statSync();
      entries.add(
        FolderEntry(
          location: entity.path,
          relativePath: p
              .relative(entity.path, from: location)
              .replaceAll('\\', '/'),
          size: stat.size,
          modified: stat.modified.millisecondsSinceEpoch,
        ),
      );
    }
    return entries;
  }

  @override
  Future<void> release(String location) async {}

  @override
  Future<OpenedFile> open(String location) async {
    if (!File(location).existsSync()) {
      throw FileSystemException('El archivo ya no existe', location);
    }
    return OpenedFile(pathSpec(location));
  }
}

class SafFolderAccess implements FolderAccess {
  const SafFolderAccess();

  static const _channel = MethodChannel('lanna/saf');

  @override
  Future<({String location, String name})?> pick() async {
    final picked = await _channel.invokeMapMethod<String, String>('pickTree');
    if (picked == null) return null;
    return (location: picked['uri']!, name: picked['name']!);
  }

  @override
  Future<List<FolderEntry>> list(String location) async {
    final rows = await _channel.invokeListMethod<Map>('listTree', location);
    return [
      for (final row in rows ?? const <Map>[])
        FolderEntry(
          location: row['uri'] as String,
          relativePath: row['path'] as String,
          size: row['size'] as int?,
          modified: row['modified'] as int?,
        ),
    ];
  }

  @override
  Future<void> release(String location) =>
      _channel.invokeMethod('releaseTree', location);

  @override
  Future<OpenedFile> open(String location) async {
    if (!location.startsWith('content://')) {
      return const DirectoryFolderAccess().open(location);
    }
    final fd = await _channel.invokeMethod<int>('openFd', location);
    if (fd == null) {
      throw FileSystemException('No se pudo abrir el archivo', location);
    }
    return OpenedFile((path: null, fd: fd), () => FdSource.release(fd));
  }
}

final folderAccessProvider = Provider<FolderAccess>(
  (ref) => Platform.isAndroid
      ? const SafFolderAccess()
      : const DirectoryFolderAccess(),
);
