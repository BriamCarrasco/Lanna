// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class EpubArchive {
  EpubArchive._(this._archive, this.opfPath);

  final Archive _archive;

  final String opfPath;

  String get rootDir => p.dirname(opfPath);

  static EpubArchive open(Uint8List epubBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(epubBytes);
    } catch (_) {
      throw const FormatException('El archivo no es un ZIP/EPUB válido');
    }
    return EpubArchive.fromDecoded(archive);
  }

  static EpubArchive fromDecoded(Archive archive) =>
      EpubArchive._(archive, _findOpfPath(archive));

  bool exists(String path) => _file(path) != null;

  Uint8List? bytes(String path) {
    final f = _file(path);
    return f == null ? null : Uint8List.fromList(f.content as List<int>);
  }

  String? string(String path) {
    final b = bytes(path);
    return b == null ? null : utf8.decode(b, allowMalformed: true);
  }

  XmlDocument xml(String path) {
    final s = string(path);
    if (s == null) throw FormatException('Recurso no encontrado: $path');
    return XmlDocument.parse(s);
  }

  String resolveFromOpf(String href) {
    final decoded = Uri.decodeFull(href.split('#').first);
    return p.normalize(p.join(rootDir, decoded)).replaceAll('\\', '/');
  }

  Iterable<String> get paths =>
      _archive.files.where((f) => f.isFile).map((f) => f.name);

  ArchiveFile? _file(String path) {
    final normalized = path.replaceAll('\\', '/');
    for (final f in _archive.files) {
      if (f.isFile && f.name == normalized) return f;
    }
    for (final f in _archive.files) {
      if (f.isFile && f.name.toLowerCase() == normalized.toLowerCase()) {
        return f;
      }
    }
    return null;
  }

  static String _findOpfPath(Archive archive) {
    ArchiveFile? container;
    for (final f in archive.files) {
      if (f.isFile && f.name == 'META-INF/container.xml') {
        container = f;
        break;
      }
    }
    if (container == null) {
      throw const FormatException('EPUB sin META-INF/container.xml');
    }
    final doc = XmlDocument.parse(
      utf8.decode(container.content as List<int>, allowMalformed: true),
    );
    final rootfile = doc.findAllElements('rootfile').firstOrNull;
    final fullPath = rootfile?.getAttribute('full-path');
    if (fullPath == null || fullPath.isEmpty) {
      throw const FormatException('container.xml sin rootfile válido');
    }
    return fullPath.replaceAll('\\', '/');
  }
}
