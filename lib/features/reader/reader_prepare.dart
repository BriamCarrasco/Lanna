// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:archive/archive.dart';

import '../../data/epub/epub_archive.dart';
import '../../data/epub/epub_book.dart';
import '../../data/epub/epub_extractor.dart';
import '../../data/epub/epub_package.dart';

typedef PrepareArgs = ({String path, String extractDir});

Future<EpubBook> prepareEpub(PrepareArgs args) async {
  final archive = ZipDecoder().decodeBytes(File(args.path).readAsBytesSync());
  EpubExtractor.extract(archive, Directory(args.extractDir));
  return EpubPackage.parseArchive(EpubArchive.fromDecoded(archive));
}
