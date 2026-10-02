// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'epub_paths.dart';
import 'epub_styles.dart';

const String objectReplacement = '￼';

enum BlockKind {
  paragraph,
  heading,
  image,
  quote,
  listItem,
  separator,
  pageBreak,
  preformatted,
}

enum InlineMark { bold, italic, code, superscript, subscript }

enum BlockAlign { start, center, end, justify }

class InlineRun {
  const InlineRun({
    required this.text,
    required this.start,
    this.marks = const {},
    this.href,
  });

  final String text;
  final int start;
  final Set<InlineMark> marks;
  final String? href;

  int get end => start + text.length;

  @override
  String toString() => 'InlineRun($start, "$text", $marks)';
}

class DocBlock {
  const DocBlock({
    required this.kind,
    required this.start,
    required this.end,
    this.runs = const [],
    this.level = 0,
    this.align = BlockAlign.start,
    this.id,
    this.src,
    this.alt,
    this.listOrdered = false,
    this.listIndex = 0,
    this.rtl = false,
    this.width,
    this.boxFraction = 1,
  });

  final BlockKind kind;
  final int start;
  final int end;
  final List<InlineRun> runs;
  final int level;
  final BlockAlign align;
  final String? id;
  final String? src;
  final String? alt;
  final bool listOrdered;
  final int listIndex;
  final bool rtl;
  final CssLength? width;
  final double boxFraction;

  bool get isEmpty => end == start;

  String get text => runs.map((r) => r.text).join();

  @override
  String toString() => 'DocBlock(${kind.name}, $start..$end)';
}

class EpubDocument {
  EpubDocument({
    required this.spineIndex,
    required this.href,
    required this.blocks,
    required this.anchors,
    required this.length,
    this.rtl = false,
  });

  final int spineIndex;
  final String href;
  final List<DocBlock> blocks;
  final Map<String, int> anchors;
  final int length;
  final bool rtl;

  late final String text = _buildText();

  String _buildText() {
    final buffer = StringBuffer();
    for (final block in blocks) {
      for (final run in block.runs) {
        buffer.write(run.text);
      }
    }
    return buffer.toString();
  }

  int offsetForAnchor(String? fragment) {
    if (fragment == null || fragment.isEmpty) return 0;
    return anchors[fragment] ?? 0;
  }

  DocBlock? blockAt(int offset) {
    for (final block in blocks) {
      if (offset >= block.start && offset < block.end) return block;
    }
    return blocks.isEmpty ? null : blocks.last;
  }
}

abstract final class EpubDocumentParser {
  static EpubDocument parseBytes(
    Uint8List bytes, {
    required int spineIndex,
    required String href,
    bool rtl = false,
    EpubStyles styles = EpubStyles.empty,
  }) => parse(
    _decode(bytes),
    spineIndex: spineIndex,
    href: href,
    rtl: rtl,
    styles: styles,
  );

  static EpubDocument parse(
    String source, {
    required int spineIndex,
    required String href,
    bool rtl = false,
    EpubStyles styles = EpubStyles.empty,
  }) {
    final document = html_parser.parse(source);
    final root = document.documentElement;
    final body = document.body ?? root;
    final declared = _dirOf(root) ?? _dirOf(document.body);
    final builder = _Builder(href, declared ?? rtl, styles);
    if (body != null) builder.visit(body);
    builder.flush();
    return EpubDocument(
      spineIndex: spineIndex,
      href: href,
      blocks: List.unmodifiable(builder.blocks),
      anchors: Map.unmodifiable(builder.anchors),
      length: builder.offset,
      rtl: declared ?? rtl,
    );
  }

  static bool? _dirOf(dom.Element? node) =>
      switch (node?.attributes['dir']?.toLowerCase().trim()) {
        'rtl' => true,
        'ltr' => false,
        _ => null,
      };

