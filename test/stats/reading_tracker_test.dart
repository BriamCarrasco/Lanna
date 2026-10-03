// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:lanna/features/stats/reading_tracker.dart';

void main() {
  late DateTime now;
  late List<ReadingSpan> spans;
  late ReadingTracker tracker;

  setUp(() {
    now = DateTime(2026, 10, 2, 21);
    spans = [];
    tracker = ReadingTracker(onSpan: spans.add, clock: () => now);
  });

  void wait(Duration d) => now = now.add(d);

  test('suma el tiempo entre actividades y lo guarda al pausar', () {
    tracker.activity(percent: 0.40);
    wait(const Duration(minutes: 2));
    tracker.activity(percent: 0.41, turned: true);
    wait(const Duration(minutes: 1));
    tracker.activity(percent: 0.42, turned: true);
    wait(const Duration(seconds: 30));
    tracker.pause();

    expect(spans, hasLength(1));
    final span = spans.single;
    expect(span.seconds, 210);
    expect(span.startPercent, 0.40);
    expect(span.endPercent, 0.42);
    expect(span.pages, 2);
    expect(span.start, DateTime(2026, 10, 2, 21));
  });

  test(
    'tras 5 minutos sin actividad no cuenta el hueco y abre otra sesión',
    () {
      tracker.activity(percent: 0.1);
      wait(const Duration(minutes: 3));
      tracker.activity(percent: 0.11, turned: true);
      wait(const Duration(minutes: 40));
      tracker.activity(percent: 0.12, turned: true);
      wait(const Duration(minutes: 2));
      tracker.pause();

      expect(spans.map((s) => s.seconds), [180, 120]);
      expect(spans.last.startPercent, 0.11);
      expect(spans.last.endPercent, 0.12);
    },
  );

  test('una pausa larga antes de cerrar no suma ese tiempo', () {
    tracker.activity();
    wait(const Duration(minutes: 1));
    tracker.activity();
    wait(const Duration(minutes: 30));
    tracker.pause();

    expect(spans.single.seconds, 60);
  });

  test('las sesiones de menos de 10 segundos se descartan', () {
    tracker.activity();
    wait(const Duration(seconds: 6));
    tracker.pause();

    expect(spans, isEmpty);
    expect(tracker.running, isFalse);
  });

  test('una sesión que cruza la medianoche se corta en dos días', () {
    now = DateTime(2026, 10, 2, 23, 58);
    tracker.activity();
    wait(const Duration(minutes: 1));
    tracker.activity();
    wait(const Duration(minutes: 2));
    tracker.activity();
    wait(const Duration(minutes: 1));
    tracker.pause();

    expect(spans, hasLength(2));
    expect(spans.first.start.day, 2);
    expect(spans.first.seconds, 180);
    expect(spans.last.start.day, 3);
    expect(spans.last.seconds, 60);
  });

  test('pausar dos veces no duplica la sesión', () {
    tracker.activity();
    wait(const Duration(minutes: 1));
    tracker.pause();
    tracker.pause();

    expect(spans, hasLength(1));
  });
}
