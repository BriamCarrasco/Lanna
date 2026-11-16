// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/lanna_menu.dart';
import '../../l10n/l10n.dart';
import '../library/widgets/section_scaffold.dart';
import '../reader/reader_settings_provider.dart';
import '../reader/reader_theme.dart';
import 'reading_stats.dart';
import 'stats_providers.dart';

String _dayLabel(DateTime day, DateTime today, AppLocalizations l10n) {
  if (day == today) return l10n.today;
  return DateFormat(l10n.dayPattern, l10n.localeName).format(day);
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(readingStatsProvider).valueOrNull;
    final finished = ref.watch(finishedThisYearProvider).valueOrNull?.length;
    final empty = ref.watch(readingSessionsProvider).valueOrNull?.isEmpty;

    return SectionScaffold(
      title: context.l10n.stats,
      actions: const [_GoalButton()],
      child: stats == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                final gutter = constraints.maxWidth < 620
                    ? LannaSpacing.s4
                    : LannaSpacing.s6;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    gutter,
                    gutter,
                    LannaSpacing.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (empty ?? false) ...[
                        const _StartHint(),
                        const SizedBox(height: LannaSpacing.s4),
                      ],
                      _SummaryGrid(stats: stats, finished: finished ?? 0),
                      const SizedBox(height: LannaSpacing.s5),
                      _YearCard(stats: stats),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _GoalButton extends ConsumerWidget {
  const _GoalButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal =
        ref.watch(readerSettingsProvider).valueOrNull?.dailyGoalMinutes ?? 20;
    return PopupMenuButton<int>(
      initialValue: goal,
      tooltip: context.l10n.dailyGoal,
      position: PopupMenuPosition.under,
      onSelected: ref.read(readerSettingsControllerProvider).setDailyGoal,
      itemBuilder: (_) => [
        for (final minutes in ReaderSettings.dailyGoals)
          lannaChoiceItem(
            value: minutes,
            label: context.l10n.minutesPerDay(minutes),
            selected: minutes == goal,
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LannaSpacing.s3,
          vertical: LannaSpacing.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 18,
              color: LannaColors.textMuted,
            ),
            const SizedBox(width: LannaSpacing.s2),
            Text(
              context.l10n.goalMinutes(goal),
              style: LannaType.sm.copyWith(color: LannaColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartHint extends StatelessWidget {
  const _StartHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LannaSpacing.s4),
      decoration: const BoxDecoration(
        color: LannaColors.accentTint,
        borderRadius: LannaRadii.brLg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_outlined, color: LannaColors.accentStrong),
          const SizedBox(width: LannaSpacing.s3),
          Expanded(
            child: Text(
              context.l10n.statsEmptyHint,
              style: LannaType.sm.copyWith(color: LannaColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats, required this.finished});

  final ReadingStats stats;
  final int finished;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 880 ? 4 : (width >= 330 ? 2 : 1);
        const gap = LannaSpacing.s3;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in _cards(context))
              SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  List<Widget> _cards(BuildContext context) {
    final missing = math.max(0, stats.goalSeconds - stats.todaySeconds);
    final streak = stats.currentStreak;
    return [
      _StatCard(
        label: context.l10n.today,
        value: formatReadingTime(stats.todaySeconds),
        detail: missing == 0
            ? context.l10n.goalMet
            : context.l10n.timeMissing(formatReadingTime(missing)),
        leading: _GoalRing(progress: stats.todayProgress),
      ),
      _StatCard(
        label: context.l10n.streak,
        value: streak == 0
            ? context.l10n.noStreak
            : context.l10n.daysCount(streak),
        detail: stats.bestStreak > 0
            ? context.l10n.bestStreak(context.l10n.daysCount(stats.bestStreak))
            : context.l10n.streakHint,
        leading: Icon(
          Icons.local_fire_department_outlined,
          size: 26,
          color: stats.streakAlive
              ? LannaColors.accentStrong
              : LannaColors.textMuted,
        ),
      ),
      _StatCard(
        label: context.l10n.thisWeek,
        value: formatReadingTime(stats.weekSeconds),
        detail: context.l10n.sinceMonday,
      ),
      _StatCard(
        label: context.l10n.thisYear,
        value: formatReadingTime(stats.yearSeconds),
        detail: context.l10n.finishedBooksCount(finished),
      ),
    ];
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.detail,
    this.leading,
  });

  final String label;
  final String value;
  final String detail;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(LannaSpacing.s4),
      decoration: BoxDecoration(
        color: LannaColors.surfaceHigh,
        border: Border.all(color: LannaColors.border),
        borderRadius: LannaRadii.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.xs.copyWith(color: LannaColors.textMuted),
                  ),
                ),
                if (leading != null)
                  SizedBox.square(
                    dimension: 26,
                    child: FittedBox(child: leading),
                  ),
              ],
            ),
          ),
          const SizedBox(height: LannaSpacing.s1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LannaType.title.copyWith(color: LannaColors.textStrong),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LannaType.sm.copyWith(color: LannaColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: LannaMotion.slow,
      curve: LannaMotion.ease,
      builder: (context, value, _) => CustomPaint(
        size: const Size.square(26),
        painter: _RingPainter(value),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = LannaColors.surfaceActive
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..color = progress >= 1 ? LannaColors.success : LannaColors.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

Color _levelColor(int level) => switch (level) {
  0 => LannaColors.surfaceActive,
  1 => LannaColors.accent.withValues(alpha: 0.3),
  2 => LannaColors.accent.withValues(alpha: 0.55),
  3 => LannaColors.accent.withValues(alpha: 0.8),
  _ => LannaColors.accentStrong,
};

class _YearCard extends StatefulWidget {
  const _YearCard({required this.stats});

  final ReadingStats stats;

  @override
  State<_YearCard> createState() => _YearCardState();
}

class _YearCardState extends State<_YearCard> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final day = _selected ?? stats.today;
    final seconds = stats.secondsOn(day);
    return Container(
      padding: const EdgeInsets.all(LannaSpacing.s4),
      decoration: BoxDecoration(
        color: LannaColors.surfaceHigh,
        border: Border.all(color: LannaColors.border),
        borderRadius: LannaRadii.brLg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = constraints.maxWidth;
          final wide =
              inner >= _YearCalendar.fullWidth + 2 * _gap + _panelWidth;
          final space = wide ? _YearCalendar.fullWidth : inner;
          final weeks = _YearCalendar.weeksThatFit(space);
          final first = stats.calendarWeeks(weeks: weeks).first;
          final calendar = SizedBox(
            width: _YearCalendar.widthFor(weeks, space),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _YearCalendar(
                  stats: stats,
                  weeks: weeks,
                  selected: _selected,
                  onSelect: (d) => setState(() => _selected = d),
                ),
                const SizedBox(height: LannaSpacing.s3),
                const Align(alignment: Alignment.centerRight, child: _Legend()),
              ],
            ),
          );
          final panel = _YearPanel(
            stats: stats,
            day: day,
            seconds: seconds,
            daysRead: stats.daysReadSince(first),
            wide: wide,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.lastMonths(math.max(1, weeks * 7 ~/ 30.44)),
                style: LannaType.xs.copyWith(color: LannaColors.textMuted),
              ),
              const SizedBox(height: LannaSpacing.s3),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    calendar,
                    const SizedBox(width: _gap),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: _gap),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: LannaColors.border),
                          ),
                        ),
                        child: panel,
                      ),
                    ),
                  ],
                )
              else ...[
                Align(alignment: Alignment.centerLeft, child: calendar),
                const SizedBox(height: LannaSpacing.s4),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: LannaColors.border,
                ),
                const SizedBox(height: LannaSpacing.s4),
                panel,
              ],
            ],
          );
        },
      ),
    );
  }

  static const _gap = 28.0;
  static const _panelWidth = 260.0;
}

