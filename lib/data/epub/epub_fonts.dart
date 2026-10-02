// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:path/path.dart' as p;

import 'epub_paths.dart';

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
  const EpubFontSheet({
    required this.faces,
    required this.preferred,
    this.skippedFormat = false,
  });

  final List<FontFace> faces;
  final String? preferred;
  final bool skippedFormat;

  bool get isEmpty => faces.isEmpty;

  Iterable<String> get families => {for (final f in faces) f.family};
}

abstract final class EpubFonts {
  static const _supported = {'.ttf', '.otf', '.ttc', '.woff'};

  static const unsupported = {'.woff2', '.eot', '.svg'};

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
    _skipped = false;
    final faces = <FontFace>[];
    final declared = <String>[];

    stylesheets.forEach((href, css) {
      faces.addAll(_facesIn(css, href));
      final family = _readingFamily(css);
      if (family != null) declared.add(family);
    });

    if (faces.isEmpty) {
      return EpubFontSheet(
        faces: const [],
        preferred: null,
        skippedFormat: _skipped,
      );
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

    return EpubFontSheet(
      faces: faces,
      preferred: preferred,
      skippedFormat: _skipped,
    );
  }

  static bool _skipped = false;

  static List<FontFace> _facesIn(String css, String cssHref) {
    final result = <FontFace>[];
    for (final block in _faceBlock.allMatches(css)) {
      final face = _faceFrom(block.group(1) ?? '', cssHref);
      if (face != null) result.add(face);
    }
    return result;
  }

  static FontFace? _faceFrom(String body, String cssHref) {
    String? family;
    String? source;
    var weight = 400;
    var italic = false;
    for (final decl in _declaration.allMatches(body)) {
      final value = decl.group(2)!.trim();
      switch (decl.group(1)!.toLowerCase()) {
        case 'font-family':
          family = _unquote(value);
        case 'src':
          source = _pickSource(value);
        case 'font-weight':
          weight = _weight(value);
        case 'font-style':
          italic = _isItalic(value);
      }
    }

    if (source == null && family != null && _hasUnsupported(body)) {
      _skipped = true;
    }
    if (family == null || family.isEmpty || source == null) return null;
    return FontFace(
      family: family,
      href: _resolve(source, cssHref),
      weight: weight,
      italic: italic,
    );
  }

  static bool _isItalic(String value) {
    final lower = value.toLowerCase();
    return lower.contains('italic') || lower.contains('oblique');
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

  static bool _hasUnsupported(String value) {
    for (final match in _url.allMatches(value)) {
      final url = match.group(1)!.trim();
      if (url.startsWith('data:')) continue;
      final ext = p.extension(url.split('?').first).toLowerCase();
      if (unsupported.contains(ext)) return true;
    }
    return false;
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
    final decoded = decodeHref(src.split('#').first.split('?').first);
    return p.url.normalize(p.url.join(p.url.dirname(cssHref), decoded));
  }
}
