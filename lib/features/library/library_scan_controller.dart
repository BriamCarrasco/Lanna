// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book_repository.dart';
import '../../data/library/library_scanner.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';

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

  Future<ScanReport?> scanOnStartup() async {
    if (_startedOnce) return null;
    _startedOnce = true;
    final report = await scan();
    await ref.read(bookRepositoryProvider).shrinkCovers();
    return report;
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

  Future<ScanReport?> addFolder({String? dialogTitle}) async {
    final folder = await ref
        .read(bookRepositoryProvider)
        .pickFolder(dialogTitle: dialogTitle);
    if (folder == null) return null;
    return scan();
  }

  Future<void> removeFolder(LibraryFolder folder) =>
      ref.read(bookRepositoryProvider).removeFolder(folder);
}

final libraryScanProvider = NotifierProvider<LibraryScanController, ScanState>(
  LibraryScanController.new,
);

String describeScan(ScanReport report, AppLocalizations l10n) {
  final parts = [
    if (report.added > 0) l10n.scanNewBooks(report.added),
    if (report.relocated > 0) l10n.scanMoved(report.relocated),
    if (report.missing > 0) l10n.scanMissing(report.missing),
    if (report.failed > 0) l10n.scanFailed(report.failed),
    for (final name in report.unreachable) l10n.scanNoAccess(name),
  ];
  return parts.isEmpty ? l10n.libraryUpToDate : parts.join(' · ');
}

Future<void> reportScan(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Future<ScanReport?> work,
) async {
  try {
    final report = await work;
    if (report == null) return;
    messenger.showSnackBar(SnackBar(content: Text(describeScan(report, l10n))));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.scanFolderFailed('$e'))),
    );
  }
}
