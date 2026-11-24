// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';
import '../library/widgets/book_actions.dart';
import '../library/widgets/book_cover.dart';
import 'reading_stats.dart';
import 'stats_providers.dart';
import 'week_bars.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.bookId,
    required this.day,
    required this.startedAt,
    required this.seconds,
    required this.pages,
    required this.progressed,
  });

  final String bookId;
  final DateTime day;
  final DateTime startedAt;
  final int seconds;
  final int pages;
  final double progressed;
}

List<DiaryEntry> diaryEntries(
  Iterable<ReadingSession> sessions, {
  required DateTime since,
  int limit = 8,
}) {
  final groups = <(DateTime, String), List<ReadingSession>>{};
  for (final s in sessions) {
    if (s.startedAt.isBefore(since)) continue;
    groups.putIfAbsent((dayOf(s.startedAt), s.bookId), () => []).add(s);
  }
  final entries = [
    for (final MapEntry(key: (day, bookId), value: list) in groups.entries)
      DiaryEntry(
        bookId: bookId,
        day: day,
        startedAt: list
            .map((s) => s.startedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b),
        seconds: list.fold(0, (sum, s) => sum + s.seconds),
        pages: list.fold(0, (sum, s) => sum + s.pages),
        progressed: list.fold(
          0.0,
          (sum, s) => sum + math.max(0, s.endPercent - s.startPercent),
        ),
      ),
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return entries.take(limit).toList();
}

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

class DiaryView extends ConsumerWidget {
  const DiaryView({super.key, required this.stats});

  final ReadingStats stats;

  static const _twoColumnsFrom = 900.0;
  static const _fixedFrom = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(readingSessionsProvider).valueOrNull ?? const [];
    final finished =
        ref.watch(finishedThisYearProvider).valueOrNull ?? const [];
    final today = stats.today;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= _twoColumnsFrom;
        final gutter = switch (width) {
          < 620 => LannaSpacing.s4,
          < _twoColumnsFrom => LannaSpacing.s6,
          _ => LannaSpacing.s10,
        };
        final fixed = wide && constraints.maxHeight >= _fixedFrom;
        final entries = diaryEntries(
          sessions,
          since: DateTime(
            today.year,
            today.month,
            today.day - (fixed ? 90 : 30),
          ),
          limit: fixed ? 60 : 8,
        );
        final week = _Week(stats: stats, large: wide);
        final read = _Entries(
          entries: entries,
          today: today,
          scrollable: fixed,
        );
        final year = _Year(
          stats: stats,
          finished: finished,
          rows: fixed ? 1 : 2,
        );
        if (fixed) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, gutter + 8, gutter, 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      week,
                      const SizedBox(height: 48),
                      _Months(stats: stats),
                    ],
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: read),
                      const SizedBox(height: LannaSpacing.s8),
                      year,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, gutter + 8, gutter, 56),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          week,
                          const SizedBox(height: 48),
                          _Months(stats: stats),
                        ],
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [read, const SizedBox(height: 40), year],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    week,
                    const SizedBox(height: 36),
                    _MonthCalendar(stats: stats),
                    const SizedBox(height: 36),
                    read,
                    const SizedBox(height: 32),
                    year,
                  ],
                ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            text,
            style: LannaType.lg.copyWith(
              fontSize: 15,
              color: LannaColors.textStrong,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: LannaType.md.copyWith(color: LannaColors.textMuted),
          ),
      ],
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.stats, required this.large});

  final ReadingStats stats;
  final bool large;

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
    final daysRead = days
        .where((d) => !d.isAfter(today) && stats.secondsOn(d) > 0)
        .length;
    final time = formatReadingTime(stats.weekSeconds);
    final sentence = stats.weekSeconds == 0
        ? l10n.diaryWeekEmpty
        : l10n.diaryWeek(time, daysRead);
    final split = sentence.indexOf(time);
    final last = sentence.lastIndexOf(' ');
    final tail = last > split + time.length
        ? '${sentence.substring(split + time.length, last)} ${sentence.substring(last + 1)}'
        : sentence.substring(split + time.length);
    final base = TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: large ? 30 : 22,
      height: 1.3,
      color: LannaColors.textStrong,
    );
    final met = stats.todaySeconds >= stats.goalSeconds;
    final todayText = met
        ? l10n.todayGoalMet(formatReadingTime(stats.todaySeconds))
        : l10n.todayMinutes(
            (stats.todaySeconds / 60).floor(),
            stats.goalSeconds ~/ 60,
          );
    final weekday = DateFormat(large ? 'EEE' : 'EEEEE', l10n.localeName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text.rich(
            stats.weekSeconds == 0 || split < 0
                ? TextSpan(text: sentence)
                : TextSpan(
                    children: [
                      TextSpan(text: sentence.substring(0, split)),
                      TextSpan(
                        text: time,
                        style: const TextStyle(color: LannaColors.accentStrong),
                      ),
                      TextSpan(text: tail),
                    ],
                  ),
            style: base,
          ),
        ),
        const SizedBox(height: LannaSpacing.s6),
        WeekBars(
          stats: stats,
          days: days,
          height: large ? 120 : 96,
          barWidth: large ? 24 : 16,
          goalLine: true,
        ),
        const SizedBox(height: LannaSpacing.s2),
        Row(
          children: [
            for (var i = 0; i < days.length; i++) ...[
              Expanded(
                child: Text(
                  large && days[i] == today
                      ? l10n.today
                      : _capitalized(
                          weekday.format(days[i]).replaceAll('.', ''),
                        ),
                  textAlign: TextAlign.center,
                  style: LannaType.sm.copyWith(
                    fontWeight: days[i] == today
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: days[i] == today
                        ? LannaColors.textStrong
                        : LannaColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: LannaSpacing.s3),
        Text(
          '${l10n.diaryGoalLine} $todayText.',
          style: LannaType.md.copyWith(color: LannaColors.textMuted),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = stats.today;
    final first = DateTime(today.year, today.month);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final lead = first.weekday - 1;
    final monday = DateTime(2024, 1, 1);
    final weekday = DateFormat('EEEEE', l10n.localeName);
    final cells = <Widget>[
      for (var i = 0; i < 7; i++)
        Center(
          child: Text(
            weekday.format(DateTime(monday.year, monday.month, i + 1)),
            style: LannaType.micro.copyWith(color: LannaColors.textMuted),
          ),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(day: DateTime(today.year, today.month, d), stats: stats),
    ];
    final rows = (cells.length / 7).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          _capitalized(DateFormat('MMMM', l10n.localeName).format(today)),
          trailing: l10n.readingDays(stats.daysReadSince(first)),
        ),
        const SizedBox(height: LannaSpacing.s3),
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: r == 0 ? 24 : 42,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: r * 7 + c < cells.length
                        ? cells[r * 7 + c]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.stats});

  final DateTime day;
  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final isToday = day == stats.today;
    final future = day.isAfter(stats.today);
    final seconds = stats.secondsOn(day);
    final level = stats.levelOn(day);
    final size = switch (level) {
      0 => 0.0,
      1 => 4.0,
      2 => 5.0,
      3 => 7.0,
      _ => 8.0,
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${day.day}',
          style: LannaType.md.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: switch ((future, isToday)) {
              (true, _) => LannaColors.textMuted.withValues(alpha: 0.5),
              (_, true) => LannaColors.textStrong,
              _ => LannaColors.text,
            },
            decoration: isToday ? TextDecoration.underline : null,
            decorationColor: LannaColors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: seconds >= stats.goalSeconds
                ? LannaColors.text
                : LannaColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Months extends StatelessWidget {
  const _Months({required this.stats});

  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final months = stats.monthlyTotals(12);
    final top = math.max(1, months.map((m) => m.seconds).fold(0, math.max));
    final format = DateFormat('MMM', l10n.localeName);
    final current = DateTime(stats.today.year, stats.today.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          l10n.yearByMonth,
          trailing: l10n.readingDays(
            stats.daysReadSince(DateTime(stats.today.year)),
          ),
        ),
        const SizedBox(height: LannaSpacing.s6),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              for (final month in months)
                Expanded(
                  child: Tooltip(
                    message: formatReadingTime(month.seconds),
                    child: BarColumn(
                      fraction: month.seconds / top,
                      maxHeight: 120,
                      width: 18,
                      color: switch ((month.seconds, month.month == current)) {
                        (0, _) => LannaColors.borderSubtle,
                        (_, true) => LannaColors.text,
                        _ => barRest,
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Row(
          children: [
            for (final month in months)
              Expanded(
                child: Text(
                  format.format(month.month).replaceAll('.', ''),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: LannaType.sm.copyWith(
                    fontWeight: month.month == current ? FontWeight.w700 : null,
                    color: month.month == current
                        ? LannaColors.textStrong
                        : LannaColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({
    required this.entries,
    required this.today,
    this.scrollable = false,
  });

  final List<DiaryEntry> entries;
  final DateTime today;
  final bool scrollable;

  String _dayTitle(BuildContext context, DateTime day) {
    final l10n = context.l10n;
    final days = today.difference(day).inDays;
    if (days == 0) return l10n.today;
    final pattern = days < 7 ? 'EEEE' : l10n.dayPattern;
    return _capitalized(DateFormat(pattern, l10n.localeName).format(day));
  }

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<DiaryEntry>>{};
    for (final entry in entries) {
      days.putIfAbsent(entry.day, () => []).add(entry);
    }
    final items = [
      if (entries.isEmpty)
        Text(
          context.l10n.diaryEmpty,
          style: LannaType.base.copyWith(color: LannaColors.textMuted),
        )
      else
        for (final MapEntry(key: day, value: list) in days.entries) ...[
          Container(
            padding: const EdgeInsets.only(
              top: LannaSpacing.s3,
              bottom: LannaSpacing.s1,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: LannaColors.borderSubtle)),
            ),
            child: Text(
              _dayTitle(context, day),
              style: LannaType.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: LannaColors.textMuted,
              ),
            ),
          ),
          for (final entry in list) _EntryTile(entry: entry),
          const SizedBox(height: LannaSpacing.s2),
        ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(context.l10n.whatYouRead),
        const SizedBox(height: LannaSpacing.s4),
        if (scrollable)
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: items),
          )
        else
          ...items,
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(findBookProvider(entry.bookId)).valueOrNull;
    if (book == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final percent = (entry.progressed * 100).round();
    final detail = [
      formatReadingTime(entry.seconds),
      if (entry.pages > 0)
        l10n.pagesCount(entry.pages)
      else if (percent > 0)
        l10n.progressGained(percent),
    ].join(' · ');
    final tabular = LannaType.md.copyWith(
      color: LannaColors.textMuted,
      fontFeatures: LannaType.tabular,
    );
    return Pressable(
      scale: 0.99,
      onTap: () => openBook(context, book),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
        child: Row(
          children: [
            SizedBox(width: 36, child: BookCover(book: book)),
            const SizedBox(width: LannaSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 16,
                      height: 1.3,
                      color: LannaColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: tabular),
                ],
              ),
            ),
            const SizedBox(width: LannaSpacing.s3),
            Text(
              DateFormat.Hm(l10n.localeName).format(entry.startedAt),
              style: tabular,
            ),
          ],
        ),
      ),
    );
  }
}

class _Year extends StatelessWidget {
  const _Year({required this.stats, required this.finished, this.rows = 2});

  final ReadingStats stats;
  final List<Book> finished;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final year = '${stats.today.year}';
    final books = [...finished]
      ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
    final sentence = [
      l10n.yearSummary(
        formatReadingTime(stats.yearSeconds),
        l10n.finishedBooksCount(finished.length),
      ),
      if (stats.bestStreak > 0) l10n.bestStreakSentence(stats.bestStreak),
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.inYear(year)),
        const SizedBox(height: LannaSpacing.s2),
        Text(
          sentence,
          style: LannaType.base.copyWith(
            fontSize: 15,
            height: 1.6,
            color: LannaColors.text,
          ),
        ),
        if (books.isNotEmpty) ...[
          const SizedBox(height: LannaSpacing.s6),
          _Heading(l10n.finishedIn(year)),
          const SizedBox(height: LannaSpacing.s3),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = LannaSpacing.s3;
              final columns = math.max(
                4,
                ((constraints.maxWidth + gap) / (96 + gap)).floor(),
              );
              final cover =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final book in books.take(columns * rows))
                    SizedBox(
                      width: cover,
                      child: Pressable(
                        scale: 0.98,
                        onTap: () => openBook(context, book),
                        child: Tooltip(
                          message: book.title,
                          child: BookCover(book: book),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
