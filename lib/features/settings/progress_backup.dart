// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book_repository.dart';
import '../../data/transfer/progress_transfer.dart';
import '../../l10n/l10n.dart';

Future<void> exportProgressFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final bytes = await ref.read(bookRepositoryProvider).exportProgress();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final saved = await FilePicker.saveFile(
      dialogTitle: l10n.exportProgressTitle,
      fileName: 'lanna-progreso-$date.json',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (saved == null) return;
    _show(messenger, l10n.progressExported);
  } catch (_) {
    _show(messenger, l10n.exportFailed);
  }
}

Future<void> importProgressFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final repo = ref.read(bookRepositoryProvider);
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: l10n.importProgressTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;
    final report = await repo.importProgress(await file.readAsBytes());
    _show(messenger, describeImport(report, l10n));
  } on ProgressFileException catch (e) {
    _show(messenger, _backupError(e.kind, l10n));
  } catch (_) {
    _show(messenger, l10n.importFailed);
  }
}

String _backupError(ProgressFileError kind, AppLocalizations l10n) =>
    switch (kind) {
      ProgressFileError.tooLarge => l10n.backupTooLarge,
      ProgressFileError.invalid => l10n.backupInvalid,
      ProgressFileError.notLanna => l10n.backupNotLanna,
      ProgressFileError.noBooks => l10n.backupNoBooks,
    };

String describeImport(ProgressImportReport report, AppLocalizations l10n) {
  if (report.total == 0 && report.collections == 0) {
    return l10n.backupNoProgress;
  }

  return [
    if (report.applied > 0)
      l10n.progressImportedIn(report.applied)
    else if (report.collections == 0)
      l10n.noNewProgress,
    if (report.collections > 0) l10n.backupCollections(report.collections),
    if (report.upToDate > 0) l10n.backupUpToDate(report.upToDate),
    if (report.unmatched > 0) l10n.backupUnmatched(report.unmatched),
    if (report.invalid > 0) l10n.backupInvalidEntries(report.invalid),
  ].join(' · ');
}

void _show(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      persist: false,
      duration: const Duration(seconds: 6),
    ),
  );
}
