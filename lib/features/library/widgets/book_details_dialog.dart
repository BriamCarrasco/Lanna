// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import '../../../l10n/l10n.dart';
import '../../stats/reading_stats.dart';
import '../../stats/stats_providers.dart';
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
            ? context.l10n.archiveBookTitle(book.title)
            : context.l10n.deleteBookTitle(book.title),
      ),
      content: Text(
        book.folderId != null
            ? context.l10n.archiveBookBody
            : context.l10n.deleteBookBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: book.folderId != null
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: LannaColors.danger,
                  foregroundColor: LannaColors.surface,
                ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            book.folderId != null ? context.l10n.archive : context.l10n.delete,
          ),
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
    final reading = ref.watch(bookReadingProvider(book.id)).valueOrNull;

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
                            _Chip(
                              context.l10n.addedOn(
                                _formatDate(book.addedAt, context.l10n),
                              ),
                            ),
                            if (book.finishedAt != null)
                              _Chip(
                                context.l10n.finishedOn(
                                  _formatDate(book.finishedAt!, context.l10n),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: LannaSpacing.s3),
                        Text(
                          started
                              ? context.l10n.readingProgressPercent(percent)
                              : context.l10n.notStarted,
                          style: LannaType.sm.copyWith(
                            color: LannaColors.textMuted,
                          ),
                        ),
                        if (reading != null && reading.seconds >= 60) ...[
                          const SizedBox(height: 2),
                          Text(
                            _readingLine(
                              context.l10n,
                              reading,
                              progress?.percent ?? 0,
                              finished: book.finishedAt != null,
                            ),
                            style: LannaType.sm.copyWith(
                              color: LannaColors.textMuted,
                            ),
                          ),
                        ],
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
                    child: Text(context.l10n.delete),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.close),
                  ),
                  const SizedBox(width: LannaSpacing.s2),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(context.push('/reader/${book.id}'));
                    },
                    child: Text(
                      started
                          ? context.l10n.continueReading
                          : context.l10n.read,
                    ),
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

String _readingLine(
  AppLocalizations l10n,
  BookReading reading,
  double percent, {
  required bool finished,
}) {
  final read = l10n.timeRead(formatReadingTime(reading.seconds));
  if (finished) return read;
  final left = remainingEstimate(
    seconds: reading.seconds,
    progressed: reading.progressed,
    percent: percent,
  );
  if (left == null) return read;
  return l10n.timeReadRemaining(read, formatReadingTime(left.inSeconds));
}

String _formatDate(DateTime date, AppLocalizations l10n) =>
    DateFormat(l10n.dateShortPattern, l10n.localeName).format(date.toLocal());
