// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/text_search.dart';
import '../../../data/epub/epub_book.dart';
import '../engine_support.dart';
import '../fixed/fixed_layout_engine.dart';
import '../reader_engine.dart';
import 'selectable_pdf_page.dart';

class PdfEngineView extends FixedLayoutEngine {
  const PdfEngineView({
    super.key,
    required this.document,
    required super.callbacks,
    super.initialLocator,
    super.initialRtl,
  });

  final PdfDocument document;

  @override
  State<PdfEngineView> createState() => _PdfEngineViewState();
}

class _PdfEngineViewState extends FixedLayoutEngineState<PdfEngineView>
    with EngineHighlights<PdfEngineView> {
  List<EpubTocEntry> _toc = const [];
  PdfSelection? _selection;
  int _searchToken = 0;

  PdfDocument get _document => widget.document;

  @override
  int get pageCount => _document.pages.length;

  @override
  Size? pageSize(int page) {
    final p = _document.pages[page - 1];
    return Size(p.width, p.height);
  }

  @override
  List<EpubTocEntry> get toc => _toc;

  @override
  ReaderCapabilities get capabilities => const ReaderCapabilities(
    searchable: true,
    selectable: true,
    directional: true,
  );

  @override
  Future<void> prepare() async {
    try {
      _toc = _mapOutline(await _document.loadOutline());
    } catch (_) {}
  }

  List<EpubTocEntry> _mapOutline(List<PdfOutlineNode> nodes) => [
    for (final node in nodes)
      EpubTocEntry(
        label: node.title.trim(),
        href: node.dest != null ? 'page:${node.dest!.pageNumber}' : '',
        children: _mapOutline(node.children),
      ),
  ];

  @override
  void onPageChanged() {
    if (_selection == null) return;
    _selection = null;
    widget.callbacks.onSelectionCleared?.call();
  }

  @override
  Widget buildPage(BuildContext context, int page, Alignment alignment) {
    return SelectablePdfPage(
      document: _document,
      pageNumber: page,
      highlights: [
        for (final h in highlights)
          if (h.cfi.startsWith('page:$page#')) h,
      ],
      selection: _selection,
      onSelect: (sel) {
        setState(() => _selection = sel);
        widget.callbacks.onTextSelected?.call(
          ReaderSelection(
            cfi: sel.encodeCfi(),
            text: sel.text,
            rect: sel.screenRect,
          ),
        );
      },
      onHighlightTap: (cfi) => widget.callbacks.onHighlightTapped?.call(cfi),
      onTapEmpty: () {
        if (_selection != null) clearSelection();
      },
    );
  }

  @override
  Future<void> clearSelection() async {
    if (mounted && _selection != null) setState(() => _selection = null);
    widget.callbacks.onSelectionCleared?.call();
  }

  @override
  Future<void> search(String query) async {
    final trimmed = query.trim();
    final token = ++_searchToken;
    if (trimmed.length < 2) {
      widget.callbacks.onSearchResults?.call(query, const []);
      return;
    }
    final folded = foldForSearch(trimmed);
    final hits = <SearchHit>[];
    for (var n = 1; n <= pageCount; n++) {
      if (!mounted || token != _searchToken) return;
      String text;
      try {
        text = (await _document.pages[n - 1].loadText())?.fullText ?? '';
      } catch (_) {
        continue;
      }
      final foldedText = foldForSearch(text);
      var from = 0;
      while (hits.length < 200) {
        final at = foldedText.indexOf(folded, from);
        if (at < 0) break;
        final start = math.max(0, at - 48);
        final end = math.min(text.length, at + folded.length + 48);
        final prefix = start > 0 ? '…' : '';
        final suffix = end < text.length ? '…' : '';
        hits.add(
          SearchHit(
            cfi: 'page:$n',
            excerpt: '$prefix${text.substring(start, end).trim()}$suffix',
          ),
        );
        from = at + folded.length;
      }
      if (hits.length >= 200) break;
    }
    if (!mounted || token != _searchToken) return;
    widget.callbacks.onSearchResults?.call(query, List.unmodifiable(hits));
  }
}
