// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/epub/epub_book.dart';
import '../../../data/local/app_database.dart';
import '../reader_theme.dart';

enum _Tab { chapters, bookmarks, notes }

class TocDrawer extends StatefulWidget {
  const TocDrawer({
    super.key,
    required this.toc,
    required this.currentHref,
    required this.chapterCount,
    required this.pageCount,
    required this.bookmarks,
    required this.currentCfi,
    required this.chrome,
    required this.onSelect,
    required this.onBookmarkSelect,
    required this.onBookmarkDelete,
    required this.onClose,
    this.highlights = const [],
    this.highlightColors = const {},
    this.onHighlightSelect,
    this.onHighlightDelete,
  });

  final List<EpubTocEntry> toc;
  final String? currentHref;
  final int chapterCount;
  final int pageCount;
  final List<Bookmark> bookmarks;
  final String? currentCfi;
  final ReaderChrome chrome;
  final ValueChanged<EpubTocEntry> onSelect;
  final ValueChanged<Bookmark> onBookmarkSelect;
  final ValueChanged<Bookmark> onBookmarkDelete;
  final VoidCallback onClose;
  final List<Highlight> highlights;
  final Map<String, Color> highlightColors;
  final ValueChanged<Highlight>? onHighlightSelect;
  final ValueChanged<Highlight>? onHighlightDelete;

  @override
  State<TocDrawer> createState() => _TocDrawerState();
}

class _TocDrawerState extends State<TocDrawer> {
  _Tab _tab = _Tab.chapters;

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: chrome.panelBackground,
        border: Border(right: BorderSide(color: chrome.panelBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s4,
                LannaSpacing.s2,
                LannaSpacing.s2,
                LannaSpacing.s2,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: chrome.barBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabToggle(
                      tab: _tab,
                      chrome: chrome,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 17),
                    color: chrome.onBarMuted,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _Tab.chapters => _chapters(),
                _Tab.bookmarks => _bookmarksList(),
                _Tab.notes => _notesList(),
              },
            ),
            if (_tab == _Tab.chapters &&
                (widget.chapterCount > 0 || widget.pageCount > 0))
              Container(
                padding: const EdgeInsets.fromLTRB(
                  LannaSpacing.s5,
                  LannaSpacing.s3,
                  LannaSpacing.s5,
                  LannaSpacing.s3,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: chrome.barBorder)),
                ),
                child: Text(
                  [
                    if (widget.chapterCount > 0)
                      '${widget.chapterCount} capítulos',
                    if (widget.pageCount > 0) '${widget.pageCount} páginas',
                  ].join(' · '),
                  style: LannaType.micro.copyWith(color: chrome.onBarMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chapters() {
    final chrome = widget.chrome;
    final flat = <({EpubTocEntry entry, int depth})>[];
    void walk(List<EpubTocEntry> items, int depth) {
      for (final item in items) {
        flat.add((entry: item, depth: depth));
        walk(item.children, depth + 1);
      }
    }

    walk(widget.toc, 0);
    if (flat.isEmpty) {
      return _Empty('Este libro no trae índice', chrome: chrome);
    }

    final current = widget.currentHref?.split('#').first;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      itemCount: flat.length,
      itemBuilder: (context, i) {
        final row = flat[i];
        final active =
            current != null && row.entry.href.split('#').first == current;
        return InkWell(
          onTap: () => widget.onSelect(row.entry),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              LannaSpacing.s5 + row.depth * LannaSpacing.s4,
              LannaSpacing.s2 + 1,
              LannaSpacing.s4,
              LannaSpacing.s2 + 1,
            ),
            decoration: BoxDecoration(
              color: active ? chrome.fieldActive : Colors.transparent,
              borderRadius: active
                  ? const BorderRadius.horizontal(right: LannaRadii.sm)
                  : null,
              border: Border(
                left: BorderSide(
                  color: active ? ReaderChrome.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              row.entry.label,
              style: LannaType.sm.copyWith(
                fontWeight: active
                    ? FontWeight.w600
                    : (row.depth == 0 ? FontWeight.w500 : FontWeight.w400),
                color: active ? chrome.onBar : chrome.onBarMuted,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bookmarksList() {
    final chrome = widget.chrome;
    if (widget.bookmarks.isEmpty) {
      return _Empty('Sin marcadores todavía', chrome: chrome);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, i) {
        final bookmark = widget.bookmarks[i];
        final active =
            widget.currentCfi != null && bookmark.cfi == widget.currentCfi;
        final percent = (bookmark.percent * 100).round();
        return InkWell(
          onTap: () => widget.onBookmarkSelect(bookmark),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              LannaSpacing.s5,
              LannaSpacing.s3,
              LannaSpacing.s3,
              LannaSpacing.s3,
            ),
            color: active ? chrome.fieldActive : Colors.transparent,
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  size: 14,
                  color: ReaderChrome.accent,
                ),
                const SizedBox(width: LannaSpacing.s3 - 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.label?.trim().isNotEmpty == true
                            ? bookmark.label!.trim()
                            : 'Marcador',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LannaType.sm.copyWith(
                          fontWeight: FontWeight.w500,
                          color: chrome.onBar,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$percent %',
                        style: LannaType.micro.copyWith(
                          color: chrome.onBarMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 14),
                  color: chrome.onBarMuted,
                  onPressed: () => widget.onBookmarkDelete(bookmark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notesList() {
    final chrome = widget.chrome;
    if (widget.highlights.isEmpty) {
      return _Empty('Sin notas todavía', chrome: chrome);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      itemCount: widget.highlights.length,
      itemBuilder: (context, i) {
        final h = widget.highlights[i];
        final dot = widget.highlightColors[h.color] ?? ReaderChrome.accent;
        return InkWell(
          onTap: () => widget.onHighlightSelect?.call(h),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              LannaSpacing.s5,
              LannaSpacing.s3,
              LannaSpacing.s3,
              LannaSpacing.s3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: LannaSpacing.s3 - 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.content.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: LannaType.sm.copyWith(color: chrome.onBar),
                      ),
                      if (h.note?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          h.note!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LannaType.micro.copyWith(
                            fontStyle: FontStyle.italic,
                            color: chrome.onBarMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 14),
                  color: chrome.onBarMuted,
                  onPressed: () => widget.onHighlightDelete?.call(h),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message, {required this.chrome});
  final String message;
  final ReaderChrome chrome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: LannaType.sm.copyWith(color: chrome.onBarMuted),
      ),
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.chrome,
    required this.onChanged,
  });

  final _Tab tab;
  final ReaderChrome chrome;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, _Tab value) {
      final selected = tab == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s1 + 1),
            decoration: BoxDecoration(
              color: selected ? chrome.fieldActive : Colors.transparent,
              borderRadius: LannaRadii.brXs,
            ),
            child: Text(
              label,
              style: LannaType.micro.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? chrome.onBar : chrome.onBarMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: chrome.fieldBackground,
        borderRadius: LannaRadii.brSm,
        border: Border.all(color: chrome.panelBorder),
      ),
      child: Row(
        children: [
          cell('Capítulos', _Tab.chapters),
          cell('Marcadores', _Tab.bookmarks),
          cell('Notas', _Tab.notes),
        ],
      ),
    );
  }
}
