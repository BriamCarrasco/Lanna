// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'reading_stats.dart';

const barRest = Color(0xFF34313B);
const barMet = Color(0xFF8B8579);

Color barColor({
  required int seconds,
  required int goal,
  bool current = false,
}) => switch ((seconds, current)) {
  (0, _) => LannaColors.borderSubtle,
  (_, true) => LannaColors.accent,
  _ when seconds >= goal => barMet,
  _ => barRest,
};

class BarColumn extends StatelessWidget {
  const BarColumn({
    super.key,
    required this.fraction,
    required this.color,
    required this.maxHeight,
    this.width = 20,
  });

  final double fraction;
  final Color color;
  final double maxHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final empty = fraction <= 0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: empty ? width + 8 : width,
        height: empty ? 2 : math.max(3, maxHeight * fraction.clamp(0, 1)),
        decoration: BoxDecoration(
          color: color,
          borderRadius: empty
              ? BorderRadius.circular(1)
              : const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    );
  }
}

class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.stats,
    required this.days,
    required this.height,
    this.barWidth = 20,
    this.goalLine = false,
  });

  final ReadingStats stats;
  final List<DateTime> days;
  final double height;
  final double barWidth;
  final bool goalLine;

  @override
  Widget build(BuildContext context) {
    final goal = math.max(stats.goalSeconds, 1);
    final best = days.map(stats.secondsOn).fold<int>(0, math.max);
    final top = math.max(goal, best) * 1.1;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          if (goalLine)
            Positioned(
              left: 0,
              right: 0,
              bottom: height * goal / top,
              child: const _DottedLine(),
            ),
          Positioned.fill(
            child: Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: BarColumn(
                      fraction: stats.secondsOn(day) / top,
                      maxHeight: height,
                      width: barWidth,
                      color: barColor(
                        seconds: stats.secondsOn(day),
                        goal: goal,
                        current: day == stats.today,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 6).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 2,
                height: 1,
                margin: const EdgeInsets.only(right: 4),
                color: LannaColors.textMuted.withValues(alpha: 0.45),
              ),
          ],
        );
      },
    );
  }
}