class _YearPanel extends StatelessWidget {
  const _YearPanel({
    required this.stats,
    required this.day,
    required this.seconds,
    required this.daysRead,
    required this.wide,
  });

  final ReadingStats stats;
  final DateTime day;
  final int seconds;
  final int daysRead;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = LannaType.sm.copyWith(color: LannaColors.textMuted);
    final value = LannaType.title.copyWith(color: LannaColors.textStrong);
    final isToday = day == stats.today;
    final missing = math.max(0, stats.goalSeconds - seconds);
    final String? note = !isToday && seconds > 0 && missing == 0
        ? l10n.goalMet
        : null;
    final dayBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_dayLabel(day, stats.today, l10n), style: label, maxLines: 1),
        const SizedBox(height: 2),
        Text(
          seconds == 0 ? l10n.noReading : formatReadingTime(seconds),
          style: value,
          maxLines: 1,
        ),
        if (note != null) Text(note, style: label, maxLines: 1),
      ],
    );
    final daysBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.daysWithReading, style: label, maxLines: 1),
        const SizedBox(height: 2),
        Text(l10n.daysCount(daysRead), style: value, maxLines: 1),
      ],
    );
    final months = _MonthBars(totals: stats.monthlyTotals(6));
    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          dayBlock,
          const SizedBox(height: LannaSpacing.s5),
          months,
          const SizedBox(height: LannaSpacing.s5),
          daysBlock,
        ],
      );
    }
    return Wrap(
      spacing: LannaSpacing.s6,
      runSpacing: LannaSpacing.s5,
      children: [
        SizedBox(width: 150, child: dayBlock),
        SizedBox(width: 150, child: daysBlock),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: months,
        ),
      ],
    );
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.totals});

  final List<({DateTime month, int seconds})> totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = LannaType.micro.copyWith(
      color: LannaColors.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final most = totals.fold(0, (m, t) => math.max(m, t.seconds));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.timePerMonth,
          style: LannaType.sm.copyWith(color: LannaColors.textMuted),
        ),
        const SizedBox(height: LannaSpacing.s2),
        for (final t in totals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    DateFormat.MMM(l10n.localeName).format(t.month),
                    style: muted,
                    maxLines: 1,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    child: SizedBox(
                      height: 6,
                      child: ColoredBox(
                        color: _levelColor(0),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: most == 0 ? 0 : t.seconds / most,
                          child: ColoredBox(color: _levelColor(3)),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    t.seconds == 0 ? '—' : formatReadingTime(t.seconds),
                    style: muted,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final muted = LannaType.micro.copyWith(color: LannaColors.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n.less, style: muted),
        const SizedBox(width: LannaSpacing.s1 + 2),
        for (var level = 0; level <= 4; level++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _levelColor(level),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
        const SizedBox(width: LannaSpacing.s1 + 2),
        Text(context.l10n.more, style: muted),
      ],
    );
  }
}

