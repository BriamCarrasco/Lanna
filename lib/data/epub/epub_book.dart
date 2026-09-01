// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:typed_data';

class EpubMetadata {
  const EpubMetadata({
    this.title,
    this.author,
    this.language,
    this.identifier,
    this.publisher,
    this.description,
    this.coverBytes,
    this.coverFileName,
  });

  final String? title;
  final String? author;
  final String? language;
  final String? identifier;
  final String? publisher;
  final String? description;

  final Uint8List? coverBytes;
  final String? coverFileName;
}

class ManifestItem {
  const ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties = const {},
  });

  final String id;

  final String href;
  final String mediaType;
  final Set<String> properties;

  bool get isXhtml =>
      mediaType == 'application/xhtml+xml' || mediaType == 'text/html';
}

class SpineItem {
  const SpineItem({
    required this.index,
    required this.idref,
    required this.href,
    required this.linear,
  });

  final int index;
  final String idref;

  final String href;
  final bool linear;
}

class EpubTocEntry {
  const EpubTocEntry({
    required this.label,
    required this.href,
    this.children = const [],
  });

  final String label;

  final String href;
  final List<EpubTocEntry> children;
}

class EpubBook {
  const EpubBook({
    required this.opfPath,
    required this.metadata,
    required this.manifest,
    required this.spine,
    required this.toc,
  });

  final String opfPath;
  final EpubMetadata metadata;
  final List<ManifestItem> manifest;
  final List<SpineItem> spine;
  final List<EpubTocEntry> toc;

  ManifestItem? itemById(String id) {
    for (final item in manifest) {
      if (item.id == id) return item;
    }
    return null;
  }

  int get chapterCount => spine.where((s) => s.linear).length;
}
