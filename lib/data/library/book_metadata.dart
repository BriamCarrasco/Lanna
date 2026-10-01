// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../comic/comic_archive.dart';
import '../epub/epub_book.dart';
import '../epub/epub_package.dart';
import '../models/book_format.dart';
import '../storage/random_source.dart';

const coverWidth = 450;

BookFormat? formatForName(String name) =>
    switch (p.extension(name).toLowerCase()) {
      '.epub' => BookFormat.epub,
      '.pdf' => BookFormat.pdf,
      '.cbz' || '.cbr' => BookFormat.comic,
      _ => null,
    };

Future<PdfDocument> openPdfDocument(
  SourceSpec spec, {
  PdfPasswordProvider? passwordProvider,
}) async {
  await pdfrxFlutterInitialize();
  if (spec.path case final path?) {
    return PdfDocument.openFile(path, passwordProvider: passwordProvider);
  }
  final source = openSource(spec);
  try {
    return await PdfDocument.openCustom(
      read: (buffer, position, size) =>
          source.readInto(Uint8List.sublistView(buffer, 0, size), position),
      fileSize: source.length,
      sourceName: 'fd:${spec.fd}',
      passwordProvider: passwordProvider,
      onDispose: source.close,
    );
  } catch (_) {
    source.close();
    rethrow;
  }
}

EpubMetadata _readEpubMetadata(SourceSpec spec) {
  final source = openSource(spec);
  try {
    return EpubPackage.parse(source.readAll()).metadata;
  } finally {
    source.close();
  }
}

class BookMeta {
  const BookMeta({this.title, this.author, this.series, this.coverPath});

  final String? title;
  final String? author;
  final String? series;
  final String? coverPath;
}

Future<BookMeta> readBookMeta({
  required SourceSpec spec,
  required BookFormat format,
  required String id,
  required String coversDir,
  required String cacheDir,
}) async {
  switch (format) {
    case BookFormat.epub:
      final meta = await compute(_readEpubMetadata, spec);
      String? coverPath;
      if (meta.coverBytes case final bytes?) {
        try {
          coverPath = await _renderImageCover(bytes, id, coversDir);
        } catch (_) {
          final ext = p.extension(meta.coverFileName ?? 'cover.jpg');
          final dest = File(p.join(coversDir, '$id$ext'));
          await dest.writeAsBytes(bytes);
          coverPath = dest.path;
        }
      }
      return BookMeta(
        title: meta.title,
        author: meta.author,
        coverPath: coverPath,
      );
    case BookFormat.pdf:
      String? coverPath;
      try {
        coverPath = await _renderPdfCover(spec, id, coversDir);
      } catch (_) {}
      return BookMeta(coverPath: coverPath);
    case BookFormat.comic:
      final comic = await ComicArchive.open(
        spec,
        cacheDir: p.join(cacheDir, 'reader', id),
      );
      try {
        String? coverPath;
        try {
          coverPath = await _renderImageCover(
            await comic.page(0),
            id,
            coversDir,
          );
        } catch (_) {}
        return BookMeta(
          title: comic.book.title,
          author: comic.book.writer,
          series: comic.book.series,
          coverPath: coverPath,
        );
      } finally {
        await comic.close();
      }
  }
}

Future<String?> _renderPdfCover(
  SourceSpec spec,
  String id,
  String covers,
) async {
  final document = await openPdfDocument(spec);
  try {
    if (document.pages.isEmpty) return null;
    final page = document.pages.first;
    const width = coverWidth * 1.0;
    final rendered = await page.render(
      fullWidth: width,
      fullHeight: width * page.height / page.width,
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) return null;
    try {
      final image = await rendered.createImage();
      try {
        return await _writePng(image, id, covers);
      } finally {
        image.dispose();
      }
    } finally {
      rendered.dispose();
    }
  } finally {
    await document.dispose();
  }
}

Future<String?> _renderImageCover(
  Uint8List image,
  String id,
  String covers, {
  String suffix = '',
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(image);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.min(descriptor.width, coverWidth),
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        return await _writePng(frame.image, '$id$suffix', covers);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

Future<String?> shrinkCover(String path, String id, String covers) async {
  final bytes = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final width = descriptor.width;
  descriptor.dispose();
  buffer.dispose();
  if (width <= coverWidth + coverWidth ~/ 10) return null;
  return _renderImageCover(bytes, id, covers, suffix: '-$coverWidth');
}

Future<String?> _writePng(ui.Image image, String id, String covers) async {
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) return null;
  final dest = File(p.join(covers, '$id.png'));
  await dest.writeAsBytes(png.buffer.asUint8List());
  return dest.path;
}
