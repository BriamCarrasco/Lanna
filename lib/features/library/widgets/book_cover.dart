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

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.showFormat = false});

  final Book book;
  final bool showFormat;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverPath;
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: LannaRadii.brSm,
        child: Stack(
          fit: StackFit.expand,
          children: [
            (cover != null && File(cover).existsSync())
                ? Image.file(File(cover), fit: BoxFit.cover)
                : _FallbackCover(title: book.title),
            if (showFormat)
              Positioned(
                left: LannaSpacing.s1 + 2,
                bottom: LannaSpacing.s1 + 2,
                child: _FormatBadge(formatLabel(book)),
              ),
          ],
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
  const _FallbackCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final base = _seedColor(title);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            HSLColor.fromColor(base).withLightness(0.16).toColor(),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LannaSpacing.s3),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.reading(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFF0E6DF),
            ),
          ),
        ),
      ),
    );
  }

  Color _seedColor(String title) {
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.28, 0.30).toColor();
  }
}
