// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bundled_licenses.dart';
import 'perf_probe.dart';

void main() {
  registerBundledLicenses();
  if (perfProbeEnabled) {
    WidgetsFlutterBinding.ensureInitialized();
    startPerfProbe();
  }
  runApp(const ProviderScope(child: LannaApp()));
}
