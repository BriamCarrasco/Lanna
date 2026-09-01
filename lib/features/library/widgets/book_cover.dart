// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverPath;
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: (cover != null && File(cover).existsSync())
            ? Image.file(File(cover), fit: BoxFit.cover)
            : _FallbackCover(title: book.title),
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
        padding: const EdgeInsets.all(11),
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
