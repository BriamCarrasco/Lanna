// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/epub/epub_book.dart';

const _drawerBg = Color(0xFF1A191F);
const _rowActive = Color(0xFF26242C);

class TocDrawer extends StatelessWidget {
  const TocDrawer({
    super.key,
    required this.toc,
    required this.currentHref,
    required this.chapterCount,
    required this.pageCount,
    required this.onSelect,
    required this.onClose,
  });

  final List<EpubTocEntry> toc;
  final String? currentHref;
  final int chapterCount;
  final int pageCount;
  final ValueChanged<EpubTocEntry> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final flat = <({EpubTocEntry entry, int depth})>[];
    void walk(List<EpubTocEntry> items, int depth) {
      for (final item in items) {
        flat.add((entry: item, depth: depth));
        walk(item.children, depth + 1);
      }
    }

    walk(toc, 0);
    final current = currentHref?.split('#').first;

    return Container(
      width: 300,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: _drawerBg,
        border: Border(right: BorderSide(color: LannaColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF232128))),
            ),
            child: Row(
              children: [
                Text(
                  'Contenido',
                  style: AppTheme.reading(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: LannaColors.text,
                  ),
                ),
                const Spacer(),
                const _MiniToggle(),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 17),
                  color: LannaColors.textMuted,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: flat.isEmpty
                ? const Center(
                    child: Text(
                      'Este libro no trae índice',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: LannaColors.textMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: flat.length,
                    itemBuilder: (context, i) {
                      final row = flat[i];
                      final active =
                          current != null &&
                          row.entry.href.split('#').first == current;
                      return InkWell(
                        onTap: () => onSelect(row.entry),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            20.0 + row.depth * 14,
                            9,
                            16,
                            9,
                          ),
                          decoration: BoxDecoration(
                            color: active ? _rowActive : Colors.transparent,
                            borderRadius: active
                                ? const BorderRadius.horizontal(
                                    right: Radius.circular(6),
                                  )
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: active
                                    ? LannaColors.accent
                                    : Colors.transparent,
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
                                  : (row.depth == 0
                                        ? FontWeight.w500
                                        : FontWeight.w400),
                              color: active
                                  ? LannaColors.textStrong
                                  : LannaColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (chapterCount > 0 || pageCount > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF232128))),
              ),
              child: Text(
                [
                  if (chapterCount > 0) '$chapterCount capítulos',
                  if (pageCount > 0) '$pageCount páginas',
                ].join(' · '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6D6A63)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF111014),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: LannaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _rowActive,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'Capítulos',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: LannaColors.text,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              'Marcadores',
              style: TextStyle(fontSize: 11, color: Color(0xFF57534C)),
            ),
          ),
        ],
      ),
    );
  }
}
