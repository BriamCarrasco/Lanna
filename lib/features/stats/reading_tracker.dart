// SPDX-License-Identifier: GPL-3.0-or-later

class ReadingSpan {
  const ReadingSpan({
    required this.start,
    required this.seconds,
    required this.startPercent,
    required this.endPercent,
    required this.pages,
  });

  final DateTime start;
  final int seconds;
  final double startPercent;
  final double endPercent;
  final int pages;
}

class ReadingTracker {
  ReadingTracker({
    required this.onSpan,
    this.idle = const Duration(minutes: 5),
    this.minimum = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final void Function(ReadingSpan span) onSpan;
  final Duration idle;
  final Duration minimum;
  final DateTime Function() _clock;

  DateTime? _start;
  DateTime? _last;
  Duration _active = Duration.zero;
  double _startPercent = 0;
  double? _percent;
  int _pages = 0;

  bool get running => _last != null;

  void activity({double? percent, bool turned = false}) {
    final now = _clock();
    final last = _last;
    if (last != null) {
      final gap = now.difference(last);
      if (gap > idle) {
        _emit();
      } else {
        _active += gap;
        if (!_sameDay(_start!, now)) _emit();
      }
    }
    if (_last == null) _open(now, percent);
    _last = now;
    if (percent != null) _percent = percent;
    if (turned) _pages++;
  }

  void pause() {
    final last = _last;
    if (last == null) return;
    final gap = _clock().difference(last);
    if (gap <= idle) _active += gap;
    _emit();
  }

  void _open(DateTime now, double? percent) {
    _start = now;
    _active = Duration.zero;
    _startPercent = _percent ?? percent ?? 0;
    _pages = 0;
  }

  void _emit() {
    final start = _start;
    _last = null;
    _start = null;
    if (start == null || _active < minimum) return;
    onSpan(
      ReadingSpan(
        start: start,
        seconds: _active.inSeconds,
        startPercent: _startPercent,
        endPercent: _percent ?? _startPercent,
        pages: _pages,
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
