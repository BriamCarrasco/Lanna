// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import 'book_cover.dart';

Future<void> showBookDetails(BuildContext context, Book book) {
  return showDialog(
    context: context,
    builder: (_) => BookDetailsDialog(book: book),
  );
}

Future<bool> confirmDeleteBook(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text(
        book.folderId != null
            ? '¿Archivar «${book.title}»?'
            : '¿Eliminar «${book.title}»?',
      ),
      content: Text(
        book.folderId != null
            ? 'Dejará de aparecer en la biblioteca, pero conserva su '
                  'progreso, marcadores y subrayados. El archivo se queda en '
                  'su carpeta. Puedes recuperarlo desde Ajustes → Libros '
                  'archivados.'
            : 'Se quitará de la biblioteca y se borrará el archivo importado, '
                  'junto con su progreso y marcadores. No se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: book.folderId != null
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: LannaColors.danger,
                  foregroundColor: LannaColors.surface,
                ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(book.folderId != null ? 'Archivar' : 'Eliminar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(bookRepositoryProvider).deleteBook(book.id);
  return true;
}

class BookDetailsDialog extends ConsumerWidget {
  const BookDetailsDialog({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bookProgressProvider(book.id)).valueOrNull;
    final percent = ((progress?.percent ?? 0) * 100).round();
    final started = (progress?.percent ?? 0) > 0;

    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(LannaSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 96, child: BookCover(book: book)),
                  const SizedBox(width: LannaSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: LannaType.title.copyWith(
                            color: LannaColors.textStrong,
                          ),
                        ),
                        if (book.author != null) ...[
                          const SizedBox(height: LannaSpacing.s1),
                          Text(
                            book.author!,
                            style: LannaType.md.copyWith(
                              color: LannaColors.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: LannaSpacing.s3),
                        Wrap(
                          spacing: LannaSpacing.s1 + 2,
                          runSpacing: LannaSpacing.s1 + 2,
                          children: [
                            _Chip(formatLabel(book)),
                            if (book.fileSizeBytes != null)
                              _Chip(_formatSize(book.fileSizeBytes!)),
                            _Chip('Añadido ${_formatDate(book.addedAt)}'),
                          ],
                        ),
                        const SizedBox(height: LannaSpacing.s3),
                        Text(
                          started
                              ? 'Progreso de lectura: $percent %'
                              : 'Sin empezar',
                          style: LannaType.sm.copyWith(
                            color: LannaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LannaSpacing.s5),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final deleted = await confirmDeleteBook(
                        context,
                        ref,
                        book,
                      );
                      if (deleted) navigator.pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: LannaColors.accentStrong,
                    ),
                    child: const Text('Eliminar'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: LannaSpacing.s2),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/reader/${book.id}');
                    },
                    child: Text(started ? 'Seguir leyendo' : 'Leer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LannaSpacing.s2 + 1,
        vertical: LannaSpacing.s1,
      ),
      decoration: const BoxDecoration(
        color: LannaColors.surfaceActive,
        borderRadius: LannaRadii.brSm,
      ),
      child: Text(
        label,
        style: LannaType.micro.copyWith(color: LannaColors.text),
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(DateTime date) {
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
