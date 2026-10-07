// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/lanna_dialog.dart';
import '../../data/book_repository.dart';
import '../../data/library/folder_access.dart';
import '../../data/local/app_database.dart';
import '../library/widgets/compact_book_tile.dart';

Future<void> showArchivedBooks(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const ArchivedBooksDialog(),
  );
}

class ArchivedBooksDialog extends ConsumerWidget {
  const ArchivedBooksDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(archivedProvider).valueOrNull ?? const <Book>[];
    final folders = {
      for (final f
          in ref.watch(libraryFoldersProvider).valueOrNull ??
              const <LibraryFolder>[])
        f.id: f.name,
    };

    return LannaDialog(
      title: 'Libros archivados',
      subtitle:
          'No aparecen en la biblioteca. Al restaurarlos vuelven con su '
          'progreso, marcadores y subrayados. También puedes eliminarlos del '
          'dispositivo.',
      serifTitle: true,
      maxWidth: 480,
      maxHeight: 560,
      children: [
        Flexible(
          child: books.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: LannaSpacing.s6,
                  ),
                  child: Text(
                    'No hay libros archivados',
                    textAlign: TextAlign.center,
                    style: LannaType.md.copyWith(color: LannaColors.textMuted),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: books.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: LannaColors.borderSubtle),
                  itemBuilder: (context, i) => _ArchivedRow(
                    book: books[i],
                    folder: folders[books[i].folderId],
                  ),
                ),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    );
  }
}

class _ArchivedRow extends ConsumerWidget {
  const _ArchivedRow({required this.book, this.folder});

  final Book book;
  final String? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final where = [?folder, ?book.relativePath].join(' · ');
    return CompactBookTile(
      book: book,
      subtitle: where,
      subtitleStyle: LannaType.micro,
      verticalPadding: LannaSpacing.s2,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => unawaited(
              ref.read(bookRepositoryProvider).restoreBook(book.id),
            ),
            child: const Text('Restaurar'),
          ),
          IconButton(
            onPressed: () => unawaited(_delete(context, ref)),
            icon: const Icon(Icons.delete_outline),
            color: LannaColors.danger,
            tooltip: 'Eliminar del dispositivo',
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(bookRepositoryProvider);
    final confirmed = await confirmDeleteFromDevice(context, book, folder);
    if (!confirmed) return;
    String message;
    try {
      await repo.deleteFromDevice(book.id);
      message = '«${book.title}» eliminado del dispositivo';
    } on FolderWriteDenied {
      message =
          'Lanna no tiene permiso para borrar en '
          '${folder == null ? 'esa carpeta' : '«$folder»'}. Vuelve a añadir '
          'la carpeta desde la Biblioteca para concederlo.';
    } catch (_) {
      message = 'No se pudo eliminar «${book.title}». Inténtalo de nuevo.';
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        persist: false,
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

Future<bool> confirmDeleteFromDevice(
  BuildContext context,
  Book book,
  String? folder,
) async {
  final file = book.relativePath ?? book.title;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text('¿Eliminar «${book.title}» del dispositivo?'),
      content: Text(
        'Se borrará el archivo «$file»'
        '${folder == null ? '' : ' de la carpeta «$folder»'} y se quitará '
        'de Lanna junto con su progreso, marcadores, subrayados y tiempo de '
        'lectura. No se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LannaColors.danger,
            foregroundColor: LannaColors.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
