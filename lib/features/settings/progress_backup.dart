// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book_repository.dart';
import '../../data/transfer/progress_transfer.dart';

Future<void> exportProgressFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await ref.read(bookRepositoryProvider).exportProgress();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Exportar progreso de lectura',
      fileName: 'lanna-progreso-$date.json',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (saved == null) return;
    _show(messenger, 'Progreso de lectura exportado');
  } catch (_) {
    _show(messenger, 'No se pudo exportar el progreso. Inténtalo de nuevo.');
  }
}

Future<void> importProgressFile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(bookRepositoryProvider);
  try {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Importar progreso de lectura',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;
    final report = await repo.importProgress(await file.readAsBytes());
    _show(messenger, describeImport(report));
  } on ProgressFileException catch (e) {
    _show(messenger, e.message);
  } catch (_) {
    _show(messenger, 'No se pudo importar el progreso. Inténtalo de nuevo.');
  }
}

String describeImport(ProgressImportReport report) {
  if (report.total == 0) return 'El respaldo no tiene progreso para importar';
  String books(int n) => n == 1 ? '1 libro' : '$n libros';
  return [
    report.applied == 0
        ? 'No había progreso nuevo que importar'
        : 'Progreso importado en ${books(report.applied)}',
    if (report.upToDate > 0) '${books(report.upToDate)} ya al día',
    if (report.unmatched > 0)
      '${books(report.unmatched)} no ${report.unmatched == 1 ? 'está' : 'están'} '
          'en esta biblioteca',
    if (report.invalid > 0)
      '${report.invalid} ${report.invalid == 1 ? 'entrada no válida' : 'entradas no válidas'}',
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
