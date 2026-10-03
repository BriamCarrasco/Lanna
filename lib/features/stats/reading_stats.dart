// SPDX-License-Identifier: GPL-3.0-or-later

DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

class ReadingStats {
  const ReadingStats({
    required this.today,
    required this.goalSeconds,
    required this.byDay,
    required this.todaySeconds,
    required this.weekSeconds,
    required this.yearSeconds,
    required this.currentStreak,
    required this.bestStreak,
    required this.streakAlive,
  });

  factory ReadingStats.compute({
    required Iterable<({DateTime start, int seconds})> sessions,
    required int goalMinutes,
    required DateTime now,
  }) {
    final today = dayOf(now);
    final goal = goalMinutes * 60;
    final byDay = <DateTime, int>{};
    for (final s in sessions) {
      final day = dayOf(s.start);
      byDay[day] = (byDay[day] ?? 0) + s.seconds;
    }

    final monday = _mondayOf(today);
    var week = 0;
    var year = 0;
    for (final MapEntry(key: day, value: seconds) in byDay.entries) {
      if (!day.isBefore(monday) && !day.isAfter(today)) week += seconds;
      if (day.year == today.year) year += seconds;
    }

    bool met(DateTime day) => (byDay[day] ?? 0) >= goal;
    final todayMet = met(today);
    var current = 0;
    var cursor = todayMet ? today : _previous(today);
    while (met(cursor)) {
      current++;
      cursor = _previous(cursor);
    }

    var best = 0;
    var run = 0;
    DateTime? last;
    final days = byDay.keys.where(met).toList()..sort();
    for (final day in days) {
      run = last != null && _previous(day) == last ? run + 1 : 1;
      if (run > best) best = run;
      last = day;
    }

    return ReadingStats(
      today: today,
      goalSeconds: goal,
      byDay: byDay,
      todaySeconds: byDay[today] ?? 0,
      weekSeconds: week,
      yearSeconds: year,
      currentStreak: current,
      bestStreak: best,
      streakAlive: todayMet,
    );
  }

  final DateTime today;
  final int goalSeconds;
  final Map<DateTime, int> byDay;
  final int todaySeconds;
  final int weekSeconds;
  final int yearSeconds;
  final int currentStreak;
  final int bestStreak;
  final bool streakAlive;

  double get todayProgress =>
      goalSeconds == 0 ? 1 : (todaySeconds / goalSeconds).clamp(0, 1);

  int secondsOn(DateTime day) => byDay[dayOf(day)] ?? 0;

  int levelOn(DateTime day) {
    final seconds = secondsOn(day);
    if (seconds <= 0) return 0;
    if (seconds < goalSeconds / 2) return 1;
    if (seconds < goalSeconds) return 2;
    if (seconds < goalSeconds * 2) return 3;
    return 4;
  }

  List<DateTime> calendarWeeks({int weeks = 53}) {
    final monday = _mondayOf(today);
    return [
      for (var i = weeks - 1; i >= 0; i--)
        DateTime(monday.year, monday.month, monday.day - 7 * i),
    ];
  }

  static DateTime _mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  static DateTime _previous(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);
}

String formatReadingTime(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

Duration? remainingEstimate({
  required int seconds,
  required double progressed,
  required double percent,
}) {
  if (seconds < 300 || progressed < 0.02 || percent >= 1) return null;
  final perUnit = seconds / progressed;
  return Duration(seconds: (perUnit * (1 - percent)).round());
}
