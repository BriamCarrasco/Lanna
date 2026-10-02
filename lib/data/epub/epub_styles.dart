// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:html/dom.dart' as dom;

enum CssUnit { percent, em, px }

class CssLength {
  const CssLength(this.value, this.unit);

  final double value;
  final CssUnit unit;

  static final _pattern = RegExp(r'^(\d*\.?\d+)\s*(%|r?em|px)?$');

  static CssLength? parse(String raw) {
    final match = _pattern.firstMatch(raw.trim().toLowerCase());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || value <= 0) return null;
    return CssLength(value, switch (match.group(2)) {
      '%' => CssUnit.percent,
      'em' || 'rem' => CssUnit.em,
      _ => CssUnit.px,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is CssLength && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => '$value${unit.name}';
}

class EpubStyles {
  const EpubStyles._(this._widths);

  static const empty = EpubStyles._({});

  final Map<String, CssLength?> _widths;

  static final _comment = RegExp(r'/\*.*?\*/', dotAll: true);
  static final _rule = RegExp(r'([^{}]+)\{([^{}]*)\}');
  static final _simpleSelector = RegExp(r'^[a-z0-9]*(\.[\w-]+)?$');
  static final _width = RegExp(r'(?:^|[;\s])width\s*:\s*([^;!]+)');

  factory EpubStyles.parse(Iterable<String> sheets) {
    final widths = <String, CssLength?>{};
    for (final sheet in sheets) {
      final css = sheet.replaceAll(_comment, '');
      for (final rule in _rule.allMatches(css)) {
        final declared = _widthIn(rule.group(2)!);
        if (declared == null) continue;
        for (final raw in rule.group(1)!.split(',')) {
          final selector = raw.trim().toLowerCase();
          if (selector.isEmpty || !_simpleSelector.hasMatch(selector)) {
            continue;
          }
          widths[selector] = declared.length;
        }
      }
    }
    return widths.isEmpty ? empty : EpubStyles._(widths);
  }

  static ({CssLength? length})? _widthIn(String body) {
    final match = _width.firstMatch(body.toLowerCase());
    if (match == null) return null;
    return (length: CssLength.parse(match.group(1)!));
  }

  CssLength? widthOf(dom.Element node, {bool attribute = false}) {
    final inline = _widthIn(node.attributes['style'] ?? '');
    if (inline != null) return inline.length;
    final tag = node.localName?.toLowerCase() ?? '';
    final classes = node.classes.map((c) => c.toLowerCase()).toList();
    for (final key in [
      for (final c in classes.reversed) '$tag.$c',
      for (final c in classes.reversed) '.$c',
    ]) {
      if (_widths.containsKey(key)) return _widths[key];
    }
    if (attribute) {
      final declared = node.attributes['width'];
      if (declared != null) return CssLength.parse(declared);
    }
    return _widths[tag];
  }
}
