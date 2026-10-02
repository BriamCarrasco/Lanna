// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/lanna_menu.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'book_search.dart';
import 'library_filters.dart';
import 'library_scan_controller.dart';
import 'library_shell.dart';
import 'series_group.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_grid.dart';
import 'widgets/compact_book_tile.dart';
import 'widgets/continue_reading_row.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/filters_panel.dart';
import 'widgets/section_scaffold.dart';
import 'widgets/series_sheet.dart';

enum _SortMode {
  recent('Recientes'),
  title('Título'),
  author('Autor');

  const _SortMode(this.label);
  final String label;
}

enum _ViewMode { grid, list }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _SortMode _sort = _SortMode.recent;
  _ViewMode _view = _ViewMode.grid;
  LibraryFilters _filters = const LibraryFilters();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(libraryScanProvider.notifier)
            .scanOnStartup()
            .then((_) {}, onError: (_) {}),
      );
    });
  }

  Future<void> _addFolder() => reportScan(
    ScaffoldMessenger.of(context),
    ref.read(libraryScanProvider.notifier).addFolder(),
  );

  Future<void> _rescan() => reportScan(
    ScaffoldMessenger.of(context),
    ref.read(libraryScanProvider.notifier).scan(),
  );

  void _showBookMenu(Book book, Offset globalPosition) {
    unawaited(showBookMenu(context, ref, book, globalPosition));
  }

  List<Book> _filteredSorted(
    List<Book> books,
    String rawQuery,
    Map<String, double> progress,
  ) {
    final query = foldForSearch(rawQuery);
    final matched = [
      for (final b in books)
        if ((query.isEmpty || bookMatches(b, query)) &&
            _filters.matches(b, progress[b.id]))
          b,
    ];
    return _sorted(matched);
  }

  List<Book> _sorted(List<Book> books) {
    final list = [...books];
    switch (_sort) {
      case _SortMode.recent:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case _SortMode.title:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SortMode.author:
        list.sort(
          (a, b) => (a.author ?? '~').toLowerCase().compareTo(
            (b.author ?? '~').toLowerCase(),
          ),
        );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final continueReading =
        ref.watch(continueReadingProvider).valueOrNull ?? const [];
    final hasFolders =
        ref.watch(libraryFoldersProvider).valueOrNull?.isNotEmpty ?? false;
    final query = ref.watch(librarySearchProvider);
    final progress =
        ref.watch(progressByBookProvider).valueOrNull ??
        const <String, double>{};
    final count = library.valueOrNull?.length ?? 0;
    final compact = MediaQuery.sizeOf(context).width < 900;

    return SectionScaffold(
      title: 'Biblioteca',
      subtitle: '$count ${count == 1 ? 'libro' : 'libros'}',
      actions: compact
          ? [
              PopupMenuButton<_SortMode>(
                icon: const Icon(
                  Icons.sort,
                  size: 20,
                  color: LannaColors.textMuted,
                ),
                initialValue: _sort,
                tooltip: 'Ordenar',
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final m in _SortMode.values)
                    lannaChoiceItem(
                      value: m,
                      label: m.label,
                      selected: m == _sort,
                    ),
                ],
              ),
              _RescanButton(onPressed: _rescan),
              IconButton(
                onPressed: _addFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'Añadir carpeta',
              ),
            ]
          : [
              _ViewToggle(
                view: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
              _SortButton(
                sort: _sort,
                onChanged: (s) => setState(() => _sort = s),
              ),
              _RescanButton(onPressed: _rescan, muted: true),
              FilledButton.icon(
                onPressed: _addFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Añadir carpeta'),
              ),
            ],
      child: Column(
        children: [
          const _ScanBanner(),
          Expanded(
            child: _LibraryBody(
              library: library.whenData(
                (books) => _filteredSorted(books, query, progress),
              ),
              libraryEmpty: count == 0,
              filters: _filters,
              onFilters: (f) => setState(() => _filters = f),
              continueReading: query.isEmpty && !_filters.active
                  ? continueReading
                  : const [],
              query: query,
              view: _view,
              hasFolders: hasFolders,
              onAddFolder: _addFolder,
              onRescan: _rescan,
              onBookMenu: _showBookMenu,
            ),
          ),
        ],
      ),
    );
  }
}

class _RescanButton extends ConsumerWidget {
  const _RescanButton({required this.onPressed, this.muted = false});

  final VoidCallback onPressed;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(libraryScanProvider.select((s) => s.running));
    return IconButton(
      onPressed: running ? null : onPressed,
      icon: Icon(Icons.refresh, size: muted ? 20 : null),
      color: muted ? LannaColors.textMuted : null,
      tooltip: 'Actualizar biblioteca',
    );
  }
}

