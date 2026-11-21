// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

class PageNumber {
  const PageNumber(this.current, this.total);

  final int current;
  final int? total;
}

PageNumber? pageNumber({
  required int chapter,
  required int pageInChapter,
  required int chapterCount,
  required int? Function(int chapter) pagesOf,
}) {
  var before = 0;
  for (var c = 0; c < chapter; c++) {
    final pages = pagesOf(c);
    if (pages == null) return null;
    before += pages;
  }
  final current = before + pageInChapter + 1;
  var total = before;
  for (var c = chapter; c < chapterCount; c++) {
    final pages = pagesOf(c);
    if (pages == null) return PageNumber(current, null);
    total += pages;
  }
  return PageNumber(current, total < current ? current : total);
}

class PageCounts {
  PageCounts(this.chapterCount);

  final int chapterCount;
  final Map<int, int> _counts = {};

  int? of(int chapter) => _counts[chapter];

  bool get isComplete => _counts.length >= chapterCount;

  bool record(int chapter, int pages) {
    if (chapter < 0 || chapter >= chapterCount) return false;
    final value = pages < 1 ? 1 : pages;
    if (_counts[chapter] == value) return false;
    _counts[chapter] = value;
    return true;
  }

  int? nextMissing(int current) {
    for (var c = current - 1; c >= 0; c--) {
      if (!_counts.containsKey(c)) return c;
    }
    for (var c = current < 0 ? 0 : current; c < chapterCount; c++) {
      if (!_counts.containsKey(c)) return c;
    }
    return null;
  }

  List<int>? toList() =>
      isComplete ? [for (var c = 0; c < chapterCount; c++) _counts[c]!] : null;

  bool restore(List<int> saved) {
    if (saved.length != chapterCount || saved.any((n) => n < 1)) return false;
    for (var c = 0; c < chapterCount; c++) {
      _counts[c] = saved[c];
    }
    return true;
  }
}

class PageCountStore {
  PageCountStore(this.file);

  static const int version = 2;
  static const int maxLayouts = 8;

  final File file;

  Future<List<({String key, List<int> counts})>> _load() async {
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['version'] != version) return [];
      final layouts = data['layouts'];
      if (layouts is! List) return [];
      return [
        for (final entry in layouts)
          if (entry is Map && entry['key'] is String && entry['counts'] is List)
            (
              key: entry['key'] as String,
              counts: [
                for (final n in entry['counts'] as List)
                  if (n is int) n,
              ],
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<List<int>?> read(String key) async {
    for (final layout in await _load()) {
      if (layout.key == key) return layout.counts;
    }
    return null;
  }

  Future<void> write(String key, List<int> counts) async {
    final layouts = [
      (key: key, counts: counts),
      for (final layout in await _load())
        if (layout.key != key) layout,
    ];
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'version': version,
          'layouts': [
            for (final layout in layouts.take(maxLayouts))
              {'key': layout.key, 'counts': layout.counts},
          ],
        }),
      );
    } catch (_) {}
  }
}
