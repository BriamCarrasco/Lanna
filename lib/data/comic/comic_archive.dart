// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:rar/rar.dart';

import 'comic_book.dart';
import 'libarchive.dart';

enum ComicContainer { zip, rar, unknown }

ComicContainer sniffComic(String path) {
  final raf = File(path).openSync();
  try {
    final head = raf.readSync(7);
    if (head.length >= 4 && head[0] == 0x50 && head[1] == 0x4B) {
      return ComicContainer.zip;
    }
    if (head.length >= 7 &&
        head[0] == 0x52 &&
        head[1] == 0x61 &&
        head[2] == 0x72 &&
        head[3] == 0x21 &&
        head[4] == 0x1A &&
        head[5] == 0x07) {
      return ComicContainer.rar;
    }
    return ComicContainer.unknown;
  } finally {
    raf.closeSync();
  }
}

class ComicFormatException implements Exception {
  const ComicFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

({List<int> pages, int? info}) selectComicEntries(List<String> names) {
  final normalized = [for (final n in names) n.replaceAll('\\', '/')];
  final pages = <int>[];
  int? info;
  for (var i = 0; i < normalized.length; i++) {
    final name = normalized[i];
    if (name.isEmpty || name.endsWith('/')) continue;
    final parts = name.split('/');
    if (parts.any((s) => s != '.' && s.startsWith('.') || s == '__MACOSX')) {
      continue;
    }
    final lower = name.toLowerCase();
    if (p.posix.basename(lower) == 'comicinfo.xml') {
      info ??= i;
      continue;
    }
    if (comicImageExtensions.contains(p.posix.extension(lower))) pages.add(i);
  }
  pages.sort((a, b) => compareNatural(normalized[a], normalized[b]));
  return (pages: pages, info: info);
}

enum _Source { zip, rar, directory }

class ComicArchive {
  ComicArchive._(this.book, this._requests, this._pending);

  final ComicBook book;
  final SendPort _requests;
  final Map<int, Completer<Uint8List>> _pending;
  int _nextId = 0;
  bool _closed = false;

  static const markerName = '.lanna-complete';

  static Future<ComicArchive> open(String path, {required String cacheDir}) async {
    final (source, target) = switch (sniffComic(path)) {
      ComicContainer.zip => (_Source.zip, path),
      ComicContainer.rar when LibArchive.instance != null => (_Source.rar, path),
      ComicContainer.rar => (
        _Source.directory,
        await _extractWithPlugin(path, cacheDir),
      ),
      ComicContainer.unknown => throw const ComicFormatException(
        'El archivo no es un CBZ ni un CBR válido',
      ),
    };
    if (source != _Source.directory) _discardExtraction(cacheDir);

    final port = ReceivePort();
    final init = Completer<(SendPort, List<String>, String?)>();
    final pending = <int, Completer<Uint8List>>{};
    port.listen((message) {
      switch (message) {
        case (SendPort requests, List<String> pages, String? info):
          init.complete((requests, pages, info));
        case (int id, TransferableTypedData data):
          pending.remove(id)?.complete(data.materialize().asUint8List());
        case (int id, String error):
          pending.remove(id)?.completeError(ComicFormatException(error));
        case (null, String error):
          if (!init.isCompleted) {
            init.completeError(ComicFormatException(error));
          }
        default:
          const stopped = ComicFormatException('El lector de cómics se detuvo');
          if (!init.isCompleted) init.completeError(stopped);
          for (final completer in pending.values) {
            completer.completeError(stopped);
          }
          pending.clear();
          port.close();
      }
    });
    try {
      await Isolate.spawn(
        _worker,
        (port.sendPort, target, source),
        onExit: port.sendPort,
        onError: port.sendPort,
      );
    } catch (_) {
      port.close();
      rethrow;
    }

    final (requests, pages, info) = await init.future;
    final meta = info == null ? const ComicInfo() : ComicInfo.parse(info);
    final archive = ComicArchive._(
      ComicBook(
        pages: pages,
        title: meta.title,
        writer: meta.writer,
        rtl: meta.rtl,
      ),
      requests,
      pending,
    );
    if (pages.isEmpty) {
      await archive.close();
      throw const ComicFormatException('El cómic no tiene páginas');
    }
    return archive;
  }

