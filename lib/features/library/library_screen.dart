// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/lanna_menu.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';
import 'library_filters.dart';
import 'library_scan_controller.dart';
import 'library_shell.dart';
import 'series_group.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_grid.dart';
import 'widgets/compact_book_tile.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/filters_panel.dart';
import 'widgets/section_scaffold.dart';
import 'widgets/series_dialogs.dart';
import 'widgets/series_sheet.dart';

enum _SortMode {
  recent,
  title,
  author;

  String label(AppLocalizations l10n) => switch (this) {
    recent => l10n.sortRecent,
    title => l10n.sortTitle,
    author => l10n.sortAuthor,
  };
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
  final _filtersKey = GlobalKey(debugLabel: 'filtros');
  Set<String>? _selection;

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
    context.l10n,
    ref
        .read(libraryScanProvider.notifier)
        .addFolder(dialogTitle: context.l10n.chooseBooksFolder),
  );

  Future<void> _rescan() => reportScan(
    ScaffoldMessenger.of(context),
    context.l10n,
    ref.read(libraryScanProvider.notifier).scan(),
  );

  void _showBookMenu(Book book, Offset globalPosition) {
    unawaited(
      showBookMenu(
        context,
        ref,
        book,
        globalPosition,
        onSelect: () => _startSelection(book),
      ),
    );
  }

  void _startSelection([Book? book]) {
    setState(() => _selection = {if (book != null) book.id});
  }

  void _endSelection() => setState(() => _selection = null);

  void _toggle(List<Book> books) {
    final selection = _selection;
    if (selection == null) return;
    final ids = {for (final b in books) b.id};
    setState(() {
      _selection = ids.every(selection.contains)
          ? selection.difference(ids)
          : selection.union(ids);
    });
  }

  void _toggleAll(List<Book> volumes) {
    final selection = _selection;
    if (selection == null) return;
    final all = volumes.every((b) => selection.contains(b.id));
    setState(() => _selection = all ? {} : {for (final b in volumes) b.id});
  }

  Future<void> _moveSelection() async {
    final ids = _selection;
    if (ids == null || ids.isEmpty) return;
    final library = ref.read(libraryProvider).valueOrNull ?? const <Book>[];
    final books = [
      for (final b in library)
        if (ids.contains(b.id)) b,
    ];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final repo = ref.read(bookRepositoryProvider);
    final moved = await moveBooksToSeries(context, ref, books);
    if (moved == null || !mounted) return;
    _endSelection();
    final count = l10n.volumesCount(books.length);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          moved.name.isEmpty
              ? l10n.volumesOutOfSeries(count)
              : l10n.volumesInSeries(moved.name, count),
        ),
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(repo.restoreSeries(moved.previous)),
        ),
      ),
    );
  }

  List<LibraryEntry> _entries(
    List<Book> books,
    String rawQuery,
    Map<String, double> progress,
  ) {
    final query = foldForSearch(rawQuery);
    final filtered = _sorted([
      for (final b in books)
        if (_filters.matches(b, progress[b.id])) b,
    ]);
    return query.isEmpty
        ? groupSeries(filtered)
        : searchEntries(filtered, query);
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
    final hasFolders =
        ref.watch(libraryFoldersProvider).valueOrNull?.isNotEmpty ?? false;
    final query = ref.watch(librarySearchProvider);
    final progress =
        ref.watch(progressByBookProvider).valueOrNull ??
        const <String, double>{};
    final count = library.valueOrNull?.length ?? 0;
    final compact = MediaQuery.sizeOf(context).width < 900;
    final visible = library.whenData(
      (books) => _entries(books, query, progress),
    );
    final hasSeries =
        library.valueOrNull?.any((b) => b.format.hasSeries) ?? false;
    final selection = _selection;

    return PopScope(
      canPop: selection == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endSelection();
      },
      child: selection == null
          ? _scaffold(
              count: count,
              compact: compact,
              hasSeries: hasSeries,
              body: _body(visible, count, query, hasFolders),
            )
          : _selectionScaffold(
              selection: selection,
              compact: compact,
              volumes: [
                for (final b in booksOf(visible.valueOrNull ?? const []))
                  if (b.format.hasSeries) b,
              ],
              body: _body(visible, count, query, hasFolders),
            ),
    );
  }

  Widget _body(
    AsyncValue<List<LibraryEntry>> visible,
    int count,
    String query,
    bool hasFolders,
  ) {
    return Column(
      children: [
        const _ScanBanner(),
        Expanded(
          child: _LibraryBody(
            entries: visible,
            libraryEmpty: count == 0,
            filters: _filters,
            onFilters: (f) => setState(() => _filters = f),
            query: query,
            view: _view,
            hasFolders: hasFolders,
            onAddFolder: _addFolder,
            onRescan: _rescan,
            onBookMenu: _showBookMenu,
            selection: _selection,
            onToggle: _toggle,
          ),
        ),
      ],
    );
  }

  Widget _selectionScaffold({
    required Set<String> selection,
    required bool compact,
    required List<Book> volumes,
    required Widget body,
  }) {
    final n = selection.length;
    final allSelected =
        volumes.isNotEmpty && volumes.every((b) => selection.contains(b.id));
    return SectionScaffold(
      title: n == 0
          ? context.l10n.selectVolumes
          : context.l10n.selectedCount(n),
      onBack: _endSelection,
      backIcon: Icons.close,
      actions: [
        IconButton(
          onPressed: volumes.isEmpty ? null : () => _toggleAll(volumes),
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected
              ? context.l10n.clearSelection
              : context.l10n.selectAll,
        ),
        if (compact)
          IconButton.filled(
            onPressed: n == 0 ? null : () => unawaited(_moveSelection()),
            icon: const Icon(Icons.layers_outlined),
            tooltip: context.l10n.moveToSeries,
          )
        else
          FilledButton.icon(
            onPressed: n == 0 ? null : () => unawaited(_moveSelection()),
            icon: const Icon(Icons.layers_outlined, size: 18),
            label: Text(context.l10n.moveToSeries),
          ),
      ],
      child: body,
    );
  }

  Widget _scaffold({
    required int count,
    required bool compact,
    required bool hasSeries,
    required Widget body,
  }) {
    final filters = FiltersButton(
      key: _filtersKey,
      filters: _filters,
      onChanged: (f) => setState(() => _filters = f),
      iconOnly: compact,
    );
    final roomy = MediaQuery.sizeOf(context).width >= 1240;
    final more = _MoreMenu(
      onSelect: hasSeries ? _startSelection : null,
      onRescan: _rescan,
      onAddFolder: roomy ? null : _addFolder,
    );
    return SectionScaffold(
      title: context.l10n.library,
      subtitle: compact ? null : context.l10n.booksCount(count),
      actions: compact
          ? [
              filters,
              PopupMenuButton<_SortMode>(
                icon: const Icon(
                  Icons.sort,
                  size: 20,
                  color: LannaColors.textMuted,
                ),
                initialValue: _sort,
                tooltip: context.l10n.sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final m in _SortMode.values)
                    lannaChoiceItem(
                      value: m,
                      label: m.label(context.l10n),
                      selected: m == _sort,
                    ),
                ],
              ),
              more,
            ]
          : [
              _SortButton(
                sort: _sort,
                onChanged: (s) => setState(() => _sort = s),
              ),
              const SizedBox(width: LannaSpacing.s2),
              filters,
              const SizedBox(width: LannaSpacing.s2),
              _ViewToggle(
                view: _view,
                onChanged: (v) => setState(() => _view = v),
              ),
              const SizedBox(width: LannaSpacing.s1),
              more,
              if (roomy) ...[
                const SizedBox(width: LannaSpacing.s3),
                OutlinedButton.icon(
                  onPressed: _addFolder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LannaColors.text,
                    side: const BorderSide(color: LannaColors.border),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: LannaSpacing.s4,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: LannaRadii.brMd,
                    ),
                    textStyle: LannaType.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(context.l10n.addFolder),
                ),
              ],
            ],
      child: body,
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({
    required this.onSelect,
    required this.onRescan,
    required this.onAddFolder,
  });

  final VoidCallback? onSelect;
  final VoidCallback onRescan;
  final VoidCallback? onAddFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(libraryScanProvider.select((s) => s.running));
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l10n.more,
      position: PopupMenuPosition.under,
      icon: const Icon(
        Icons.more_horiz,
        size: 20,
        color: LannaColors.textMuted,
      ),
      onSelected: (value) => switch (value) {
        'select' => onSelect?.call(),
        'rescan' => onRescan(),
        'folder' => onAddFolder?.call(),
        _ => null,
      },
      itemBuilder: (_) => [
        if (onSelect != null)
          lannaMenuItem(
            value: 'select',
            icon: Icons.checklist,
            label: l10n.selectVolumesTooltip,
          ),
        if (!running)
          lannaMenuItem(
            value: 'rescan',
            icon: Icons.refresh,
            label: l10n.refreshLibrary,
          ),
        if (onAddFolder != null)
          lannaMenuItem(
            value: 'folder',
            icon: Icons.create_new_folder_outlined,
            label: l10n.addFolder,
          ),
      ],
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
                ? context.l10n.scanning
                : context.l10n.scanningProgress(scan.done, scan.total),
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

