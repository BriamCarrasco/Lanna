// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:path/path.dart' as p;

class FontFace {
  const FontFace({
    required this.family,
    required this.href,
    this.weight = 400,
    this.italic = false,
  });

  final String family;
  final String href;
  final int weight;
  final bool italic;

  @override
  String toString() =>
      'FontFace($family, $href, $weight${italic ? ', italic' : ''})';
}

class EpubFontSheet {
  const EpubFontSheet({required this.faces, required this.preferred});

  final List<FontFace> faces;
  final String? preferred;

  bool get isEmpty => faces.isEmpty;

  Iterable<String> get families => {for (final f in faces) f.family};
}

abstract final class EpubFonts {
  static const _supported = {'.ttf', '.otf', '.ttc'};

  static final _faceBlock = RegExp(
    r'@font-face\s*\{([^}]*)\}',
    caseSensitive: false,
  );
  static final _declaration = RegExp(r'([a-zA-Z-]+)\s*:\s*([^;]+)');
  static final _url = RegExp(r'''url\(\s*['"]?([^'")]+)['"]?\s*\)''');
  static final _bodyRule = RegExp(
    r'(?:^|\})\s*([^{}@]*)\{([^}]*)\}',
    multiLine: true,
  );

  static EpubFontSheet parse(Map<String, String> stylesheets) {
    final faces = <FontFace>[];
    final declared = <String>[];

    stylesheets.forEach((href, css) {
      faces.addAll(_facesIn(css, href));
      final family = _readingFamily(css);
      if (family != null) declared.add(family);
    });

    if (faces.isEmpty) {
      return const EpubFontSheet(faces: [], preferred: null);
    }

    final available = {for (final f in faces) f.family};
    String? preferred;
    for (final candidate in declared) {
      final match = available.firstWhere(
        (f) => f.toLowerCase() == candidate.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        preferred = match;
        break;
      }
    }

    if (preferred == null) {
      final counts = <String, int>{};
      for (final face in faces) {
        counts[face.family] = (counts[face.family] ?? 0) + 1;
      }
      final ranked = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      preferred = ranked.first.key;
    }

    return EpubFontSheet(faces: faces, preferred: preferred);
  }

  static List<FontFace> _facesIn(String css, String cssHref) {
    final result = <FontFace>[];
    for (final block in _faceBlock.allMatches(css)) {
      final body = block.group(1) ?? '';
      String? family;
      String? source;
      var weight = 400;
      var italic = false;

      for (final decl in _declaration.allMatches(body)) {
        final name = decl.group(1)!.toLowerCase();
        final value = decl.group(2)!.trim();
        switch (name) {
          case 'font-family':
            family = _unquote(value);
          case 'src':
            source = _pickSource(value);
          case 'font-weight':
            weight = _weight(value);
          case 'font-style':
            italic =
                value.toLowerCase().contains('italic') ||
                value.toLowerCase().contains('oblique');
        }
      }

      if (family == null || family.isEmpty || source == null) continue;
      result.add(
        FontFace(
          family: family,
          href: _resolve(source, cssHref),
          weight: weight,
          italic: italic,
        ),
      );
    }
    return result;
  }

  static String? _pickSource(String value) {
    for (final match in _url.allMatches(value)) {
      final url = match.group(1)!.trim();
      if (url.startsWith('data:')) continue;
      final ext = p.extension(url.split('?').first).toLowerCase();
      if (_supported.contains(ext)) return url;
    }
    return null;
  }

  static String? _readingFamily(String css) {
    for (final rule in _bodyRule.allMatches(css)) {
      final selector = (rule.group(1) ?? '').toLowerCase();
      if (selector.contains('@font-face')) continue;
      final targets = selector
          .split(',')
          .map((s) => s.trim().split(RegExp(r'[\s>]')).last)
          .toSet();
      if (!targets.contains('body') &&
          !targets.contains('p') &&
          !targets.contains('html')) {
        continue;
      }
      final body = rule.group(2) ?? '';
      for (final decl in _declaration.allMatches(body)) {
        if (decl.group(1)!.toLowerCase() != 'font-family') continue;
        final first = decl.group(2)!.split(',').first;
        final name = _unquote(first.trim());
        if (name.isNotEmpty && !_generic.contains(name.toLowerCase())) {
          return name;
        }
      }
    }
    return null;
  }

  static const _generic = {
    'serif',
    'sans-serif',
    'monospace',
    'cursive',
    'fantasy',
    'system-ui',
    'inherit',
    'initial',
  };

  static int _weight(String value) {
    final lower = value.toLowerCase().trim();
    if (lower == 'bold') return 700;
    if (lower == 'normal') return 400;
    final parsed = int.tryParse(lower);
    if (parsed == null) return 400;
    return parsed.clamp(100, 900);
  }

  static String _unquote(String value) =>
      value.trim().replaceAll('"', '').replaceAll("'", '').trim();

  static String _resolve(String src, String cssHref) {
    final decoded = Uri.decodeFull(src.split('#').first.split('?').first);
    return p.url.normalize(p.url.join(p.url.dirname(cssHref), decoded));
  }
}
