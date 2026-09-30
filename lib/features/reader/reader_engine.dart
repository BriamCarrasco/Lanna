// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import '../../data/epub/epub_book.dart';

class ReaderLocation {
  const ReaderLocation({
    required this.cfi,
    this.href,
    this.percentage,
    this.chapterIndex,
    this.label,
    this.remainingMinutes,
    this.atStart = false,
    this.atEnd = false,
  });

  final String cfi;

  final String? href;
  final double? percentage;
  final int? chapterIndex;
  final String? label;

  final int? remainingMinutes;
  final bool atStart;
  final bool atEnd;
}

class SearchHit {
  const SearchHit({required this.cfi, required this.excerpt});

  final String cfi;
  final String excerpt;
}

class HighlightSpec {
  const HighlightSpec({required this.cfi, required this.color});

  final String cfi;
  final String color;
}

class ReaderSelection {
  const ReaderSelection({
    required this.cfi,
    required this.text,
    required this.rect,
  });

  final String cfi;
  final String text;
  final ui.Rect rect;
}

class ReaderPresentation {
  const ReaderPresentation({
    required this.background,
    required this.foreground,
    this.link,
    this.fontSizePercent = 112,
    this.fontFamily,
    this.lineHeight = 1.6,
    this.columnMode = 'auto',
    this.pageAnimation = 'slide',
    this.edgeTaps = true,
  });

  final String background;
  final String foreground;
  final String? link;
  final int fontSizePercent;
  final String? fontFamily;
  final double lineHeight;

  final String columnMode;
  final String pageAnimation;
  final bool edgeTaps;
}

class ReaderCapabilities {
  const ReaderCapabilities({
    this.reflowable = false,
    this.searchable = false,
    this.selectable = false,
    this.bookFontAvailable = false,
    this.bookFontUnsupported = false,
  });

  final bool reflowable;
  final bool searchable;
  final bool selectable;
  final bool bookFontAvailable;
  final bool bookFontUnsupported;
}

abstract class ReaderEngineController {
  ReaderCapabilities get capabilities;
  bool get rtl;
  int get chapterCount;
  String scrubLabel(double fraction);

  Future<void> next();
  Future<void> previous();
  Future<void> goToCfi(String cfi);
  Future<void> goToPercentage(double percentage);
  Future<void> applyPresentation(ReaderPresentation presentation);

  Future<void> search(String query);

  Future<ui.Image?> snapshot();

  Future<void> applyHighlights(List<HighlightSpec> highlights);
  Future<void> addHighlight(String cfi, String color);
  Future<void> removeHighlight(String cfi);
  Future<void> clearSelection();

  Future<void> setInsets(double top, double bottom);

  Future<void> setAnimating(bool value);
}

class ReaderEngineCallbacks {
  const ReaderEngineCallbacks({
    this.onReady,
    this.onLocationChanged,
    this.onTocLoaded,
    this.onPageCount,
    this.onSearchResults,
    this.onRendered,
    this.onTextSelected,
    this.onSelectionCleared,
    this.onHighlightTapped,
    this.onError,
  });

  final void Function(ReaderEngineController controller)? onReady;
  final void Function(ReaderLocation location)? onLocationChanged;
  final void Function(List<EpubTocEntry> toc)? onTocLoaded;
  final void Function(int total)? onPageCount;
  final void Function()? onRendered;
  final void Function(String query, List<SearchHit> hits)? onSearchResults;
  final void Function(ReaderSelection selection)? onTextSelected;
  final void Function()? onSelectionCleared;
  final void Function(String cfi)? onHighlightTapped;
  final void Function(String message)? onError;
}
