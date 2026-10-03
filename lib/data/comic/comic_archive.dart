// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:rar/rar.dart';

import '../storage/random_source.dart';
import 'comic_book.dart';
import 'image_dimensions.dart';
import 'libarchive.dart';

enum ComicContainer { zip, rar, unknown }

ComicContainer sniffComic(String path) {
  final source = FileSource(path);
  try {
    return sniffSource(source);
  } finally {
    source.close();
  }
}

ComicContainer sniffSource(RandomSource source) {
  final head = source.read(0, 7);
  {
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
  ComicArchive._(this.book, this._requests, this._pending, this._exited);

  final ComicBook book;
  final SendPort _requests;
  final Map<int, Completer<Uint8List>> _pending;
  final Completer<void> _exited;
  int _nextId = 0;
  bool _closed = false;

  static const markerName = '.lanna-complete';

  static Future<ComicArchive> open(
    SourceSpec spec, {
    required String cacheDir,
  }) async {
    final probe = openSource(spec);
    final ComicContainer container;
    try {
      container = sniffSource(probe);
    } finally {
      probe.close();
    }
    final (source, directory) = switch (container) {
      ComicContainer.zip => (_Source.zip, null),
      ComicContainer.rar when LibArchive.instance != null => (
        _Source.rar,
        null,
      ),
      ComicContainer.rar when spec.path != null => (
        _Source.directory,
        await _extractWithPlugin(spec.path!, cacheDir),
      ),
      ComicContainer.rar => throw const ComicFormatException(
        'Este dispositivo no puede leer CBR desde una carpeta',
      ),
      ComicContainer.unknown => throw const ComicFormatException(
        'El archivo no es un CBZ ni un CBR válido',
      ),
    };
    if (source != _Source.directory) _discardExtraction(cacheDir);

    final port = ReceivePort();
    final init = Completer<(SendPort, List<String>, String?)>();
    final pending = <int, Completer<Uint8List>>{};
    final exited = Completer<void>();
    port.listen((message) {
      switch (message) {
        case (
          final SendPort requests,
          final List<String> pages,
          final String? info,
        ):
          init.complete((requests, pages, info));
        case (final int id, final TransferableTypedData data):
          pending.remove(id)?.complete(data.materialize().asUint8List());
        case (final int id, final String error):
          pending.remove(id)?.completeError(ComicFormatException(error));
        case (null, final String error):
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
          if (!exited.isCompleted) exited.complete();
      }
    });
    try {
      await Isolate.spawn(
        _worker,
        (port.sendPort, spec, source, directory),
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
        series: meta.series,
        rtl: meta.rtl,
      ),
      requests,
      pending,
      exited,
    );
    if (pages.isEmpty) {
      await archive.close();
      throw const ComicFormatException('El cómic no tiene páginas');
    }
    return archive;
  }

  static const _recentLimit = 12;
  final Map<int, Future<Uint8List>> _recent = {};

  Future<Uint8List> page(int index) {
    if (_closed) {
      return Future.error(const ComicFormatException('El cómic está cerrado'));
    }
    final cached = _recent.remove(index);
    if (cached != null) return _recent[index] = cached;
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    _requests.send((id, index));
    final future = completer.future;
    _recent[index] = future;
    future.then(
      (_) {},
      onError: (_) {
        _recent.remove(index);
      },
    );
    if (_recent.length > _recentLimit) _recent.remove(_recent.keys.first);
    return future;
  }

  Future<ImageDimensions?> pageDimensions(int index) async {
    try {
      return imageDimensions(await page(index));
    } catch (_) {
      return null;
    }
  }

  Future<void> close() {
    if (!_closed) {
      _closed = true;
      _recent.clear();
      _requests.send(null);
    }
    return _exited.future;
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

class _SourceHandle extends AbstractFileHandle {
  _SourceHandle(this._source);

  final RandomSource _source;

  @override
  int position = 0;

  @override
  int get length => _source.length;

  @override
  bool get isOpen => true;

  @override
  int readInto(Uint8List buffer, [int? length]) {
    final view = length == null
        ? buffer
        : Uint8List.sublistView(buffer, 0, length);
    final n = _source.readInto(view, position);
    position += n;
    return n;
  }

  @override
  Future<void> close() async {}

  @override
  void closeSync() {}

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) =>
      throw UnsupportedError('solo lectura');
}

class _ZipReader implements _EntryReader {
  _ZipReader(RandomSource source)
    : _input = InputFileStream.withFileHandle(_SourceHandle(source)) {
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
  _RarReader(RandomSource source) : _reader = RarReader(source);

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

void _worker((SendPort, SourceSpec, _Source, String?) args) {
  final (reply, spec, source, directory) = args;
  final _EntryReader reader;
  final List<int> pages;
  RandomSource? input;
  try {
    if (directory != null) {
      reader = _DirectoryReader(directory);
    } else {
      input = openSource(spec);
      reader = switch (source) {
        _Source.zip => _ZipReader(input),
        _ => _RarReader(input),
      };
    }
  } catch (error) {
    input?.close();
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
  reply.send((inbox.sendPort, [for (final i in pages) reader.names[i]], info));
  inbox.listen((message) {
    if (message case (final int id, final int page)) {
      try {
        final bytes = reader.read(pages[page]);
        reply.send((id, TransferableTypedData.fromList([bytes])));
      } catch (error) {
        reply.send((id, _describe(error)));
      }
      return;
    }
    reader.close();
    input?.close();
    inbox.close();
  });
}
