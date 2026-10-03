// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/local/database_provider.dart';
import '../reader/reader_settings_provider.dart';
import 'reading_stats.dart';

final readingSessionsProvider = StreamProvider<List<ReadingSession>>((ref) {
  return ref.watch(appDatabaseProvider).watchSessionsSince(DateTime(2000));
});

final readingStatsProvider = Provider<AsyncValue<ReadingStats>>((ref) {
  final goal = ref.watch(
    readerSettingsProvider.select((s) => s.valueOrNull?.dailyGoalMinutes),
  );
  return ref
      .watch(readingSessionsProvider)
      .whenData(
        (sessions) => ReadingStats.compute(
          sessions: [
            for (final s in sessions) (start: s.startedAt, seconds: s.seconds),
          ],
          goalMinutes: goal ?? 20,
          now: DateTime.now(),
        ),
      );
});

final finishedThisYearProvider = StreamProvider<List<Book>>((ref) {
  final now = DateTime.now();
  return ref.watch(appDatabaseProvider).watchFinishedSince(DateTime(now.year));
});

class BookReading {
  const BookReading({required this.seconds, required this.progressed});

  final int seconds;
  final double progressed;
}

final bookReadingProvider = StreamProvider.family<BookReading, String>((
  ref,
  bookId,
) {
  return ref.watch(appDatabaseProvider).watchBookSessions(bookId).map((
    sessions,
  ) {
    var seconds = 0;
    var progressed = 0.0;
    for (final s in sessions) {
      seconds += s.seconds;
      final delta = s.endPercent - s.startPercent;
      if (delta > 0) progressed += delta;
    }
    return BookReading(seconds: seconds, progressed: progressed);
  });
});
