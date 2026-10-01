// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:path/path.dart' as p;

final _leadingTags = RegExp(r'^(\s*[\[(][^\])]*[\])]\s*)+');
final _volumeMarker = RegExp(
  r'[\s\-–—_.,:]*(?:\b(?:tomo|tome|vol(?:ume|umen)?|v|t|n[ºo°]|no|num|libro|book|parte|part)\.?|#)\s*\d+.*$',
  caseSensitive: false,
);
final _trailingNumber = RegExp(
  r'[\s\-–—_.,:]+\d+(?:\s*[\[(][^\])]*[\])])*\s*$',
);
final _trailingTags = RegExp(r'(\s*[\[(][^\])]*[\])]\s*)+$');
final _edges = RegExp(r'^[\s\-–—_.,:]+|[\s\-–—_.,:]+$');

String? seriesFromFileName(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  var name = p.posix.basenameWithoutExtension(normalized);
  name = name.replaceAll('_', ' ');
  name = name.replaceFirst(_leadingTags, '');
  final marked = name.replaceFirst(_volumeMarker, '');
  name = marked != name
      ? marked
      : name.replaceFirst(_trailingTags, '').replaceFirst(_trailingNumber, '');
  name = name.replaceFirst(_trailingTags, '').replaceAll(_edges, '').trim();
  if (name.isNotEmpty && RegExp(r'\D').hasMatch(name)) return name;

  final parent = p.posix.dirname(normalized);
  if (parent == '.' || parent.isEmpty) return null;
  final folder = p.posix.basename(parent).trim();
  return folder.isEmpty ? null : folder;
}
