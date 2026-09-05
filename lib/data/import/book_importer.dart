// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:uuid/uuid.dart';

import '../epub/epub_book.dart';
import '../epub/epub_package.dart';
import '../local/app_database.dart';
import '../models/book_format.dart';

sealed class ImportResult {
  const ImportResult(this.fileName);
  final String fileName;
}

class ImportAdded extends ImportResult {
  const ImportAdded(super.fileName, this.book);
  final Book book;
}

class ImportSkipped extends ImportResult {
  const ImportSkipped(super.fileName, this.reason);
  final String reason;
}

class ImportFailed extends ImportResult {
  const ImportFailed(super.fileName, this.error);
  final Object error;
}

EpubMetadata readEpubMetadata(String path) =>
    EpubPackage.parse(File(path).readAsBytesSync()).metadata;

Future<String> hashFile(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

class BookImporter {
  BookImporter(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  static const _supportedExtensions = {'.epub', '.pdf'};

  Future<ImportResult> importFile(String path) async {
    final fileName = p.basename(path);
    try {
      final source = File(path);
      if (!source.existsSync()) {
        return ImportFailed(fileName, 'El archivo ya no existe');
      }

      final ext = p.extension(path).toLowerCase();
      if (!_supportedExtensions.contains(ext)) {
        return ImportSkipped(fileName, 'Formato no soportado ($ext)');
      }
      final format = ext == '.pdf' ? BookFormat.pdf : BookFormat.epub;

      final hash = await hashFile(path);
      final duplicate = await _db.findBookByHash(hash);
      if (duplicate != null) {
        return ImportSkipped(fileName, 'Ya está en la biblioteca');
      }

      final id = _uuid.v4();
      final dirs = await _ensureDirs();

      String? title;
      String? author;
      String? coverPath;

      if (format == BookFormat.epub) {
        try {
          final meta = await compute(readEpubMetadata, source.path);
          title = meta.title;
          author = meta.author;
          if (meta.coverBytes != null) {
            final coverExt = p.extension(meta.coverFileName ?? 'cover.jpg');
            final dest = File(p.join(dirs.covers, '$id$coverExt'));
            await dest.writeAsBytes(meta.coverBytes!);
            coverPath = dest.path;
          }
        } on FormatException catch (e) {
          return ImportFailed(fileName, 'EPUB inválido: ${e.message}');
        }
      } else if (format == BookFormat.pdf) {
        try {
          coverPath = await _renderPdfCover(source, id, dirs.covers);
        } catch (_) {}
      }

      title ??= p.basenameWithoutExtension(path);

      final storedFile = File(p.join(dirs.books, '$id$ext'));
      await source.copy(storedFile.path);

      final companion = BooksCompanion.insert(
        id: id,
        title: title,
        filePath: storedFile.path,
        format: format,
        author: Value(author),
        coverPath: Value(coverPath),
        fileSizeBytes: Value(await storedFile.length()),
        contentHash: Value(hash),
      );
      await _db.upsertBook(companion);

      final book = await _db.findBook(id);
      return ImportAdded(fileName, book!);
    } catch (e) {
      return ImportFailed(fileName, e);
    }
  }

  Future<String?> _renderPdfCover(File source, String id, String covers) async {
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openFile(source.path);
    try {
      if (document.pages.isEmpty) return null;
      final page = document.pages.first;
      const width = 600.0;
      final rendered = await page.render(
        fullWidth: width,
        fullHeight: width * page.height / page.width,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) return null;
      try {
        final image = await rendered.createImage();
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) return null;
          final dest = File(p.join(covers, '$id.png'));
          await dest.writeAsBytes(png.buffer.asUint8List());
          return dest.path;
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

  Future<({String books, String covers})> _ensureDirs() async {
    final support = await getApplicationSupportDirectory();
    final books = Directory(p.join(support.path, 'library', 'books'));
    final covers = Directory(p.join(support.path, 'library', 'covers'));
    await books.create(recursive: true);
    await covers.create(recursive: true);
    return (books: books.path, covers: covers.path);
  }
}
