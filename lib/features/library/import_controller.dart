// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/book_repository.dart';
import '../../data/import/book_importer.dart';

enum ImportItemStatus { queued, processing, added, skipped, failed }

class ImportItem {
  const ImportItem({required this.fileName, required this.status, this.detail});

  final String fileName;
  final ImportItemStatus status;
  final String? detail;

  bool get isDone =>
      status != ImportItemStatus.queued &&
      status != ImportItemStatus.processing;
}

class ImportProgress {
  const ImportProgress(this.items);
  const ImportProgress.idle() : items = const [];

  final List<ImportItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isRunning => items.any((i) => !i.isDone);
  int get total => items.length;
  int get finished => items.where((i) => i.isDone).length;
  int get addedCount =>
      items.where((i) => i.status == ImportItemStatus.added).length;
}

class ImportController extends Notifier<ImportProgress> {
  @override
  ImportProgress build() => const ImportProgress.idle();

  Future<void> importPaths(List<String> paths) async {
    if (paths.isEmpty || state.isRunning) return;

    state = ImportProgress([
      for (final path in paths)
        ImportItem(fileName: p.basename(path), status: ImportItemStatus.queued),
    ]);

    final repo = ref.read(bookRepositoryProvider);

    for (var i = 0; i < paths.length; i++) {
      _set(i, ImportItemStatus.processing, 'Copiando y leyendo metadata…');
      final result = await repo.importFile(paths[i]);
      switch (result) {
        case ImportAdded():
          _set(i, ImportItemStatus.added, null);
        case ImportSkipped(:final reason):
          _set(i, ImportItemStatus.skipped, reason);
        case ImportFailed(:final error):
          _set(i, ImportItemStatus.failed, error.toString());
      }
    }
  }

  void clear() => state = const ImportProgress.idle();

  void _set(int index, ImportItemStatus status, String? detail) {
    final items = [...state.items];
    items[index] = ImportItem(
      fileName: items[index].fileName,
      status: status,
      detail: detail,
    );
    state = ImportProgress(items);
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportProgress>(ImportController.new);
