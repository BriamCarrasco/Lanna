// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/core/bundled_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'las licencias de pdfium, libarchive y las fuentes van en la app',
    () async {
      final entries = await bundledLicenses(rootBundle).toList();
      final byPackage = <String, int>{};
      for (final entry in entries) {
        for (final package in entry.packages) {
          byPackage[package] = (byPackage[package] ?? 0) + 1;
        }
        expect(entry.paragraphs, isNotEmpty);
      }

      expect(byPackage.keys.toSet(), {
        'pdfium',
        'libarchive',
        'Manrope',
        'Newsreader',
      });
      expect(byPackage['pdfium'], 19);
      final pdfium = entries
          .where((e) => e.packages.contains('pdfium'))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join('\n');
      expect(pdfium, contains('FreeType'));
      final fonts = entries
          .where((e) => e.packages.contains('Manrope'))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join('\n');
      expect(fonts, contains('SIL OPEN FONT LICENSE'));
    },
  );
}
