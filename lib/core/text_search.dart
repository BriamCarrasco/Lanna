// SPDX-License-Identifier: GPL-3.0-or-later
const _from = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
const _to = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

String foldForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final idx = _from.indexOf(ch);
    buffer.write(idx == -1 ? ch : _to[idx]);
  }
  return buffer.toString().toLowerCase().trim();
}

final _spaces = RegExp(r'\s+');

bool matchesQuery(String haystack, String foldedQuery) {
  if (foldedQuery.isEmpty) return true;
  final folded = foldForSearch(haystack);
  return foldedQuery
      .split(_spaces)
      .every((word) => word.isEmpty || folded.contains(word));
}