  static String _decode(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes, 2, littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes, 2, littleEndian: false);
    }

    return switch (declaredEncoding(bytes)) {
      'iso-8859-1' || 'latin1' || 'iso8859-1' => latin1.decode(bytes),
      'windows-1252' || 'cp1252' => _cp1252(bytes),
      _ => utf8.decode(bytes, allowMalformed: true),
    };
  }

  static final _encodingPattern = RegExp(
    r'''(?:encoding|charset)\s*=\s*["']?\s*([A-Za-z0-9_-]+)''',
    caseSensitive: false,
  );

  static String? declaredEncoding(Uint8List bytes) {
    final head = latin1.decode(
      bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
      allowInvalid: true,
    );
    final match = _encodingPattern.firstMatch(head);
    return match?.group(1)?.toLowerCase();
  }

  static const _cp1252High = [
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
    0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
  ];

  static String _cp1252(Uint8List bytes) => String.fromCharCodes([
    for (final b in bytes)
      if (b >= 0x80 && b <= 0x9F) _cp1252High[b - 0x80] else b,
  ]);

  static String _utf16(
    Uint8List bytes,
    int from, {
    required bool littleEndian,
  }) {
    final units = <int>[];
    for (var i = from; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}

const _skipped = {
  'script',
  'style',
  'head',
  'title',
  'link',
  'meta',
  'noscript',
  'template',
};

const _promotable = {
  'div',
  'section',
  'article',
  'aside',
  'nav',
  'main',
  'header',
  'footer',
  'figure',
};

const _inlineTags = {
  'span',
  'a',
  'b',
  'strong',
  'i',
  'em',
  'cite',
  'dfn',
  'var',
  'code',
  'kbd',
  'samp',
  'tt',
  'sup',
  'sub',
  'small',
  'big',
  'u',
  's',
  'strike',
  'abbr',
  'acronym',
  'q',
  'br',
  'ruby',
  'rt',
  'rp',
  'bdi',
  'bdo',
  'wbr',
  'font',
  'mark',
  'ins',
  'del',
  'label',
  'time',
  'data',
  'nobr',
};

const _containers = {
  'ul',
  'ol',
  'dl',
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'body',
  'html',
};

const _leafBlocks = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'blockquote',
  'pre',
  'figcaption',
  'dt',
  'dd',
  'td',
  'th',
  'caption',
};

const _markTags = {
  'b': InlineMark.bold,
  'strong': InlineMark.bold,
  'i': InlineMark.italic,
  'em': InlineMark.italic,
  'cite': InlineMark.italic,
  'dfn': InlineMark.italic,
  'var': InlineMark.italic,
  'code': InlineMark.code,
  'kbd': InlineMark.code,
  'samp': InlineMark.code,
  'tt': InlineMark.code,
  'sup': InlineMark.superscript,
  'sub': InlineMark.subscript,
};

class _Builder {
  _Builder(this.docHref, this._rtl, this.styles);

  final String docHref;
  final EpubStyles styles;
  double _boxFraction = 1;
  bool _rtl;
  final List<DocBlock> blocks = [];
  final Map<String, int> anchors = {};

  int offset = 0;

  final List<InlineRun> _runs = [];
  final StringBuffer _pending = StringBuffer();
  Set<InlineMark> _pendingMarks = const {};
  String? _pendingHref;
  int _pendingStart = 0;

  final Set<InlineMark> _marks = {};
  String? _href;

  BlockKind _kind = BlockKind.paragraph;
  int _level = 0;
  BlockAlign _align = BlockAlign.start;
  String? _blockId;
  bool _listOrdered = false;
  int _listIndex = 0;
  bool _preserveSpace = false;

  final List<bool> _listStack = [];
  final List<int> _listCounters = [];

  void visit(dom.Node node) {
    if (node is dom.Text) {
      _appendText(node.text);
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_skipped.contains(tag)) return;

    final id = node.id.isEmpty ? null : node.id;
    if (id != null) anchors[id] = _cursor();

    final box = _boxFraction;
    if (!_imageTags.contains(tag)) {
      final width = styles.widthOf(node);
      if (width?.unit == CssUnit.percent) {
        _boxFraction = box * (width!.value / 100).clamp(0, 1);
      }
    }
    _dispatch(tag, node, id);
    _boxFraction = box;
  }

  static const _imageTags = {'img', 'image'};

  void _dispatch(String tag, dom.Element node, String? id) {
    if (_isPageBreak(node)) {
      _emitMarker(BlockKind.pageBreak, id);
      return;
    }
    if (_visitSpecial(tag, node, id)) return;
    if (_leafBlocks.contains(tag)) {
      _openBlock(tag, node, id);
    } else if (_promotable.contains(tag) && _hasOnlyInline(node)) {
      _openBlock('p', node, id);
    } else if (_containers.contains(tag) || _promotable.contains(tag)) {
      _visitContainer(node);
    } else {
      _visitChildren(node);
    }
  }

  bool _visitSpecial(String tag, dom.Element node, String? id) {
    switch (tag) {
      case 'br':
        _visitBreak();
      case 'hr':
        _emitMarker(BlockKind.separator, id);
      case 'img' || 'image':
        _emitImage(node, id);
      case 'svg':
        final image = node.querySelector('image');
        if (image == null) return false;
        _emitImage(image, id);
      case 'a':
        _visitLink(node);
      case 'ul' || 'ol':
        _visitList(node, ordered: tag == 'ol');
      default:
        final mark = _markTags[tag];
        if (mark == null) return false;
        _visitMarked(node, mark);
    }
    return true;
  }

