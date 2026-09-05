// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'epub_archive.dart';
import 'epub_book.dart';
import 'epub_paths.dart';

abstract final class EpubPackage {
  static const _dcNs = 'http://purl.org/dc/elements/1.1/';
  static const _opsNs = 'http://www.idpf.org/2007/ops';

  static EpubBook parse(Uint8List epubBytes) =>
      parseArchive(EpubArchive.open(epubBytes));

  static EpubBook parseArchive(EpubArchive archive) {
    if (!archive.exists(archive.opfPath)) {
      throw FormatException('OPF no encontrado: ${archive.opfPath}');
    }
    final opf = archive.xml(archive.opfPath);
    final pkg = opf.rootElement;

    final manifest = _parseManifest(pkg, archive);
    final manifestById = {for (final m in manifest) m.id: m};
    final spine = _parseSpine(pkg, manifestById);
    final metadata = _parseMetadata(pkg, manifest, archive);
    final toc = _parseToc(pkg, manifest, manifestById, archive);

    return EpubBook(
      opfPath: archive.opfPath,
      metadata: metadata,
      manifest: manifest,
      spine: spine,
      toc: toc,
      rtl: _isRtl(pkg),
    );
  }

  static List<ManifestItem> _parseManifest(
    XmlElement pkg,
    EpubArchive archive,
  ) {
    final manifest = _child(pkg, 'manifest');
    if (manifest == null) return const [];
    return manifest
        .findElements('item')
        .map((item) {
          final href = item.getAttribute('href');
          final id = item.getAttribute('id');
          if (href == null || id == null) return null;
          return ManifestItem(
            id: id,
            href: archive.resolveFromOpf(href),
            mediaType: item.getAttribute('media-type') ?? '',
            properties: (item.getAttribute('properties') ?? '')
                .split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty)
                .toSet(),
          );
        })
        .whereType<ManifestItem>()
        .toList();
  }

  static bool _isRtl(XmlElement pkg) {
    final spine = _child(pkg, 'spine');
    final declared = spine?.getAttribute('page-progression-direction');
    return declared?.toLowerCase().trim() == 'rtl';
  }

  static List<SpineItem> _parseSpine(
    XmlElement pkg,
    Map<String, ManifestItem> byId,
  ) {
    final spine = _child(pkg, 'spine');
    if (spine == null) return const [];
    var index = 0;
    return spine
        .findElements('itemref')
        .map((ref) {
          final idref = ref.getAttribute('idref');
          final item = idref == null ? null : byId[idref];
          if (item == null) return null;
          return SpineItem(
            index: index++,
            idref: idref!,
            href: item.href,
            linear: (ref.getAttribute('linear') ?? 'yes') != 'no',
          );
        })
        .whereType<SpineItem>()
        .toList();
  }

  static EpubMetadata _parseMetadata(
    XmlElement pkg,
    List<ManifestItem> manifest,
    EpubArchive archive,
  ) {
    final md = _child(pkg, 'metadata');
    final coverHref = _coverHref(pkg, manifest);
    Uint8List? coverBytes;
    String? coverName;
    if (coverHref != null) {
      coverBytes = archive.bytes(coverHref);
      if (coverBytes != null) coverName = p.basename(coverHref);
    }

    return EpubMetadata(
      title: _dc(md, 'title'),
      author: _dc(md, 'creator'),
      language: _dc(md, 'language'),
      identifier: _dc(md, 'identifier'),
      publisher: _dc(md, 'publisher'),
      description: _dc(md, 'description'),
      coverBytes: coverBytes,
      coverFileName: coverName,
    );
  }

  static String? _coverHref(XmlElement pkg, List<ManifestItem> manifest) {
    for (final item in manifest) {
      if (item.properties.contains('cover-image')) return item.href;
    }
    final md = _child(pkg, 'metadata');
    final coverId = md
        ?.findElements('meta')
        .where((m) => m.getAttribute('name') == 'cover')
        .map((m) => m.getAttribute('content'))
        .firstOrNull;
    if (coverId != null) {
      for (final item in manifest) {
        if (item.id == coverId) return item.href;
      }
    }
    for (final item in manifest) {
      if (item.mediaType.startsWith('image/') &&
          (item.id.toLowerCase().contains('cover') ||
              item.href.toLowerCase().contains('cover'))) {
        return item.href;
      }
    }
    return null;
  }

  static List<EpubTocEntry> _parseToc(
    XmlElement pkg,
    List<ManifestItem> manifest,
    Map<String, ManifestItem> byId,
    EpubArchive archive,
  ) {
    final navItem = manifest.firstWhereOrNull(
      (m) => m.properties.contains('nav'),
    );
    if (navItem != null && archive.exists(navItem.href)) {
      final toc = _parseNavDoc(archive.xml(navItem.href), navItem.href);
      if (toc.isNotEmpty) return _pruneToc(toc);
    }

    final spine = _child(pkg, 'spine');
    final ncxId = spine?.getAttribute('toc');
    var ncx = ncxId == null ? null : byId[ncxId];
    ncx ??= manifest.firstWhereOrNull(
      (m) => m.mediaType == 'application/x-dtbncx+xml',
    );
    if (ncx != null && archive.exists(ncx.href)) {
      return _pruneToc(_parseNcx(archive.xml(ncx.href), ncx.href));
    }

    return const [];
  }

  static final _numberLabel = RegExp(r'^\d{1,4}\s*[.)]?$');

  static bool _isNumberish(String label) => _numberLabel.hasMatch(label.trim());

  /// Quita entradas que son solo un número de capítulo (típico de NCX que
  /// listan «Título» y debajo «3»), pero solo si quedan entradas con título.
  static List<EpubTocEntry> _pruneToc(List<EpubTocEntry> toc) {
    var titled = 0;
    void count(List<EpubTocEntry> items) {
      for (final e in items) {
        if (!_isNumberish(e.label)) titled++;
        count(e.children);
      }
    }

    count(toc);
    if (titled == 0) return toc;

    List<EpubTocEntry> prune(List<EpubTocEntry> items, String? parentLabel) {
      final out = <EpubTocEntry>[];
      for (final e in items) {
        final children = prune(e.children, e.label);
        final duplicate =
            parentLabel != null &&
            e.label.trim().toLowerCase() == parentLabel.trim().toLowerCase();
        if ((_isNumberish(e.label) || duplicate) && children.isEmpty) {
          continue;
        }
        out.add(EpubTocEntry(label: e.label, href: e.href, children: children));
      }
      return out;
    }

    final pruned = prune(toc, null);
    return pruned.isEmpty ? toc : pruned;
  }

  static List<EpubTocEntry> _parseNcx(XmlDocument doc, String ncxPath) {
    final baseDir = p.dirname(ncxPath);
    final navMap = doc.findAllElements('navMap').firstOrNull;
    if (navMap == null) return const [];

    List<EpubTocEntry> readPoints(Iterable<XmlElement> points) {
      final out = <EpubTocEntry>[];
      for (final point in points) {
        final label =
            point
                .findElements('navLabel')
                .expand((l) => l.findElements('text'))
                .map((t) => t.innerText.trim())
                .firstOrNull ??
            '';
        final src = point
            .findElements('content')
            .map((c) => c.getAttribute('src'))
            .firstOrNull;
        out.add(
          EpubTocEntry(
            label: label,
            href: src == null ? '' : _resolve(baseDir, src),
            children: readPoints(point.findElements('navPoint')),
          ),
        );
      }
      return out;
    }

    return readPoints(navMap.findElements('navPoint'))
        .where((e) => e.label.isNotEmpty)
        .toList();
  }

  static List<EpubTocEntry> _parseNavDoc(XmlDocument doc, String navPath) {
    final baseDir = p.dirname(navPath);

    XmlElement? tocNav;
    for (final nav in doc.findAllElements('nav')) {
      final type =
          nav.getAttribute('epub:type') ??
          nav.getAttribute('type', namespaceUri: _opsNs) ??
          '';
      if (type.split(RegExp(r'\s+')).contains('toc')) {
        tocNav = nav;
        break;
      }
    }
    tocNav ??= doc
        .findAllElements('nav')
        .firstWhereOrNull((n) => n.findElements('ol').isNotEmpty);
    if (tocNav == null) return const [];

    List<EpubTocEntry> readList(XmlElement ol) {
      final out = <EpubTocEntry>[];
      for (final li in ol.findElements('li')) {
        final anchor =
            li.findElements('a').firstOrNull ??
            li.findElements('span').firstOrNull;
        final href = anchor?.getAttribute('href');
        final childOl = li.findElements('ol').firstOrNull;
        out.add(
          EpubTocEntry(
            label: anchor?.innerText.trim() ?? '',
            href: href == null ? '' : _resolve(baseDir, href),
            children: childOl == null ? const [] : readList(childOl),
          ),
        );
      }
      return out;
    }

    final rootOl = tocNav.findElements('ol').firstOrNull;
    if (rootOl == null) return const [];
    return readList(rootOl).where((e) => e.label.isNotEmpty).toList();
  }

  static String _resolve(String baseDir, String href) {
    final decoded = decodeHref(href);
    final hashIndex = decoded.indexOf('#');
    final path = hashIndex >= 0 ? decoded.substring(0, hashIndex) : decoded;
    final fragment = hashIndex >= 0 ? decoded.substring(hashIndex) : '';
    final resolved = p.normalize(p.join(baseDir, path)).replaceAll('\\', '/');
    return '$resolved$fragment';
  }

  static XmlElement? _child(XmlElement parent, String local) {
    for (final e in parent.childElements) {
      if (e.localName == local) return e;
    }
    return parent.findAllElements(local).firstOrNull;
  }

  static String? _dc(XmlElement? metadata, String tag) {
    if (metadata == null) return null;
    final el =
        metadata.findElements(tag, namespaceUri: _dcNs).firstOrNull ??
        metadata.findElements('dc:$tag').firstOrNull ??
        metadata.findElements(tag).firstOrNull;
    final text = el?.innerText.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}

extension _IterX<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }

  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
