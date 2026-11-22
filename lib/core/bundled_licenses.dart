// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bundledLicensesDir = 'assets/licenses/';

void registerBundledLicenses() {
  LicenseRegistry.addLicense(() => bundledLicenses(rootBundle));
}

Stream<LicenseEntry> bundledLicenses(AssetBundle bundle) async* {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths =
      manifest
          .listAssets()
          .where((path) => path.startsWith(bundledLicensesDir))
          .toList()
        ..sort();
  for (final path in paths) {
    final package = path.substring(bundledLicensesDir.length).split('/').first;
    if (package.isEmpty) continue;
    yield LicenseEntryWithLineBreaks([
      package,
    ], await bundle.loadString(path, cache: false));
  }
}