  Future<Uint8List> page(int index) {
    if (_closed) {
      return Future.error(const ComicFormatException('El cómic está cerrado'));
    }
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    _requests.send((id, index));
    return completer.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _requests.send(null);
  }

  static void _discardExtraction(String dir) {
    final stale = Directory(dir);
    if (stale.existsSync()) {
      unawaited(stale.delete(recursive: true).then((_) {}, onError: (_) {}));
    }
  }

  static Future<String> _extractWithPlugin(String path, String dir) async {
    final dest = Directory(dir);
    final marker = File(p.join(dir, markerName));
    if (marker.existsSync()) return dir;
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    dest.createSync(recursive: true);
    final result = await Rar.extractRarFile(
      rarFilePath: path,
      destinationPath: dir,
    );
    if (result['success'] != true) {
      throw ComicFormatException(
        'No se pudo extraer el CBR: ${result['message'] ?? ''}'.trim(),
      );
    }
    marker.writeAsStringSync('');
    return dir;
  }
}

abstract interface class _EntryReader {
  List<String> get names;
  Uint8List read(int index);
  void close();
}

class _ZipReader implements _EntryReader {
  _ZipReader(String path) : _input = InputFileStream(path) {
    try {
      _files = ZipDecoder().decodeStream(_input).files;
    } catch (_) {
      _input.closeSync();
      throw const ComicFormatException('El CBZ está dañado');
    }
    names = [for (final f in _files) f.isFile ? f.name : ''];
  }

  final InputFileStream _input;
  late final List<ArchiveFile> _files;

  @override
  late final List<String> names;

  @override
  Uint8List read(int index) =>
      _files[index].rawContent?.getStream().toUint8List() ?? Uint8List(0);

  @override
  void close() => _input.closeSync();
}

class _RarReader implements _EntryReader {
  _RarReader(String path) : _reader = RarReader(path);

  final RarReader _reader;

  @override
  List<String> get names => _reader.names;

  @override
  Uint8List read(int index) => _reader.read(index);

  @override
  void close() => _reader.close();
}

class _DirectoryReader implements _EntryReader {
  _DirectoryReader(this.root)
    : names = [
        for (final entity in Directory(
          root,
        ).listSync(recursive: true, followLinks: false))
          if (entity is File) p.relative(entity.path, from: root),
      ];

  final String root;

  @override
  final List<String> names;

  @override
  Uint8List read(int index) =>
      File(p.join(root, names[index])).readAsBytesSync();

  @override
  void close() {}
}

String _describe(Object error) => switch (error) {
  ComicFormatException(:final message) => message,
  LibArchiveException(:final message) => 'No se pudo leer el CBR: $message',
  _ => '$error',
};

void _worker((SendPort, String, _Source) args) {
  final (reply, target, source) = args;
  final _EntryReader reader;
  final List<int> pages;
  try {
    reader = switch (source) {
      _Source.zip => _ZipReader(target),
      _Source.rar => _RarReader(target),
      _Source.directory => _DirectoryReader(target),
    };
  } catch (error) {
    reply.send((null, _describe(error)));
    return;
  }
  final selection = selectComicEntries(reader.names);
  pages = selection.pages;
  String? info;
  if (selection.info case final index?) {
    try {
      info = utf8.decode(reader.read(index), allowMalformed: true);
    } catch (_) {}
  }

  final inbox = ReceivePort();
  reply.send((
    inbox.sendPort,
    [for (final i in pages) reader.names[i]],
    info,
  ));
  inbox.listen((message) {
    if (message case (int id, int page)) {
      try {
        final bytes = reader.read(pages[page]);
        reply.send((id, TransferableTypedData.fromList([bytes])));
      } catch (error) {
        reply.send((id, _describe(error)));
      }
      return;
    }
    reader.close();
    inbox.close();
  });
}
