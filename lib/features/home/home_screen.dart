// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/pressable.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../data/models/book_format.dart';
import '../../l10n/l10n.dart';
import '../library/library_scan_controller.dart';
import '../library/widgets/book_actions.dart';
import '../library/widgets/book_cover.dart';
import '../library/widgets/empty_library_view.dart';
import '../stats/reading_stats.dart';
import '../stats/stats_providers.dart';
import '../stats/week_bars.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _wideFrom = 1000.0;
  static const _panelFrom = 1240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).valueOrNull;
    if (library == null) return const SizedBox.shrink();
    if (library.isEmpty) {
      final hasFolders =
          ref.watch(libraryFoldersProvider).valueOrNull?.isNotEmpty ?? false;
      final scan = ref.read(libraryScanProvider.notifier);
      return FadeIn(
        child: EmptyLibraryView(
          hasFolders: hasFolders,
          onAddFolder: () => unawaited(
            reportScan(
              ScaffoldMessenger.of(context),
              context.l10n,
              scan.addFolder(dialogTitle: context.l10n.chooseBooksFolder),
            ),
          ),
          onRescan: () => reportScan(
            ScaffoldMessenger.of(context),
            context.l10n,
            scan.scan(),
          ),
        ),
      );
    }

    final reading = ref.watch(continueReadingProvider).valueOrNull ?? const [];
    final stats = ref.watch(readingStatsProvider).valueOrNull;
    final recent = [...library]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= _wideFrom;
        final gutter = switch (width) {
          < 480 => LannaSpacing.s5,
          < _wideFrom => LannaSpacing.s8,
          _ => 48.0,
        };
        final grid = _ShelfGrid.fit(width - gutter * 2, wide: wide);
        final section = wide ? 64.0 : 40.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            wide ? 48 : LannaSpacing.s6,
            gutter,
            64,
          ),
          child: FadeIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (reading.isEmpty)
                  Text(
                    context.l10n.pickBookToStart,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: wide ? 32 : 24,
                      height: 1.2,
                      color: LannaColors.textStrong,
                    ),
                  )
                else
                  _Hero(
                    item: reading.first,
                    stats: stats,
                    wide: wide,
                    panel: width >= _panelFrom && stats != null,
                  ),
                if (reading.length > 1) ...[
                  SizedBox(height: section),
                  _SectionHeader(context.l10n.alsoReading),
                  const SizedBox(height: LannaSpacing.s4),
                  grid.row([
                    for (final item in reading.skip(1))
                      _ShelfItem(
                        book: item.book,
                        detail: _position(context, item),
                        progress: item.progress.percent,
                      ),
                  ]),
                ],
                SizedBox(height: section),
                _SectionHeader(
                  context.l10n.recentlyAdded,
                  link: context.l10n.seeLibrary(library.length),
                  onLink: () => context.go('/library'),
                ),
                const SizedBox(height: LannaSpacing.s4),
                grid.row([
                  for (final book in recent.take(grid.columns))
                    _ShelfItem(book: book, detail: book.author),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _lastRead(BuildContext context, DateTime when) {
  final l10n = context.l10n;
  final now = DateTime.now();
  final elapsed = now.difference(when);
  if (elapsed.inMinutes < 60) return l10n.lastReadMoment;
  final today = dayOf(now);
  final day = dayOf(when);
  if (day == today) return l10n.lastReadHours(elapsed.inHours);
  final days = today.difference(day).inDays;
  if (days == 1) return l10n.lastReadYesterday;
  return l10n.lastReadDays(days);
}

String _position(BuildContext context, BookWithProgress item) {
  final percent = (item.progress.percent.clamp(0.0, 1.0) * 100).round();
  final page = item.progress.chapterIndex;
  if (item.book.format != BookFormat.epub && page != null) {
    return '${context.l10n.pageShort} ${page + 1} · $percent %';
  }
  return context.l10n.percentRead(percent);
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.item,
    required this.stats,
    required this.wide,
    required this.panel,
  });

  final BookWithProgress item;
  final ReadingStats? stats;
  final bool wide;
  final bool panel;

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final meta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _lastRead(context, item.progress.updatedAt),
          style: LannaType.md.copyWith(color: LannaColors.textMuted),
        ),
        SizedBox(height: wide ? LannaSpacing.s3 : LannaSpacing.s2),
        Text(
          book.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: wide ? 36 : 22,
            fontWeight: FontWeight.w500,
            height: 1.12,
            letterSpacing: wide ? -0.4 : -0.2,
            color: LannaColors.textStrong,
          ),
        ),
        if (book.author != null) ...[
          const SizedBox(height: LannaSpacing.s2),
          Text(
            book.author!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LannaType.base.copyWith(
              fontSize: wide ? 16 : 14,
              color: LannaColors.textMuted,
            ),
          ),
        ],
      ],
    );
    final cover = Pressable(
      scale: 0.98,
      onTap: () => openBook(context, book),
      child: BookCover(book: book),
    );
    final button = FilledButton(
      onPressed: () => openBook(context, book),
      style: FilledButton.styleFrom(
        minimumSize: Size(0, wide ? 44 : 48),
        padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      ),
      child: Text(context.l10n.continueReading),
    );
    final today = stats == null ? null : _TodayLine(stats: stats!);

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: cover),
              const SizedBox(width: LannaSpacing.s4),
              Expanded(child: meta),
            ],
          ),
          const SizedBox(height: LannaSpacing.s6),
          _Progress(item: item),
          const SizedBox(height: LannaSpacing.s5),
          button,
          if (today != null) ...[
            const SizedBox(height: LannaSpacing.s3),
            Center(child: today),
          ],
        ],
      );
    }

    final coverWidth = (MediaQuery.sizeOf(context).width * 0.11).clamp(
      180.0,
      240.0,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: coverWidth, child: cover),
        const SizedBox(width: 40),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  meta,
                  const SizedBox(height: LannaSpacing.s8),
                  _Progress(item: item),
                  const SizedBox(height: LannaSpacing.s6),
                  Row(
                    children: [
                      button,
                      if (today != null) ...[
                        const SizedBox(width: LannaSpacing.s5),
                        Flexible(child: today),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (panel) ...[
          const SizedBox(width: 64),
          SizedBox(width: 264, child: _WeekPanel(stats: stats!)),
        ],
      ],
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.item});

  final BookWithProgress item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = item.progress.percent.clamp(0.0, 1.0);
    final reading = ref.watch(bookReadingProvider(item.book.id)).valueOrNull;
    final remaining = reading == null
        ? null
        : remainingEstimate(
            seconds: reading.seconds,
            progressed: reading.progressed,
            percent: percent,
          );
    final style = LannaType.md.copyWith(
      color: LannaColors.textMuted,
      fontFeatures: LannaType.tabular,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 3,
            backgroundColor: LannaColors.borderSubtle,
          ),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Row(
          children: [
            Expanded(
              child: Text(
                _position(context, item),
                style: style.copyWith(color: LannaColors.text),
              ),
            ),
            if (remaining != null)
              Text(
                context.l10n.timeToFinish(
                  formatReadingTime(remaining.inSeconds),
                ),
                style: style,
              ),
          ],
        ),
      ],
    );
  }
}

