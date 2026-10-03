// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/stats/reading_stats.dart';

void main() {
  ({DateTime start, int seconds}) read(DateTime day, int minutes) => (
    start: DateTime(day.year, day.month, day.day, 21),
    seconds: minutes * 60,
  );

  final today = DateTime(2026, 10, 2, 22);

  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  ReadingStats stats(List<({DateTime start, int seconds})> sessions) =>
      ReadingStats.compute(sessions: sessions, goalMinutes: 20, now: today);

  test('la racha sigue viva si hoy todavía no se cumple la meta', () {
    final s = stats([
      read(daysAgo(1), 25),
      read(daysAgo(2), 30),
      read(daysAgo(3), 5),
      read(today, 10),
    ]);

    expect(s.currentStreak, 2);
    expect(s.streakAlive, isFalse);
    expect(s.todaySeconds, 600);
  });

  test('cumplir la meta hoy suma el día a la racha', () {
    final s = stats([read(daysAgo(1), 25), read(today, 12), read(today, 12)]);

    expect(s.currentStreak, 2);
    expect(s.streakAlive, isTrue);
    expect(s.todayProgress, 1);
  });

  test('un día sin meta corta la racha y se recuerda la mejor', () {
    final s = stats([
      read(daysAgo(10), 20),
      read(daysAgo(9), 20),
      read(daysAgo(8), 20),
      read(daysAgo(2), 20),
    ]);

    expect(s.currentStreak, 0);
    expect(s.bestStreak, 3);
  });

  test('la semana cuenta desde el lunes', () {
    final s = stats([
      read(DateTime(2026, 9, 27), 30),
      read(DateTime(2026, 9, 28), 15),
      read(DateTime(2026, 10, 1), 15),
    ]);

    expect(s.weekSeconds, 30 * 60);
    expect(s.yearSeconds, 60 * 60);
  });

  test('las rachas atraviesan el cambio de hora sin cortarse', () {
    final dst = DateTime(2026, 9, 7, 12);
    final s = ReadingStats.compute(
      sessions: [for (var d = 3; d <= 10; d++) read(DateTime(2026, 9, d), 20)],
      goalMinutes: 20,
      now: dst.add(const Duration(days: 3)),
    );

    expect(s.currentStreak, 8);
  });

  test('el nivel del calendario depende de la meta', () {
    final s = stats([
      read(daysAgo(1), 5),
      read(daysAgo(2), 15),
      read(daysAgo(3), 25),
      read(daysAgo(4), 60),
    ]);

    expect(s.levelOn(daysAgo(0)), 0);
    expect(s.levelOn(daysAgo(1)), 1);
    expect(s.levelOn(daysAgo(2)), 2);
    expect(s.levelOn(daysAgo(3)), 3);
    expect(s.levelOn(daysAgo(4)), 4);
  });

  test('el calendario termina en la semana actual y empieza en lunes', () {
    final weeks = stats([]).calendarWeeks();

    expect(weeks, hasLength(53));
    expect(weeks.last, DateTime(2026, 9, 28));
    expect(weeks.every((w) => w.weekday == DateTime.monday), isTrue);
  });

  test('el tiempo se escribe en minutos y horas', () {
    expect(formatReadingTime(0), '0 min');
    expect(formatReadingTime(25 * 60), '25 min');
    expect(formatReadingTime(2 * 3600), '2 h');
    expect(formatReadingTime(2 * 3600 + 15 * 60), '2 h 15 min');
  });

  test('la estimación de lo que falta necesita datos suficientes', () {
    expect(
      remainingEstimate(seconds: 100, progressed: 0.5, percent: 0.5),
      isNull,
    );
    expect(
      remainingEstimate(seconds: 3600, progressed: 0.25, percent: 0.5),
      const Duration(hours: 2),
    );
  });
}
