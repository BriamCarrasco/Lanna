// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const perfProbeEnabled = bool.fromEnvironment('LANNA_PERF');

void startPerfProbe() {
  final builds = <int>[];
  final rasters = <int>[];
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      builds.add(t.buildDuration.inMicroseconds);
      rasters.add(t.rasterDuration.inMicroseconds);
    }
  });
  Timer.periodic(const Duration(seconds: 2), (_) {
    if (builds.isEmpty) return;
    String stats(List<int> xs) {
      final s = [...xs]..sort();
      int q(double f) => s[((s.length - 1) * f).round()];
      return 'p50 ${(q(.5) / 1000).toStringAsFixed(1)} '
          'p90 ${(q(.9) / 1000).toStringAsFixed(1)} '
          'max ${(s.last / 1000).toStringAsFixed(1)}';
    }

    final hz = PlatformDispatcher.instance.displays.first.refreshRate;
    final budget = 1000000 ~/ (hz <= 0 ? 60 : hz);
    var slow = 0;
    for (var i = 0; i < builds.length; i++) {
      if (builds[i] > budget || rasters[i] > budget) slow++;
    }
    debugPrint(
      '[lanna-perf] ${hz.round()} Hz · frames ${builds.length} lentos $slow · '
      'build ${stats(builds)} · raster ${stats(rasters)}',
    );
    builds.clear();
    rasters.clear();
  });
}