class _ScanBanner extends ConsumerWidget {
  const _ScanBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(libraryScanProvider);
    if (!scan.running) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LannaSpacing.s6,
        LannaSpacing.s3,
        LannaSpacing.s6,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scan.total == 0
                ? 'Revisando tus carpetas…'
                : 'Revisando tus carpetas… ${scan.done} de ${scan.total}',
            style: LannaType.sm.copyWith(color: LannaColors.textMuted),
          ),
          const SizedBox(height: LannaSpacing.s2),
          ClipRRect(
            borderRadius: LannaRadii.brXs,
            child: LinearProgressIndicator(
              value: scan.total == 0 ? null : scan.done / scan.total,
              minHeight: 3,
              backgroundColor: LannaColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.library,
    required this.libraryEmpty,
    required this.filters,
    required this.onFilters,
    required this.continueReading,
    required this.query,
    required this.view,
    required this.hasFolders,
    required this.onAddFolder,
    required this.onRescan,
    required this.onBookMenu,
  });

  final AsyncValue<List<Book>> library;
  final bool libraryEmpty;
  final LibraryFilters filters;
  final ValueChanged<LibraryFilters> onFilters;
  final List<BookWithProgress> continueReading;
  final String query;
  final _ViewMode view;
  final bool hasFolders;
  final VoidCallback onAddFolder;
  final Future<void> Function() onRescan;
  final void Function(Book book, Offset globalPosition) onBookMenu;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (books) {
        if (libraryEmpty || (books.isEmpty && !filters.active)) {
          return searching
              ? SectionEmpty(
                  icon: Icons.search_off,
                  message: 'Sin resultados para «$query»',
                )
              : FadeIn(
                  child: EmptyLibraryView(
                    hasFolders: hasFolders,
                    onAddFolder: onAddFolder,
                    onRescan: onRescan,
                  ),
                );
        }
        final entries = searching
            ? [for (final b in books) BookEntry(b)]
            : groupSeries(books);
        return RefreshIndicator(
          onRefresh: onRescan,
          child: CustomScrollView(
            scrollCacheExtent: const ScrollCacheExtent.viewport(1),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (continueReading.isNotEmpty) ...[
                const _SectionLabel('Seguir leyendo'),
                SliverToBoxAdapter(
                  child: ContinueReadingRow(items: continueReading),
                ),
              ],
              _SectionLabel(
                searching ? 'Resultados' : 'Todos los libros',
                trailing: '${books.length}',
                action: FiltersButton(filters: filters, onChanged: onFilters),
              ),
              if (books.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: LannaSpacing.s8,
                    ),
                    child: SectionEmpty(
                      icon: Icons.filter_alt_off_outlined,
                      message: 'Ningún libro coincide con los filtros',
                      action: TextButton(
                        onPressed: () => onFilters(const LibraryFilters()),
                        child: const Text('Quitar filtros'),
                      ),
                    ),
                  ),
                )
              else if (view == _ViewMode.grid)
                LibraryGridSliver(
                  entries: entries,
                  onMenu: onBookMenu,
                  onOpenSeries: (series) =>
                      unawaited(showSeries(context, series)),
                )
              else
                _BookListSliver(entries: entries, onMenu: onBookMenu),
              const SliverToBoxAdapter(
                child: SizedBox(height: LannaSpacing.s6),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing, this.action});
  final String text;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LannaSpacing.s6,
          LannaSpacing.s5,
          LannaSpacing.s6,
          LannaSpacing.s3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      text.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LannaType.xs.copyWith(
                        color: LannaColors.textMuted,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: LannaSpacing.s2),
                    Text(
                      trailing!,
                      style: LannaType.xs.copyWith(color: LannaColors.border),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: LannaSpacing.s3),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});
  final _ViewMode view;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData icon, _ViewMode mode) {
      final active = view == mode;
      return InkWell(
        onTap: () => onChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LannaSpacing.s2 + 1,
            vertical: LannaSpacing.s2 - 1,
          ),
          color: active ? LannaColors.surfaceActive : Colors.transparent,
          child: Icon(
            icon,
            size: 15,
            color: active ? LannaColors.text : LannaColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: LannaColors.bg,
        border: Border.all(color: LannaColors.border),
        borderRadius: LannaRadii.brMd,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(Icons.grid_view, _ViewMode.grid),
          cell(Icons.view_list, _ViewMode.list),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});
  final _SortMode sort;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final mode in _SortMode.values)
          lannaChoiceItem(
            value: mode,
            label: mode.label,
            selected: mode == sort,
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LannaSpacing.s3,
          vertical: LannaSpacing.s2 - 1,
        ),
        decoration: BoxDecoration(
          color: LannaColors.bg,
          border: Border.all(color: LannaColors.border),
          borderRadius: LannaRadii.brMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.label,
              style: LannaType.md.copyWith(color: LannaColors.text),
            ),
            const SizedBox(width: LannaSpacing.s1 + 2),
            const Icon(
              Icons.expand_more,
              size: 14,
              color: LannaColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookListSliver extends StatelessWidget {
  const _BookListSliver({required this.entries, required this.onMenu});
  final List<LibraryEntry> entries;
  final void Function(Book book, Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverList.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: LannaColors.borderSubtle),
        itemBuilder: (context, i) => switch (entries[i]) {
          BookEntry(:final book) => _BookRow(book: book, onMenu: onMenu),
          final SeriesEntry series => _SeriesRow(series: series),
        },
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series});
  final SeriesEntry series;

  @override
  Widget build(BuildContext context) {
    final count = series.volumes.length;
    return InkWell(
      onTap: () => unawaited(showSeries(context, series)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s3),
        child: Row(
          children: [
            SizedBox(width: 34, child: BookCover(book: series.first)),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.md.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$count ${count == 1 ? 'tomo' : 'tomos'}',
                    style: LannaType.sm.copyWith(color: LannaColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.layers_outlined,
              size: 18,
              color: LannaColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.book, required this.onMenu});
  final Book book;
  final void Function(Book book, Offset globalPosition) onMenu;

  void _menuFromCenter(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    onMenu(book, box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openBook(context, book),
      onLongPress: () => _menuFromCenter(context),
      onSecondaryTapUp: (d) => onMenu(book, d.globalPosition),
      child: CompactBookTile(book: book, subtitle: book.author),
    );
  }
}
