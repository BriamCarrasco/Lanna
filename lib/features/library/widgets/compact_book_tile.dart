// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/local/app_database.dart';
import 'book_cover.dart';

class CompactBookTile extends StatelessWidget {
  const CompactBookTile({
    super.key,
    required this.book,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
    this.verticalPadding = LannaSpacing.s3,
  });

  final Book book;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final detail = subtitle;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Opacity(
              opacity: book.available ? 1 : 0.4,
              child: BookCover(book: book),
            ),
          ),
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
                if (detail != null && detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (subtitleStyle ?? LannaType.sm).copyWith(
                      color: LannaColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing case final widget?) ...[
            const SizedBox(width: LannaSpacing.s2),
            widget,
          ],
        ],
      ),
    );
  }
}
