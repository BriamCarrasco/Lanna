// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:xml/xml.dart';

class ComicBook {
  const ComicBook({
    required this.pages,
    this.title,
    this.writer,
    this.series,
    this.rtl = false,
  });

  final List<String> pages;
  final String? title;
  final String? writer;
  final String? series;
  final bool rtl;
}

class ComicInfo {
  const ComicInfo({this.title, this.writer, this.series, this.rtl = false});

  final String? title;
  final String? writer;
  final String? series;
  final bool rtl;

  static ComicInfo parse(String source) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } catch (_) {
      return const ComicInfo();
    }
    String? field(String name) {
      for (final e in doc.findAllElements(name)) {
        final text = e.innerText.trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final series = field('Series');
    final number = field('Number');
    final volume = field('Volume');
    final plain = field('Title');

    String? title;
    if (series != null) {
      title = number != null
          ? '$series #$number'
          : volume != null
          ? '$series Vol. $volume'
          : series;
      if (plain != null && number == null && volume == null) {
        title = '$series: $plain';
      }
    } else {
      title = plain;
    }

    final manga = field('Manga')?.toLowerCase();
    return ComicInfo(
      title: title,
      writer: field('Writer'),
      series: series,
      rtl: manga == 'yesandrighttoleft',
    );
  }
}

const comicImageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};

int compareNatural(String a, String b) {
  final ca = _chunks(a.toLowerCase());
  final cb = _chunks(b.toLowerCase());
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final x = ca[i];
    final y = cb[i];
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = nx != null && ny != null
        ? (nx != ny ? nx.compareTo(ny) : x.length.compareTo(y.length))
        : x.compareTo(y);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}

final _chunkPattern = RegExp(r'\d+|\D+');

List<String> _chunks(String s) =>
    _chunkPattern.allMatches(s).map((m) => m.group(0)!).toList();