class _YearCalendar extends StatelessWidget {
  const _YearCalendar({
    required this.stats,
    required this.weeks,
    required this.selected,
    required this.onSelect,
  });

  final ReadingStats stats;
  final int weeks;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;

  static const _gap = 3.0;
  static const _labelWidth = 24.0;
  static const _labelHeight = 18.0;
  static const _minCell = 9.0;
  static const _maxCell = 13.0;
  static const _maxWeeks = 53;

  static double get fullWidth =>
      _labelWidth + _maxWeeks * (_maxCell + _gap) - _gap;

  static double widthFor(int weeks, double space) {
    final cell = ((space - _labelWidth + _gap) / weeks - _gap).clamp(
      _minCell,
      _maxCell,
    );
    return _labelWidth + weeks * (cell + _gap) - _gap;
  }

  static int weeksThatFit(double width) {
    final fit = ((width - _labelWidth + _gap) / (_minCell + _gap)).floor();
    return fit.clamp(1, _maxWeeks);
  }

  @override
  Widget build(BuildContext context) {
    final weeks = stats.calendarWeeks(weeks: this.weeks);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            (constraints.maxWidth - _labelWidth + _gap) / weeks.length - _gap;
        final cell = fit.clamp(_minCell, _maxCell);
        final layout = _CalendarLayout(
          weeks: weeks,
          cell: cell,
          gap: _gap,
          labelWidth: 0,
          labelHeight: _labelHeight,
        );
        final grid = MouseRegion(
          onHover: (e) => _pick(layout, e.localPosition),
          onExit: (_) => onSelect(null),
          child: GestureDetector(
            onTapDown: (e) => _pick(layout, e.localPosition),
            child: CustomPaint(
              size: layout.size,
              painter: _CalendarPainter(
                stats: stats,
                layout: layout,
                selected: selected,
                locale: context.l10n.localeName,
              ),
            ),
          ),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WeekdayLabels(layout: layout, width: _labelWidth),
            Flexible(child: grid),
          ],
        );
      },
    );
  }

  void _pick(_CalendarLayout layout, Offset position) {
    final day = layout.dayAt(position);
    if (day == null || day.isAfter(stats.today)) return;
    if (day != selected) onSelect(day);
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels({required this.layout, required this.width});

  static const _height = 16.0;

  final _CalendarLayout layout;
  final double width;

  @override
  Widget build(BuildContext context) {
    final style = LannaType.micro.copyWith(color: LannaColors.textMuted);
    return SizedBox(
      width: width,
      height: layout.size.height,
      child: Stack(
        children: [
          for (final (row, text) in [
            (0, context.l10n.weekdayFirst),
            (2, context.l10n.weekdayThird),
            (4, context.l10n.weekdayFifth),
          ])
            Positioned(
              left: 0,
              right: 0,
              top: layout.cellRect(0, row).center.dy - _height / 2,
              height: _height,
              child: Center(child: Text(text, style: style, maxLines: 1)),
            ),
        ],
      ),
    );
  }
}

