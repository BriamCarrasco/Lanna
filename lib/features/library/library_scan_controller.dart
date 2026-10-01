// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book_repository.dart';
import '../../data/library/library_scanner.dart';
import '../../data/local/app_database.dart';

class ScanState {
  const ScanState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.report,
  });

  final bool running;
  final int done;
  final int total;
  final ScanReport? report;
}

class LibraryScanController extends Notifier<ScanState> {
  bool _startedOnce = false;

  @override
  ScanState build() => const ScanState();

  Future<ScanReport?> scanOnStartup() {
    if (_startedOnce) return Future.value();
    _startedOnce = true;
    return scan();
  }

  Future<ScanReport?> scan() async {
    if (state.running) return null;
    _startedOnce = true;
    state = const ScanState(running: true);
    try {
      final report = await ref
          .read(bookRepositoryProvider)
          .scan(
            onProgress: (done, total) =>
                state = ScanState(running: true, done: done, total: total),
          );
      state = ScanState(report: report);
      return report;
    } catch (_) {
      state = const ScanState();
      rethrow;
    }
  }

  Future<ScanReport?> addFolder() async {
    final folder = await ref.read(bookRepositoryProvider).pickFolder();
    if (folder == null) return null;
    return scan();
  }

  Future<void> removeFolder(LibraryFolder folder) =>
      ref.read(bookRepositoryProvider).removeFolder(folder);
}

final libraryScanProvider = NotifierProvider<LibraryScanController, ScanState>(
  LibraryScanController.new,
);

String describeScan(ScanReport report) {
  final parts = [
    if (report.added > 0)
      '${report.added} ${report.added == 1 ? 'libro nuevo' : 'libros nuevos'}',
    if (report.relocated > 0)
      '${report.relocated} ${report.relocated == 1 ? 'movido' : 'movidos'}',
    if (report.missing > 0)
      '${report.missing} ${report.missing == 1 ? 'no encontrado' : 'no encontrados'}',
    if (report.failed > 0)
      '${report.failed} ${report.failed == 1 ? 'no se pudo leer' : 'no se pudieron leer'}',
    for (final name in report.unreachable) 'sin acceso a «$name»',
  ];
  return parts.isEmpty ? 'La biblioteca está al día' : parts.join(' · ');
}
