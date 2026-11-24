// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/local/app_database.dart';
import '../../../l10n/l10n.dart';
import '../series_group.dart';
import 'book_actions.dart';
import 'book_cover.dart';

typedef BookMenuCallback = void Function(Book book, Offset globalPosition);

final _tileTitleStyle = LannaType.sm.copyWith(
  fontWeight: FontWeight.w600,
  height: 1.25,
);

double tileTextExtent(TextScaler scaler) {
  double measure(TextStyle style, int lines) {
    final painter = TextPainter(
      text: TextSpan(
        text: List.filled(lines, 'Ág').join('\n'),
        style: style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: lines,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  const gaps = LannaSpacing.s2 * 2 + 2;
  return (gaps + measure(_tileTitleStyle, 2) + measure(LannaType.micro, 1) + 2)
      .ceilToDouble();
}

class CoverGridDelegate extends SliverGridDelegate {
  const CoverGridDelegate({required this.textExtent});

  final double textExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final narrow = width < 560;
    final gap = narrow ? LannaSpacing.s4 : LannaSpacing.s6;
    final maxExtent = narrow ? 128.0 : 172.0;
    final count = math.max(3, ((width + gap) / (maxExtent + gap)).ceil());
    final itemWidth = (width - gap * (count - 1)) / count;
    final itemHeight = itemWidth * 1.5 + textExtent;
    return SliverGridRegularTileLayout(
      crossAxisCount: count,
      mainAxisStride: itemHeight + (narrow ? LannaSpacing.s4 : LannaSpacing.s6),
      crossAxisStride: itemWidth + gap,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: itemWidth,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(CoverGridDelegate oldDelegate) =>
      oldDelegate.textExtent != textExtent;
}

CoverGridDelegate _gridDelegate(BuildContext context) => CoverGridDelegate(
  textExtent: tileTextExtent(MediaQuery.textScalerOf(context)),
);

EdgeInsets _gridPadding(BuildContext context) => EdgeInsets.symmetric(
  horizontal: MediaQuery.sizeOf(context).width < 600
      ? LannaSpacing.s4
      : LannaSpacing.s6,
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
      padding: _gridPadding(context),
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate(context),
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
    this.selection,
    this.onToggle,
    this.progress = const {},
  });

  final Map<String, double> progress;
  final List<LibraryEntry> entries;
  final BookMenuCallback onMenu;
  final ValueChanged<SeriesEntry> onOpenSeries;
  final Set<String>? selection;
  final ValueChanged<List<Book>>? onToggle;

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    return SliverPadding(
      padding: _gridPadding(context),
      sliver: SliverGrid.builder(
        gridDelegate: _gridDelegate(context),
        itemCount: entries.length,
        itemBuilder: (context, i) => switch (entries[i]) {
          BookEntry(:final book) when selection == null => BookGridTile(
            book: book,
            onMenu: onMenu,
            progress: switch (progress[book.id]) {
              final p? when p > 0 && p < 0.99 => p,
              _ => null,
            },
          ),
          BookEntry(:final book) when !book.format.hasSeries => Unselectable(
            child: BookGridTile(book: book, onMenu: onMenu),
          ),
          BookEntry(:final book) => BookGridTile(
            book: book,
            onMenu: onMenu,
            selected: selection!.contains(book.id),
            onTap: () => onToggle!([book]),
          ),
          final SeriesEntry series => SeriesGridTile(
            series: series,
            selected: selection == null
                ? null
                : series.volumes.every((b) => selection.contains(b.id)),
            onOpen: selection == null
                ? () => onOpenSeries(series)
                : () => onToggle!(series.volumes),
          ),
        },
      ),
    );
  }
}

class Unselectable extends StatelessWidget {
  const Unselectable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Opacity(opacity: 0.35, child: child));
  }
}

class SelectionMark extends StatelessWidget {
  const SelectionMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: LannaMotion.fast,
      curve: LannaMotion.ease,
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.all(LannaSpacing.s1 + 2),
      decoration: BoxDecoration(
        color: selected
            ? LannaColors.accent.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.12),
        borderRadius: LannaRadii.brSm,
        border: Border.all(
          color: selected ? LannaColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: SelectionIcon(selected: selected, onCover: true),
    );
  }
}

class SelectionIcon extends StatelessWidget {
  const SelectionIcon({
    super.key,
    required this.selected,
    this.onCover = false,
  });

  final bool selected;
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onCover ? Colors.black.withValues(alpha: 0.45) : null,
      ),
      child: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 22,
        color: switch ((selected, onCover)) {
          (true, _) => LannaColors.accent,
          (_, true) => const Color(0xFFF0E6DF),
          _ => LannaColors.textMuted,
        },
      ),
    );
  }
}

class SeriesGridTile extends StatelessWidget {
  const SeriesGridTile({
    super.key,
    required this.series,
    required this.onOpen,
    this.selected,
  });

  final SeriesEntry series;
  final VoidCallback onOpen;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final count = series.volumes.length;
    return Pressable(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                if (selected case final value?)
                  Positioned.fill(child: SelectionMark(selected: value)),
              ],
            ),
          ),
          const SizedBox(height: LannaSpacing.s2),
          Text(
            series.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _tileTitleStyle,
          ),
          Text(
            context.l10n.volumesCount(count),
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
    this.selected,
    this.onTap,
  });

  final Book book;
  final BookMenuCallback onMenu;
  final double? progress;
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final selecting = selected != null;
    return Pressable(
      onTap: onTap ?? () => openBook(context, book),
      onLongPress: selecting
          ? onTap
          : () {
              final box = context.findRenderObject()! as RenderBox;
              onMenu(book, box.localToGlobal(box.size.center(Offset.zero)));
            },
      onSecondaryTapUp: selecting
          ? null
          : (d) => onMenu(book, d.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
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
              if (selected case final value?)
                Positioned.fill(child: SelectionMark(selected: value)),
            ],
          ),
          const SizedBox(height: LannaSpacing.s2),
          SizedBox(
            height: 2,
            child: switch (progress) {
              final value? => ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor: LannaColors.borderSubtle,
                ),
              ),
              null => null,
            },
          ),
          const SizedBox(height: LannaSpacing.s2),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _tileTitleStyle,
          ),
          if (!book.available)
            Text(
              context.l10n.unavailable,
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
