// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/local/app_database.dart';
import '../series_group.dart';
import 'book_actions.dart';
import 'book_cover.dart';

typedef BookMenuCallback = void Function(Book book, Offset globalPosition);

const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 168,
  childAspectRatio: 0.54,
  crossAxisSpacing: LannaSpacing.s5,
  mainAxisSpacing: LannaSpacing.s6,
);

class BookGridSliver extends StatelessWidget {
  const BookGridSliver({
    super.key,
    required this.books,
    required this.onMenu,
    this.progress,
  });

  final List<Book> books;
  final BookMenuCallback onMenu;
  final Map<String, double>? progress;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate,
        itemCount: books.length,
        itemBuilder: (context, i) => BookGridTile(
          book: books[i],
          onMenu: onMenu,
          progress: progress?[books[i].id] ?? (progress == null ? null : 0),
        ),
      ),
    );
  }
}

class LibraryGridSliver extends StatelessWidget {
  const LibraryGridSliver({
    super.key,
    required this.entries,
    required this.onMenu,
    required this.onOpenSeries,
  });

  final List<LibraryEntry> entries;
  final BookMenuCallback onMenu;
  final ValueChanged<SeriesEntry> onOpenSeries;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate,
        itemCount: entries.length,
        itemBuilder: (context, i) => switch (entries[i]) {
          BookEntry(:final book) => BookGridTile(book: book, onMenu: onMenu),
          final SeriesEntry series => SeriesGridTile(
            series: series,
            onOpen: () => onOpenSeries(series),
          ),
        },
      ),
    );
  }
}

class SeriesGridTile extends StatelessWidget {
  const SeriesGridTile({super.key, required this.series, required this.onOpen});

  final SeriesEntry series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final count = series.volumes.length;
    return Pressable(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final shift in const [8.0, 4.0])
                      Positioned.fill(
                        left: shift,
                        right: -shift,
                        top: -shift,
                        bottom: shift,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: shift == 8
                                ? LannaColors.surfaceActive
                                : LannaColors.border,
                            borderRadius: LannaRadii.brSm,
                            border: Border.all(color: LannaColors.bg),
                          ),
                        ),
                      ),
                    BookCover(book: series.first, showFormat: true),
                    Positioned(
                      top: LannaSpacing.s1 + 2,
                      right: LannaSpacing.s1 + 2,
                      child: _CountBadge(count),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: LannaSpacing.s2),
          Text(
            series.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LannaType.sm.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          Text(
            '$count ${count == 1 ? 'tomo' : 'tomos'}',
            maxLines: 1,
            style: LannaType.micro.copyWith(color: LannaColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: LannaRadii.brXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 11, color: Color(0xFFF0E6DF)),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: LannaType.micro.copyWith(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF0E6DF),
            ),
          ),
        ],
      ),
    );
  }
}

class BookGridTile extends StatelessWidget {
  const BookGridTile({
    super.key,
    required this.book,
    required this.onMenu,
    this.progress,
  });

  final Book book;
  final BookMenuCallback onMenu;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openBook(context, book),
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        onMenu(book, box.localToGlobal(box.size.center(Offset.zero)));
      },
      onSecondaryTapUp: (d) => onMenu(book, d.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Stack(
                children: [
                  Opacity(
                    opacity: book.available ? 1 : 0.4,
                    child: BookCover(book: book, showFormat: true),
                  ),
                  if (book.favoritedAt != null)
                    const Positioned(
                      top: LannaSpacing.s1 + 2,
                      right: LannaSpacing.s1 + 2,
                      child: _FavoriteBadge(),
                    ),
                ],
              ),
            ),
          ),
          if (progress case final value?) ...[
            const SizedBox(height: LannaSpacing.s1 + 2),
            ClipRRect(
              borderRadius: LannaRadii.brXs,
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: LannaColors.border,
              ),
            ),
          ],
          const SizedBox(height: LannaSpacing.s2),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LannaType.sm.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (!book.available)
            Text(
              'No disponible',
              style: LannaType.micro.copyWith(color: LannaColors.danger),
            )
          else if (book.author != null)
            Text(
              book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LannaType.micro.copyWith(color: LannaColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LannaSpacing.s1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.favorite, size: 13, color: LannaColors.accent),
    );
  }
}
