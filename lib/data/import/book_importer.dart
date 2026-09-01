// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

      final id = _uuid.v4();
      final dirs = await _ensureDirs();

      String? title;
      String? author;
      String? coverPath;

      if (format == BookFormat.epub) {
        try {
          final meta = EpubPackage.parse(await source.readAsBytes()).metadata;
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
      );
      await _db.upsertBook(companion);

      final book = await _db.findBook(id);
      return ImportAdded(fileName, book!);
    } catch (e) {
      return ImportFailed(fileName, e);
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
