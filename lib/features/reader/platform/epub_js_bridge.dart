// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import '../epub_view.dart';

class EpubJsController implements EpubViewController {
  EpubJsController(this._runJs);

  final Future<void> Function(String source) _runJs;

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