class _CalendarLayout {
  const _CalendarLayout({
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.labelWidth,
    required this.labelHeight,
  });

  final List<DateTime> weeks;
  final double cell;
  final double gap;
  final double labelWidth;
  final double labelHeight;

  double get step => cell + gap;

  Size get size => Size(
    labelWidth + weeks.length * step - gap,
    labelHeight + 7 * step - gap,
  );

  Rect cellRect(int week, int weekday) => Rect.fromLTWH(
    labelWidth + week * step,
    labelHeight + weekday * step,
    cell,
    cell,
  );

  DateTime? dayAt(Offset position) {
    final week = ((position.dx - labelWidth) / step).floor();
    final weekday = ((position.dy - labelHeight) / step).floor();
    if (week < 0 || week >= weeks.length || weekday < 0 || weekday > 6) {
      return null;
    }
    final monday = weeks[week];
    return DateTime(monday.year, monday.month, monday.day + weekday);
  }
}

class _CalendarPainter extends CustomPainter {
  _CalendarPainter({
    required this.stats,
    required this.layout,
    required this.selected,
    required this.locale,
  });

  final String locale;
  final ReadingStats stats;
  final _CalendarLayout layout;
  final DateTime? selected;

  @override
  void paint(Canvas canvas, Size size) {
    _paintMonthLabels(canvas);
    _paintCells(canvas);
  }

  void _paintCells(Canvas canvas) {
    final paint = Paint();
    final radius = Radius.circular(layout.cell / 5);
    for (var w = 0; w < layout.weeks.length; w++) {
      final monday = layout.weeks[w];
      for (var d = 0; d < 7; d++) {
        final day = DateTime(monday.year, monday.month, monday.day + d);
        if (day.isAfter(stats.today)) break;
        final rect = RRect.fromRectAndRadius(layout.cellRect(w, d), radius);
        paint.color = _levelColor(stats.levelOn(day));
        canvas.drawRRect(rect, paint);
        if (day == selected || (selected == null && day == stats.today)) {
          canvas.drawRRect(
            rect.inflate(1.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = LannaColors.textStrong,
          );
        }
      }
    }
  }

  void _paintMonthLabels(Canvas canvas) {
    var lastRight = double.negativeInfinity;
    for (var w = 0; w < layout.weeks.length; w++) {
      final month =
          _monthStartingIn(layout.weeks[w]) ??
          (w == 0 ? layout.weeks[w].month : null);
      if (month == null) continue;
      final painter = _label(
        DateFormat.MMM(locale).format(DateTime(2000, month)),
      );
      final x = math.min(
        layout.labelWidth + w * layout.step,
        layout.size.width - painter.width,
      );
      if (x < lastRight + 4) continue;
      painter.paint(canvas, Offset(x, 0));
      lastRight = x + painter.width;
    }
  }

  static int? _monthStartingIn(DateTime monday) {
    for (var d = 0; d < 7; d++) {
      final day = DateTime(monday.year, monday.month, monday.day + d);
      if (day.day == 1) return day.month;
    }
    return null;
  }

  TextPainter _label(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: LannaType.micro.copyWith(color: LannaColors.textMuted),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_CalendarPainter old) =>
      old.stats != stats ||
      old.selected != selected ||
      old.layout.cell != layout.cell;
}