  void _emitMarker(BlockKind kind, String? id) {
    flush();
    blocks.add(DocBlock(kind: kind, start: offset, end: offset, id: id));
  }

  void _visitBreak() {
    if (_pending.isEmpty && _runs.isEmpty) return;
    if (_endsWithBreak()) {
      flush();
    } else {
      _appendRaw('\n');
    }
  }

  void _visitMarked(dom.Element node, InlineMark mark) {
    final added = _marks.add(mark);
    _visitChildren(node);
    if (added) _marks.remove(mark);
  }

  void _visitLink(dom.Element node) {
    final target = node.attributes['href'];
    if (target == null || target.isEmpty) {
      _visitChildren(node);
      return;
    }
    final previous = _href;
    _href = target;
    _visitChildren(node);
    _href = previous;
  }

  void _visitList(dom.Element node, {required bool ordered}) {
    _listStack.add(ordered);
    _listCounters.add(0);
    _visitChildren(node);
    _listStack.removeLast();
    _listCounters.removeLast();
  }

  void _visitContainer(dom.Element node) {
    final align = _alignOf(node);
    final dir = EpubDocumentParser._dirOf(node);
    if (align == null && dir == null) {
      _visitChildren(node);
      return;
    }
    final previousAlign = _align;
    final previousRtl = _rtl;
    _align = align ?? _align;
    _rtl = dir ?? _rtl;
    _visitChildren(node);
    _align = previousAlign;
    _rtl = previousRtl;
  }

  bool _endsWithBreak() {
    if (_pending.isNotEmpty) return _pending.toString().endsWith('\n');
    if (_runs.isEmpty) return false;
    return _runs.last.text.endsWith('\n');
  }

  final Map<dom.Element, bool> _inlineOnly = {};

  bool _hasOnlyInline(dom.Element node) {
    final cached = _inlineOnly[node];
    if (cached != null) return cached;
    final result = _computeOnlyInline(node);
    _inlineOnly[node] = result;
    return result;
  }

  bool _computeOnlyInline(dom.Element node) {
    for (final child in node.children) {
      final tag = child.localName?.toLowerCase() ?? '';
      if (_skipped.contains(tag)) continue;
      if (!_inlineTags.contains(tag)) return false;
      if (_isPageBreak(child)) return false;
      if (!_hasOnlyInline(child)) return false;
    }
    return true;
  }

  void _visitChildren(dom.Element node) {
    for (final child in node.nodes) {
      visit(child);
    }
  }

  void _openBlock(String tag, dom.Element node, String? id) {
    flush();

    final savedKind = _kind;
    final savedLevel = _level;
    final savedAlign = _align;
    final savedId = _blockId;
    final savedOrdered = _listOrdered;
    final savedIndex = _listIndex;
    final savedPre = _preserveSpace;
    final savedRtl = _rtl;
    _rtl = EpubDocumentParser._dirOf(node) ?? _rtl;

    _kind = switch (tag) {
      'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => BlockKind.heading,
      'li' => BlockKind.listItem,
      'blockquote' => BlockKind.quote,
      'pre' => BlockKind.preformatted,
      _ => BlockKind.paragraph,
    };
    _level = switch (tag) {
      'h1' => 1,
      'h2' => 2,
      'h3' => 3,
      'h4' => 4,
      'h5' => 5,
      'h6' => 6,
      'li' => _listStack.length,
      _ => 0,
    };
    _align = _alignOf(node) ?? savedAlign;
    _blockId = id;
    _preserveSpace = tag == 'pre';

    if (tag == 'li' && _listCounters.isNotEmpty) {
      _listOrdered = _listStack.last;
      _listCounters[_listCounters.length - 1] += 1;
      _listIndex = _listCounters.last;
    }

    _visitChildren(node);
    flush();

    _kind = savedKind;
    _level = savedLevel;
    _align = savedAlign;
    _blockId = savedId;
    _listOrdered = savedOrdered;
    _listIndex = savedIndex;
    _preserveSpace = savedPre;
    _rtl = savedRtl;
  }

  void _emitImage(dom.Element node, String? id) {
    flush();
    final raw = _attribute(node, 'src') ?? _attribute(node, 'href');
    if (raw == null || raw.isEmpty) return;
    final start = offset;
    offset += objectReplacement.length;
    blocks.add(
      DocBlock(
        kind: BlockKind.image,
        start: start,
        end: offset,
        src: _resolve(raw),
        alt: node.attributes['alt'],
        align: BlockAlign.center,
        width: _imageWidth(node),
        boxFraction: _boxFraction,
        id: id,
        rtl: _rtl,
        runs: [InlineRun(text: objectReplacement, start: start)],
      ),
    );
  }

