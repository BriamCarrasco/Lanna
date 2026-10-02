// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../data/epub/epub_book.dart';
import '../../../data/epub/epub_document.dart';
import '../../../data/epub/epub_fonts.dart';
import '../../../data/epub/epub_paths.dart';
import '../../../data/epub/woff.dart';

class NativeBookSource {
  NativeBookSource({required this.root, required this.book});

  final Directory root;
  final EpubBook book;

  late final List<SpineItem> spine = book.spine.where((s) => s.linear).toList();

  final Map<int, EpubDocument> _documents = {};
  final Map<String, Size> _imageSizes = {};
  final Map<int, int> _lengths = {};

  List<int>? _prefix;
  int _total = 0;

  int get chapterCount => spine.length;

  bool get rtl => book.rtl;

  String? _bookFont;
  bool _fontsLoaded = false;

  String? get bookFontFamily => _bookFont;

  bool _fontFormatUnsupported = false;

  bool get bookFontUnsupported => _bookFont == null && _fontFormatUnsupported;

  Future<void> loadFonts() async {
    if (_fontsLoaded) return;
    _fontsLoaded = true;

    final sheets = await _styleSheets();
    if (sheets.isEmpty) return;

    final sheet = EpubFonts.parse(sheets);
    _fontFormatUnsupported = sheet.skippedFormat;
    if (sheet.isEmpty) return;

    final byFamily = <String, List<FontFace>>{};
    for (final face in sheet.faces) {
      byFamily.putIfAbsent(face.family, () => []).add(face);
    }

    var registered = false;
    for (final entry in byFamily.entries) {
      if (await _registerFamily(entry.key, entry.value)) registered = true;
    }
    if (registered) _bookFont = sheet.preferred;
  }

  Future<Map<String, String>> _styleSheets() async {
    final sheets = <String, String>{};
    for (final item in book.manifest) {
      if (!item.mediaType.contains('css') &&
          !item.href.toLowerCase().endsWith('.css')) {
        continue;
      }
      try {
        sheets[item.href] = await fileFor(item.href).readAsString();
      } catch (_) {}
    }
    return sheets;
  }

  Future<bool> _registerFamily(String family, List<FontFace> faces) async {
    final loader = FontLoader(family);
    var added = 0;
    for (final face in faces) {
      final file = fileFor(face.href);
      if (!file.existsSync()) continue;
      loader.addFont(file.readAsBytes().then(_fontData));
      added++;
    }
    if (added == 0) return false;
    try {
      await loader.load();
      return true;
    } catch (_) {
      return false;
    }
  }

  static ByteData _fontData(Uint8List bytes) {
    final sfnt = Woff.toSfnt(bytes) ?? bytes;
    return ByteData.view(sfnt.buffer, sfnt.offsetInBytes, sfnt.lengthInBytes);
  }

  File fileFor(String href) => File(p.join(root.path, href));

  EpubDocument? cached(int chapter) => _documents[chapter];

  bool isCached(int chapter) => _documents.containsKey(chapter);

  void release(int chapter) => _documents.remove(chapter);

  void keepNear(int chapter, {int radius = 2}) {
    _documents.removeWhere((i, _) => (i - chapter).abs() > radius);
  }

  Future<EpubDocument> document(int chapter) async {
    final existing = _documents[chapter];
    if (existing != null) return existing;

    final item = spine[chapter];
    final file = fileFor(item.href);
    final bytes = await file.readAsBytes();
    final parsed = EpubDocumentParser.parseBytes(
      bytes,
      spineIndex: chapter,
      href: item.href,
      rtl: book.rtl,
    );
    _documents[chapter] = parsed;
    _lengths[chapter] = parsed.length;
    await _measureImages(parsed);
    return parsed;
  }

  Size? imageSize(String src) => _imageSizes[src];

  final Map<String, bool> _present = {};

  bool hasFile(String href) =>
      _present.putIfAbsent(href, () => fileFor(href).existsSync());

  Future<void> _measureImages(EpubDocument document) async {
    for (final block in document.blocks) {
      final src = block.src;
      if (src == null || _imageSizes.containsKey(src)) continue;
      if (src.startsWith('data:') || src.startsWith('http')) continue;
      try {
        final bytes = await fileFor(src).readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        _imageSizes[src] = Size(
          descriptor.width.toDouble(),
          descriptor.height.toDouble(),
        );
        descriptor.dispose();
      } catch (_) {}
    }
  }

