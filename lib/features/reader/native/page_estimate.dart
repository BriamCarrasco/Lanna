// SPDX-License-Identifier: GPL-3.0-or-later

class PageEstimate {
  const PageEstimate(this.current, this.total);

  final int current;
  final int total;
}

PageEstimate? estimatePage({
  required int chapter,
  required int pageInChapter,
  required List<int> weights,
  required Map<int, int> knownPages,
}) {
  var knownWeight = 0;
  var knownCount = 0;
  for (final entry in knownPages.entries) {
    if (entry.key < 0 || entry.key >= weights.length || entry.value <= 0) {
      continue;
    }
    knownWeight += weights[entry.key];
    knownCount += entry.value;
  }
  if (knownWeight <= 0 || knownCount <= 0) return null;
  final perWeight = knownCount / knownWeight;

  int pagesOf(int c) {
    final known = knownPages[c];
    if (known != null && known > 0) return known;
    final estimate = (weights[c] * perWeight).round();
    return estimate < 1 ? 1 : estimate;
  }

  var before = 0;
  var total = 0;
  for (var c = 0; c < weights.length; c++) {
    final pages = pagesOf(c);
    if (c < chapter) before += pages;
    total += pages;
  }
  final current = before + pageInChapter + 1;
  return PageEstimate(current, total < current ? current : total);
}
