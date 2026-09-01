// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/epub/epub_book.dart';
import '../../../data/local/app_database.dart';
import '../reader_theme.dart';

enum _Tab { chapters, bookmarks }

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

  @override
  State<TocDrawer> createState() => _TocDrawerState();
}

class _TocDrawerState extends State<TocDrawer> {
  _Tab _tab = _Tab.chapters;

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: chrome.panelBackground,
        border: Border(right: BorderSide(color: chrome.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: chrome.barBorder)),
            ),
            child: Row(
              children: [
                Text(
                  _tab == _Tab.chapters ? 'Contenido' : 'Marcadores',
                  style: AppTheme.reading(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: chrome.onBar,
                  ),
                ),
                const Spacer(),
                _TabToggle(
                  tab: _tab,
                  chrome: chrome,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                const SizedBox(width: 4),
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
            child: _tab == _Tab.chapters ? _chapters() : _bookmarksList(),
          ),
          if (_tab == _Tab.chapters &&
              (widget.chapterCount > 0 || widget.pageCount > 0))
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: chrome.barBorder)),
              ),
              child: Text(
                [
                  if (widget.chapterCount > 0) '${widget.chapterCount} capítulos',
                  if (widget.pageCount > 0) '${widget.pageCount} páginas',
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: chrome.onBarMuted),
              ),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: flat.length,
      itemBuilder: (context, i) {
        final row = flat[i];
        final active =
            current != null && row.entry.href.split('#').first == current;
        return InkWell(
          onTap: () => widget.onSelect(row.entry),
          child: Container(
            padding: EdgeInsets.fromLTRB(20.0 + row.depth * 14, 9, 16, 9),
            decoration: BoxDecoration(
              color: active ? chrome.fieldActive : Colors.transparent,
              borderRadius: active
                  ? const BorderRadius.horizontal(right: Radius.circular(6))
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
              style: TextStyle(
                fontSize: row.depth == 0 ? 12.5 : 12,
                height: 1.35,
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, i) {
        final bookmark = widget.bookmarks[i];
        final active =
            widget.currentCfi != null && bookmark.cfi == widget.currentCfi;
        final percent = (bookmark.percent * 100).round();
        return InkWell(
          onTap: () => widget.onBookmarkSelect(bookmark),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            color: active ? chrome.fieldActive : Colors.transparent,
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  size: 14,
                  color: ReaderChrome.accent,
                ),
                const SizedBox(width: 10),
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
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: chrome.onBar,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$percent %',
                        style: TextStyle(
                          fontSize: 10.5,
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
        style: TextStyle(fontSize: 12.5, color: chrome.onBarMuted),
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
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? chrome.fieldActive : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? chrome.onBar : chrome.onBarMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: chrome.fieldBackground,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: chrome.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell('Capítulos', _Tab.chapters),
          cell('Marcadores', _Tab.bookmarks),
        ],
      ),
    );
  }
}
