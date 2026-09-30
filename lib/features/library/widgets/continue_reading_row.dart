// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/book_format.dart';
import 'book_cover.dart';

class ContinueReadingRow extends StatelessWidget {
  const ContinueReadingRow({super.key, required this.items});

  final List<BookWithProgress> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LannaSpacing.s6,
        0,
        LannaSpacing.s6,
        LannaSpacing.s1,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = LannaSpacing.s3;
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
    final unit = item.book.format == BookFormat.epub ? 'Cap.' : 'Pág.';

    return Pressable(
      scale: 0.98,
      onTap: () => context.push('/reader/${item.book.id}'),
      child: Container(
        padding: const EdgeInsets.all(LannaSpacing.s3),
        decoration: BoxDecoration(
          color: LannaColors.surfaceHigh,
          borderRadius: LannaRadii.brMd,
          border: Border.all(color: LannaColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 64, child: BookCover(book: item.book)),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.lg.copyWith(
                      fontFamily: AppFonts.serif,
                      color: LannaColors.text,
                    ),
                  ),
                  if (item.book.author != null)
                    Text(
                      item.book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LannaType.micro.copyWith(
                        color: LannaColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: LannaSpacing.s3),
                  Text(
                    chapter != null
                        ? '$unit ${chapter + 1} · ${(pct * 100).round()} %'
                        : '${(pct * 100).round()} %',
                    style: LannaType.micro.copyWith(
                      color: LannaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: LannaSpacing.s1 + 2),
                  ClipRRect(
                    borderRadius: LannaRadii.brXs,
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
