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

bool matchesQuery(String haystack, String foldedQuery) {
  if (foldedQuery.isEmpty) return true;
  return foldForSearch(haystack).contains(foldedQuery);
}
