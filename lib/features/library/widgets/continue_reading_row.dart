// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import 'book_cover.dart';

class ContinueReadingRow extends StatelessWidget {
  const ContinueReadingRow({super.key, required this.items});

  final List<BookWithProgress> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 14.0;
          final perRow = items.length.clamp(1, 3);
          final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: width.clamp(220.0, 340.0),
                    child: _Card(item: items[i]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item});
  final BookWithProgress item;

  @override
  Widget build(BuildContext context) {
    final pct = item.progress.percent.clamp(0.0, 1.0);
    final chapter = item.progress.chapterIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => context.push('/reader/${item.book.id}'),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: LannaColors.surfaceHigh,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: LannaColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 64, child: BookCover(book: item.book)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.reading(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LannaColors.text,
                    ),
                  ),
                  if (item.book.author != null)
                    Text(
                      item.book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: LannaColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    chapter != null
                        ? 'Cap. ${chapter + 1} · ${(pct * 100).round()} %'
                        : '${(pct * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 11,
                      color: LannaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 3,
                      backgroundColor: LannaColors.border,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
