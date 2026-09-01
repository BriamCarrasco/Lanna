// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

abstract final class EpubExtractor {
  static void extract(Archive archive, Directory dest) {
    if (dest.existsSync() && dest.listSync().isNotEmpty) return;
    dest.createSync(recursive: true);
    final root = dest.path;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      final target = p.normalize(p.join(root, name));

      if (!p.isWithin(root, target)) continue;

      final out = File(target);
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(file.content as List<int>);
    }
  }
}