class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final met = stats.todaySeconds >= stats.goalSeconds;
    return Text(
      met
          ? context.l10n.todayGoalMet(formatReadingTime(stats.todaySeconds))
          : context.l10n.todayMinutes(
              (stats.todaySeconds / 60).floor(),
              stats.goalSeconds ~/ 60,
            ),
      style: LannaType.md.copyWith(
        color: LannaColors.textMuted,
        fontFeatures: LannaType.tabular,
      ),
    );
  }
}

class _WeekPanel extends StatelessWidget {
  const _WeekPanel({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = stats.today;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final read = days.where((d) => !d.isAfter(today) && stats.secondsOn(d) > 0);
    final initial = DateFormat('EEEEE', l10n.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.thisWeek,
          style: LannaType.md.copyWith(color: LannaColors.textMuted),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Text(
          l10n.weekSummary(formatReadingTime(stats.weekSeconds), read.length),
          style: const TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 20,
            height: 1.3,
            color: LannaColors.textStrong,
            fontFeatures: LannaType.tabular,
          ),
        ),
        const SizedBox(height: LannaSpacing.s6),
        WeekBars(stats: stats, days: days, height: 56, barWidth: 12),
        const SizedBox(height: LannaSpacing.s2),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Text(
                  initial.format(day),
                  textAlign: TextAlign.center,
                  style: LannaType.micro.copyWith(
                    fontWeight: day == today ? FontWeight.w700 : null,
                    color: day == today
                        ? LannaColors.textStrong
                        : LannaColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: LannaSpacing.s5),
        _Link(label: l10n.seeStats, onTap: () => context.go('/stats')),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: LannaColors.text,
        padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s2),
        minimumSize: const Size(0, 36),
        textStyle: LannaType.md.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.link, this.onLink});

  final String text;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: LannaType.lg.copyWith(color: LannaColors.textStrong),
          ),
        ),
        if (link != null && onLink != null) _Link(label: link!, onTap: onLink!),
      ],
    );
  }
}

class _ShelfGrid {
  const _ShelfGrid(this.columns, this.itemWidth, this.gap);

  factory _ShelfGrid.fit(double width, {required bool wide}) {
    final gap = wide ? LannaSpacing.s6 : LannaSpacing.s4;
    final min = wide ? 128.0 : 92.0;
    final columns = math.max(3, ((width + gap) / (min + gap)).floor());
    return _ShelfGrid(columns, (width - gap * (columns - 1)) / columns, gap);
  }

  final int columns;
  final double itemWidth;
  final double gap;

  Widget row(List<Widget> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < math.min(items.length, columns); i++) ...[
          if (i > 0) SizedBox(width: gap),
          SizedBox(width: itemWidth, child: items[i]),
        ],
      ],
    );
  }
}

class _ShelfItem extends ConsumerWidget {
  const _ShelfItem({required this.book, this.detail, this.progress});

  final Book book;
  final String? detail;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      scale: 0.98,
      onTap: () => openBook(context, book),
      onSecondaryTapUp: (details) =>
          unawaited(showBookMenu(context, ref, book, details.globalPosition)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookCover(book: book),
          if (progress != null) ...[
            const SizedBox(height: LannaSpacing.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 2,
                color: LannaColors.textMuted,
                backgroundColor: LannaColors.borderSubtle,
              ),
            ),
          ],
          const SizedBox(height: LannaSpacing.s3),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LannaType.md.copyWith(
              fontWeight: FontWeight.w600,
              color: LannaColors.text,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LannaType.sm.copyWith(
                color: LannaColors.textMuted,
                fontFeatures: LannaType.tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
