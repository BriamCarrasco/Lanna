// SPDX-License-Identifier: GPL-3.0-or-later

class ReaderLocation {
  const ReaderLocation({
    required this.cfi,
    this.href,
    this.percentage,
    this.chapterIndex,
    this.remainingMinutes,
    this.atStart = false,
    this.atEnd = false,
  });

  final String cfi;

  final String? href;
  final double? percentage;
  final int? chapterIndex;

  final int? remainingMinutes;
  final bool atStart;
  final bool atEnd;
}

class TocEntry {
  const TocEntry({required this.label, required this.href});

  final String label;
  final String href;
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
  });

  final String background;
  final String foreground;
  final String? link;
  final int fontSizePercent;
  final String? fontFamily;
  final double lineHeight;

  final String columnMode;
}

abstract class EpubViewController {
  Future<void> next();
  Future<void> previous();
  Future<void> goToCfi(String cfi);
  Future<void> goToPercentage(double percentage);
  Future<void> applyPresentation(ReaderPresentation presentation);

  Future<void> loadLocations(String json);
}

class EpubViewCallbacks {
  const EpubViewCallbacks({
    this.onReady,
    this.onLocationChanged,
    this.onTocLoaded,
    this.onLocationsGenerated,
    this.onPageCount,
    this.onError,
  });

  final void Function(EpubViewController controller)? onReady;
  final void Function(ReaderLocation location)? onLocationChanged;
  final void Function(List<TocEntry> toc)? onTocLoaded;

  final void Function(String json)? onLocationsGenerated;

  final void Function(int total)? onPageCount;
  final void Function(String message)? onError;
}
