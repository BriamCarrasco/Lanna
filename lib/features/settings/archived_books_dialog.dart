// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../library/widgets/book_cover.dart';

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

    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Libros archivados',
                style: LannaType.title.copyWith(
                  fontFamily: AppFonts.serif,
                  color: LannaColors.textStrong,
                ),
              ),
              const SizedBox(height: LannaSpacing.s1),
              Text(
                'No aparecen en la biblioteca. Al restaurarlos vuelven con su '
                'progreso, marcadores y subrayados.',
                style: LannaType.sm.copyWith(color: LannaColors.textMuted),
              ),
              const SizedBox(height: LannaSpacing.s3),
              Flexible(
                child: books.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: LannaSpacing.s6,
                        ),
                        child: Text(
                          'No hay libros archivados',
                          textAlign: TextAlign.center,
                          style: LannaType.md.copyWith(
                            color: LannaColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: books.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: LannaColors.borderSubtle,
                        ),
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
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      child: Row(
        children: [
          SizedBox(width: 34, child: BookCover(book: book)),
          const SizedBox(width: LannaSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LannaType.md.copyWith(fontWeight: FontWeight.w600),
                ),
                if (where.isNotEmpty)
                  Text(
                    where,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.micro.copyWith(
                      color: LannaColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: LannaSpacing.s2),
          TextButton(
            onPressed: () => unawaited(
              ref.read(bookRepositoryProvider).restoreBook(book.id),
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}