class _LibraryBody extends ConsumerWidget {
  const _LibraryBody({
    required this.entries,
    required this.libraryEmpty,
    required this.filters,
    required this.onFilters,
    required this.query,
    required this.view,
    required this.hasFolders,
    required this.onAddFolder,
    required this.onRescan,
    required this.onBookMenu,
    required this.selection,
    required this.onToggle,
  });

  final AsyncValue<List<LibraryEntry>> entries;
  final bool libraryEmpty;
  final LibraryFilters filters;
  final ValueChanged<LibraryFilters> onFilters;
  final String query;
  final _ViewMode view;
  final bool hasFolders;
  final VoidCallback onAddFolder;
  final Future<void> Function() onRescan;
  final void Function(Book book, Offset globalPosition) onBookMenu;
  final Set<String>? selection;
  final ValueChanged<List<Book>> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(progressByBookProvider).valueOrNull ??
        const <String, double>{};
    final searching = query.trim().isNotEmpty;
    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.errorDetail('$e'))),
      data: (entries) {
        if (libraryEmpty || (entries.isEmpty && !filters.active)) {
          return searching
              ? SectionEmpty(
                  icon: Icons.search_off,
                  message: context.l10n.noResultsFor(query),
                )
              : EmptyLibraryView(
                  hasFolders: hasFolders,
                  onAddFolder: onAddFolder,
                  onRescan: onRescan,
                );
        }
        return RefreshIndicator(
          onRefresh: onRescan,
          child: CustomScrollView(
            scrollCacheExtent: const ScrollCacheExtent.viewport(1),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (searching || filters.active)
                _SectionLabel(
                  searching ? context.l10n.results : context.l10n.allBooks,
                  trailing: '${booksOf(entries).length}',
                  action: filters.active && entries.isNotEmpty
                      ? TextButton(
                          onPressed: () => onFilters(const LibraryFilters()),
                          child: Text(context.l10n.clearFilters),
                        )
                      : null,
                )
              else
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s6),
                ),
              if (entries.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: LannaSpacing.s8,
                    ),
                    child: SectionEmpty(
                      icon: Icons.filter_alt_off_outlined,
                      message: context.l10n.noFilterMatches,
                      action: TextButton(
                        onPressed: () => onFilters(const LibraryFilters()),
                        child: Text(context.l10n.clearFilters),
                      ),
                    ),
                  ),
                )
              else if (view == _ViewMode.grid)
                LibraryGridSliver(
                  entries: entries,
                  progress: progress,
                  onMenu: onBookMenu,
                  onOpenSeries: (series) =>
                      unawaited(showSeries(context, series)),
                  selection: selection,
                  onToggle: onToggle,
                )
              else
                _BookListSliver(
                  entries: entries,
                  onMenu: onBookMenu,
                  selection: selection,
                  onToggle: onToggle,
                ),
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
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LannaType.lg.copyWith(
                        color: LannaColors.textStrong,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: LannaSpacing.s2),
                    Text(
                      trailing!,
                      style: LannaType.md.copyWith(
                        color: LannaColors.textMuted,
                        fontFeatures: LannaType.tabular,
                      ),
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
            label: mode.label(context.l10n),
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
              sort.label(context.l10n),
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
  const _BookListSliver({
    required this.entries,
    required this.onMenu,
    required this.selection,
    required this.onToggle,
  });
  final List<LibraryEntry> entries;
  final void Function(Book book, Offset globalPosition) onMenu;
  final Set<String>? selection;
  final ValueChanged<List<Book>> onToggle;

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverList.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: LannaColors.borderSubtle),
        itemBuilder: (context, i) => switch (entries[i]) {
          BookEntry(:final book) when selection == null => _BookRow(
            book: book,
            onMenu: onMenu,
          ),
          BookEntry(:final book) when !book.format.hasSeries => Unselectable(
            child: _BookRow(book: book, onMenu: onMenu),
          ),
          BookEntry(:final book) => _BookRow(
            book: book,
            onMenu: onMenu,
            selected: selection!.contains(book.id),
            onTap: () => onToggle([book]),
          ),
          final SeriesEntry series => _SeriesRow(
            series: series,
            selected: selection == null
                ? null
                : series.volumes.every((b) => selection.contains(b.id)),
            onTap: selection == null ? null : () => onToggle(series.volumes),
          ),
        },
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series, this.selected, this.onTap});
  final SeriesEntry series;
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = series.volumes.length;
    return InkWell(
      onTap: onTap ?? () => unawaited(showSeries(context, series)),
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
                    context.l10n.volumesCount(count),
                    style: LannaType.sm.copyWith(color: LannaColors.textMuted),
                  ),
                ],
              ),
            ),
            if (selected case final value?)
              SelectionIcon(selected: value)
            else
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
  const _BookRow({
    required this.book,
    required this.onMenu,
    this.selected,
    this.onTap,
  });
  final Book book;
  final void Function(Book book, Offset globalPosition) onMenu;
  final bool? selected;
  final VoidCallback? onTap;

  void _menuFromCenter(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    onMenu(book, box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    return InkWell(
      onTap: onTap ?? () => openBook(context, book),
      onLongPress: selected != null ? onTap : () => _menuFromCenter(context),
      onSecondaryTapUp: selected != null
          ? null
          : (d) => onMenu(book, d.globalPosition),
      child: CompactBookTile(
        book: book,
        subtitle: book.author,
        trailing: selected == null ? null : SelectionIcon(selected: selected),
      ),
    );
  }
}
