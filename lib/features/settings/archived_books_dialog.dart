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
import '../../l10n/l10n.dart';
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
      title: context.l10n.archivedBooks,
      subtitle: context.l10n.archivedBooksHint,
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
                    context.l10n.noArchivedBooks,
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
            child: Text(context.l10n.close),
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
            child: Text(context.l10n.restore),
          ),
          IconButton(
            onPressed: () => unawaited(_delete(context, ref)),
            icon: const Icon(Icons.delete_outline),
            color: LannaColors.danger,
            tooltip: context.l10n.deleteFromDevice,
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final repo = ref.read(bookRepositoryProvider);
    final confirmed = await confirmDeleteFromDevice(context, book, folder);
    if (!confirmed) return;
    String message;
    try {
      await repo.deleteFromDevice(book.id);
      message = l10n.bookDeletedFromDevice(book.title);
    } on FolderWriteDenied {
      message = folder == null
          ? l10n.deleteDenied
          : l10n.deleteDeniedFolder(folder!);
    } catch (_) {
      message = l10n.deleteFailed(book.title);
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
      title: Text(context.l10n.deleteFromDeviceTitle(book.title)),
      content: Text(
        folder == null
            ? context.l10n.deleteFromDeviceBody(file)
            : context.l10n.deleteFromFolderBody(file, folder),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LannaColors.danger,
            foregroundColor: LannaColors.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