  void _ensureWeights() {
    if (_prefix != null) return;
    final prefix = <int>[];
    var running = 0;
    for (final item in spine) {
      prefix.add(running);
      var size = 0;
      try {
        size = fileFor(item.href).lengthSync();
      } catch (_) {}
      running += size < 1 ? 1 : size;
    }
    _prefix = prefix;
    _total = running < 1 ? 1 : running;
  }

  int weightBefore(int chapter) {
    _ensureWeights();
    if (chapter <= 0) return 0;
    if (chapter >= _prefix!.length) return _total;
    return _prefix![chapter];
  }

  int weightOf(int chapter) {
    _ensureWeights();
    if (chapter < 0 || chapter >= _prefix!.length) return 1;
    final next = chapter + 1 < _prefix!.length ? _prefix![chapter + 1] : _total;
    final width = next - _prefix![chapter];
    return width < 1 ? 1 : width;
  }

  int get totalWeight {
    _ensureWeights();
    return _total;
  }

  int? chapterForHref(String href) {
    var path = decodeHref(href.split('#').first).replaceAll('\\', '/');
    if (path.isEmpty) return null;
    path = p.url.normalize(path);
    final needle = path.startsWith('/') ? path.substring(1) : path;

    for (var i = 0; i < spine.length; i++) {
      if (spine[i].href == needle) return i;
    }
    if (needle.contains('/')) {
      for (var i = 0; i < spine.length; i++) {
        final h = spine[i].href;
        if (h.endsWith('/$needle') || needle.endsWith('/$h')) return i;
      }
    }
    final name = needle.split('/').last;
    final matches = <int>[
      for (var i = 0; i < spine.length; i++)
        if (spine[i].href.split('/').last == name) i,
    ];
    return matches.length == 1 ? matches.first : null;
  }

  static const _charsPerMinute = 1100;

  int? remainingMinutes(int chapter, int offset) {
    if (_lengths.isEmpty) return null;
    var chars = 0;
    var bytes = 0;
    for (final entry in _lengths.entries) {
      chars += entry.value;
      bytes += weightOf(entry.key);
    }
    if (chars <= 0 || bytes <= 0) return null;
    final perByte = chars / bytes;

    final here = _lengths[chapter];
    final ahead = here == null ? 0 : (here - offset).clamp(0, here);
    final bytesAfter = (totalWeight - weightBefore(chapter) - weightOf(chapter))
        .clamp(0, totalWeight);
    final remaining = ahead + bytesAfter * perByte;
    if (remaining <= 0) return 0;
    final minutes = remaining / _charsPerMinute;
    return minutes < 1 ? 1 : minutes.round();
  }

  double percentageAt(int chapter, int offset, int length) {
    final within = length <= 0 ? 0.0 : (offset / length).clamp(0.0, 1.0);
    final value =
        (weightBefore(chapter) + weightOf(chapter) * within) / totalWeight;
    return value.clamp(0.0, 1.0);
  }

  (int chapter, double within) locate(double percentage) {
    _ensureWeights();
    final target = (percentage.clamp(0.0, 1.0)) * _total;
    for (var i = spine.length - 1; i >= 0; i--) {
      final start = _prefix![i];
      if (target >= start || i == 0) {
        final within = (target - start) / weightOf(i);
        return (i, within.clamp(0.0, 1.0));
      }
    }
    return (0, 0);
  }
}

class ReaderLocator {
  const ReaderLocator({required this.chapter, required this.offset, this.end});

  final int chapter;
  final int offset;
  final int? end;

  static const scheme = 'spine';

  bool get isRange => end != null && end! > offset;

  static ReaderLocator? parse(String? raw) {
    if (raw == null || !raw.startsWith('$scheme:')) return null;
    final body = raw.substring(scheme.length + 1);
    final hash = body.indexOf('#');
    if (hash < 0) {
      final chapter = int.tryParse(body);
      return chapter == null
          ? null
          : ReaderLocator(chapter: chapter, offset: 0);
    }
    final chapter = int.tryParse(body.substring(0, hash));
    if (chapter == null) return null;
    final tail = body.substring(hash + 1);
    final dash = tail.indexOf('-');
    if (dash < 0) {
      final offset = int.tryParse(tail);
      return offset == null
          ? null
          : ReaderLocator(chapter: chapter, offset: offset);
    }
    final start = int.tryParse(tail.substring(0, dash));
    final finish = int.tryParse(tail.substring(dash + 1));
    if (start == null || finish == null) return null;
    return ReaderLocator(chapter: chapter, offset: start, end: finish);
  }

  @override
  String toString() =>
      isRange ? '$scheme:$chapter#$offset-$end' : '$scheme:$chapter#$offset';
}
