// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../data/epub/epub_archive.dart';
import '../../data/epub/epub_book.dart';
import '../../data/epub/epub_extractor.dart';
import '../../data/epub/epub_package.dart';
import '../../data/storage/random_source.dart';

typedef PrepareArgs = ({SourceSpec spec, String extractDir});

Future<EpubBook> prepareEpub(PrepareArgs args) async {
  final source = openSource(args.spec);
  final Uint8List bytes;
  try {
    bytes = source.readAll();
  } finally {
    source.close();
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  EpubExtractor.extract(archive, Directory(args.extractDir));
  return EpubPackage.parseArchive(EpubArchive.fromDecoded(archive));
}
