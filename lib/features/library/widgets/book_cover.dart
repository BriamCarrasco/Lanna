// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/book_format.dart';

String formatLabel(Book book) => switch (book.format) {
  BookFormat.epub => 'EPUB',
  BookFormat.pdf => 'PDF',
  BookFormat.comic =>
    (book.relativePath ?? book.filePath).toLowerCase().endsWith('.cbr')
        ? 'CBR'
        : 'CBZ',
};

const _coverStep = 64;

int coverDecodeWidth(double logicalWidth, double pixelRatio) {
  final physical = (logicalWidth * pixelRatio).ceil();
  return ((physical + _coverStep - 1) ~/ _coverStep) * _coverStep;
}

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.showFormat = false});

  final Book book;
  final bool showFormat;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverPath;
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: LannaRadii.brSm,
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: LannaRadii.brSm,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover == null)
                _FallbackCover(title: book.title, author: book.author)
              else
                LayoutBuilder(
                  builder: (context, constraints) => Image(
                    image: ResizeImage(
                      FileImage(File(cover)),
                      width: coverDecodeWidth(
                        constraints.maxWidth,
                        MediaQuery.devicePixelRatioOf(context),
                      ),
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        _FallbackCover(title: book.title, author: book.author),
                  ),
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: LannaRadii.brSm,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x14FFFFFF)),
                    ),
                  ),
                ),
              ),
              if (showFormat && book.format != BookFormat.epub)
                Positioned(
                  right: LannaSpacing.s1 + 2,
                  bottom: LannaSpacing.s1 + 2,
                  child: _FormatBadge(formatLabel(book)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: LannaRadii.brXs,
      ),
      child: Text(
        label,
        style: LannaType.micro.copyWith(
          fontSize: 9.5,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: const Color(0xFFF0E6DF),
        ),
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.title, this.author});

  final String title;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final cloth = _clothColor(title);
    final ink = const Color(0xFFEDE5D8);
    return ColoredBox(
      color: cloth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final pad = (w * 0.1).clamp(6.0, 18.0);
          final titleSize = (w * 0.11).clamp(9.0, 20.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (w * 0.05).clamp(3.0, 8.0),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad * 1.3, pad * 1.4, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: w < 56
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.reading(
                                      fontSize: titleSize,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                SizedBox(height: pad * 0.6),
                                Container(
                                  width: w * 0.18,
                                  height: 1,
                                  color: ink.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                    ),
                    if (author != null && w >= 72)
                      Text(
                        author!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LannaType.micro.copyWith(
                          fontSize: (w * 0.065).clamp(8.0, 12.0),
                          color: ink.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _clothColor(String title) {
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    const hues = [8.0, 24.0, 152.0, 198.0, 220.0, 262.0, 340.0];
    final hue = hues[hash % hues.length];
    return HSLColor.fromAHSL(1, hue, 0.16, 0.24).toColor();
  }
}
