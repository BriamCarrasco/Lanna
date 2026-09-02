// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:ui' as ui;

import '../epub_view.dart';

class EpubJsController implements EpubViewController {
  EpubJsController(this._runJs, {this.capture});

  final Future<void> Function(String source) _runJs;
  final Future<ui.Image?> Function()? capture;

  Future<void> _call(String expr) =>
      _runJs('window.readerApi && window.readerApi.$expr');

  @override
  Future<void> next() => _call('next();');

  @override
  Future<void> previous() => _call('prev();');

  @override
  Future<void> goToCfi(String cfi) => _call('display(${jsonEncode(cfi)});');

  @override
  Future<void> goToPercentage(double percentage) =>
      _call('goToPercentage($percentage);');

  @override
  Future<void> loadLocations(String json) =>
      _call('loadLocations(${jsonEncode(json)});');

  @override
  Future<void> search(String query) => _call('search(${jsonEncode(query)});');

  @override
  Future<ui.Image?> snapshot() => capture?.call() ?? Future.value();

  @override
  Future<void> applyHighlights(List<HighlightSpec> highlights) {
    final arg = jsonEncode([
      for (final h in highlights) {'cfi': h.cfi, 'color': h.color},
    ]);
    return _call('applyHighlights($arg);');
  }

  @override
  Future<void> addHighlight(String cfi, String color) =>
      _call('addHighlight(${jsonEncode(cfi)}, ${jsonEncode(color)});');

  @override
  Future<void> removeHighlight(String cfi) =>
      _call('removeHighlight(${jsonEncode(cfi)});');

  @override
  Future<void> clearSelection() => _call('clearSelection();');

  @override
  Future<void> setInsets(double top, double bottom) =>
      _call('setInsets(${top.round()}, ${bottom.round()});');

  @override
  Future<void> applyPresentation(ReaderPresentation p) {
    final arg = jsonEncode({
      'bg': p.background,
      'fg': p.foreground,
      'link': p.link,
      'fontSizePct': p.fontSizePercent,
      'fontFamily': p.fontFamily,
      'lineHeight': p.lineHeight,
      'columns': p.columnMode,
      'pageAnimation': p.pageAnimation,
      'edgeTaps': p.edgeTaps,
    });
    return _call('setTheme($arg);');
  }
}

void dispatchReaderEvent(
  Object? raw,
  EpubViewCallbacks callbacks,
  EpubViewController controller,
) {
  final Map<String, dynamic> event;
  try {
    event = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : Map<String, dynamic>.from(raw as Map);
  } catch (_) {
    return;
  }

  switch (event['type']) {
    case 'ready':
      callbacks.onReady?.call(controller);
    case 'relocated':
      callbacks.onLocationChanged?.call(
        ReaderLocation(
          cfi: event['cfi'] as String? ?? '',
          href: event['href'] as String?,
          percentage: (event['percentage'] as num?)?.toDouble(),
          chapterIndex: (event['chapterIndex'] as num?)?.toInt(),
          remainingMinutes: (event['remainingMinutes'] as num?)?.toInt(),
          atStart: event['atStart'] == true,
          atEnd: event['atEnd'] == true,
        ),
      );
    case 'locations':
      final data = event['data'] as String?;
      if (data != null && data.isNotEmpty) {
        callbacks.onLocationsGenerated?.call(data);
      }
    case 'locationsReady':
      final total = (event['total'] as num?)?.toInt();
      if (total != null && total > 0) callbacks.onPageCount?.call(total);
    case 'rendered':
      callbacks.onRendered?.call();
    case 'turnRequest':
      callbacks.onTurnRequest?.call(
        (event['dir'] as num?)?.toInt() == -1 ? -1 : 1,
      );
    case 'textSelected':
      final rect = event['rect'] as Map?;
      callbacks.onTextSelected?.call(
        ReaderSelection(
          cfi: event['cfi'] as String? ?? '',
          text: (event['text'] as String? ?? '').trim(),
          rect: ui.Rect.fromLTWH(
            (rect?['x'] as num?)?.toDouble() ?? 0,
            (rect?['y'] as num?)?.toDouble() ?? 0,
            (rect?['w'] as num?)?.toDouble() ?? 0,
            (rect?['h'] as num?)?.toDouble() ?? 0,
          ),
        ),
      );
    case 'selectionCleared':
      callbacks.onSelectionCleared?.call();
    case 'highlightTapped':
      final cfi = event['cfi'] as String?;
      if (cfi != null) callbacks.onHighlightTapped?.call(cfi);
    case 'searchResults':
      final hits = (event['results'] as List? ?? [])
          .map(
            (e) => SearchHit(
              cfi: e['cfi'] as String? ?? '',
              excerpt: (e['excerpt'] as String? ?? '').trim(),
            ),
          )
          .where((h) => h.cfi.isNotEmpty)
          .toList();
      callbacks.onSearchResults?.call(event['query'] as String? ?? '', hits);
    case 'toc':
      final list = (event['toc'] as List? ?? [])
          .map(
            (e) => TocEntry(
              label: (e['label'] as String? ?? '').trim(),
              href: e['href'] as String? ?? '',
            ),
          )
          .where((e) => e.label.isNotEmpty)
          .toList();
      callbacks.onTocLoaded?.call(list);
    case 'error':
      callbacks.onError?.call(event['message'] as String? ?? 'error');
  }
}