  CssLength? _imageWidth(dom.Element node) {
    if (node.localName?.toLowerCase() != 'img') return null;
    final width = styles.widthOf(node, attribute: true);
    if (width == null || width.unit != CssUnit.percent) return width;
    return CssLength(width.value * _boxFraction, CssUnit.percent);
  }

  void _appendText(String raw) {
    if (raw.isEmpty) return;
    if (_preserveSpace) {
      _appendRaw(raw);
      return;
    }
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.trim().isEmpty) {
      if (_pending.isEmpty && _runs.isEmpty) return;
      _appendRaw(' ');
      return;
    }
    var text = collapsed;
    if (_pending.isEmpty && _runs.isEmpty) {
      text = text.trimLeft();
    }
    _appendRaw(text);
  }

  void _appendRaw(String text) {
    if (text.isEmpty) return;
    final marks = Set<InlineMark>.unmodifiable(_marks);
    if (_pending.isNotEmpty &&
        (!_sameMarks(marks, _pendingMarks) || _href != _pendingHref)) {
      _closeRun();
    }
    if (_pending.isEmpty) {
      _pendingStart = offset;
      _pendingMarks = marks;
      _pendingHref = _href;
    }
    _pending.write(text);
    offset += text.length;
  }

  void _closeRun() {
    if (_pending.isEmpty) return;
    _runs.add(
      InlineRun(
        text: _pending.toString(),
        start: _pendingStart,
        marks: _pendingMarks,
        href: _pendingHref,
      ),
    );
    _pending.clear();
  }

  void flush() {
    _closeRun();
    if (_runs.isEmpty) return;

    var runs = List<InlineRun>.from(_runs);
    _runs.clear();

    if (!_preserveSpace) {
      runs = _trimTrailing(runs);
      if (runs.isEmpty) return;
    }

    final start = runs.first.start;
    final end = runs.last.end;
    blocks.add(
      DocBlock(
        kind: _kind,
        start: start,
        end: end,
        runs: List.unmodifiable(runs),
        level: _level,
        align: _align,
        id: _blockId,
        listOrdered: _listOrdered,
        listIndex: _listIndex,
        rtl: _rtl,
      ),
    );
    _blockId = null;
  }

  List<InlineRun> _trimTrailing(List<InlineRun> runs) {
    while (runs.isNotEmpty) {
      final last = runs.last;
      final trimmed = last.text.trimRight();
      if (trimmed == last.text) break;
      offset -= last.text.length - trimmed.length;
      runs.removeLast();
      if (trimmed.isEmpty) continue;
      runs.add(
        InlineRun(
          text: trimmed,
          start: last.start,
          marks: last.marks,
          href: last.href,
        ),
      );
      break;
    }
    return runs;
  }

  int _cursor() => _pending.isEmpty ? offset : _pendingStart + _pending.length;

  bool _sameMarks(Set<InlineMark> a, Set<InlineMark> b) =>
      a.length == b.length && a.every(b.contains);

  bool _isPageBreak(dom.Element node) {
    final role = node.attributes['role'];
    if (role == 'doc-pagebreak') return true;
    final type = _attribute(node, 'type');
    return type != null && type.split(RegExp(r'\s+')).contains('pagebreak');
  }

  BlockAlign? _alignOf(dom.Element node) {
    final align = node.attributes['align']?.toLowerCase();
    final style = node.attributes['style']?.toLowerCase() ?? '';
    final match = RegExp(r'text-align\s*:\s*([a-z]+)').firstMatch(style);
    return switch (match?.group(1) ?? align) {
      'center' => BlockAlign.center,
      'right' || 'end' => BlockAlign.end,
      'justify' => BlockAlign.justify,
      'left' || 'start' => BlockAlign.start,
      _ => null,
    };
  }

  String? _attribute(dom.Element node, String name) {
    final direct = node.attributes[name];
    if (direct != null) return direct;
    for (final entry in node.attributes.entries) {
      final key = entry.key.toString();
      if (key == name || key.endsWith(':$name')) return entry.value;
    }
    return null;
  }

  String _resolve(String src) {
    if (src.startsWith('data:') ||
        src.startsWith('http://') ||
        src.startsWith('https://')) {
      return src;
    }
    final decoded = decodeHref(src.split('#').first);
    return p.url.normalize(p.url.join(p.url.dirname(docHref), decoded));
  }
}
