// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/book_format.dart';
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
      title: Text('¿Eliminar «${book.title}»?'),
      content: const Text(
        'Se quitará de la biblioteca y se borrará el archivo importado, '
        'junto con su progreso y marcadores. No se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LannaColors.accent,
            foregroundColor: LannaColors.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 96, child: BookCover(book: book)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: AppTheme.reading(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: LannaColors.textStrong,
                          ),
                        ),
                        if (book.author != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            book.author!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: LannaColors.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(book.format == BookFormat.epub
                                ? 'EPUB'
                                : 'PDF'),
                            if (book.fileSizeBytes != null)
                              _Chip(_formatSize(book.fileSizeBytes!)),
                            _Chip('Añadido ${_formatDate(book.addedAt)}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          started
                              ? 'Progreso de lectura: $percent %'
                              : 'Sin empezar',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LannaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final deleted = await confirmDeleteBook(context, ref, book);
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
                  const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: LannaColors.surfaceActive,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: LannaColors.text),
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
