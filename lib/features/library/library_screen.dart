// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/fade_in.dart';
import '../../data/book_repository.dart';
import '../../data/library/library_scanner.dart';
import '../../data/local/app_database.dart';
import 'book_search.dart';
import 'library_scan_controller.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_grid.dart';
import 'widgets/continue_reading_row.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/section_scaffold.dart';

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

  Future<void> _addFolder() async {
    await _report(ref.read(libraryScanProvider.notifier).addFolder());
  }

  Future<void> _rescan() async {
    await _report(ref.read(libraryScanProvider.notifier).scan());
  }

  Future<void> _report(Future<ScanReport?> work) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await work;
      if (report == null || !mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(describeScan(report))));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo revisar la carpeta: $e')),
      );
    }
  }

  void _showBookMenu(Book book, Offset globalPosition) {
    unawaited(showBookMenu(context, ref, book, globalPosition));
  }

  List<Book> _filteredSorted(List<Book> books, String rawQuery) {
    final query = foldForSearch(rawQuery);
    final matched = query.isEmpty
        ? books
        : books.where((b) => bookMatches(b, query)).toList();
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
    final scan = ref.watch(libraryScanProvider);
    final hasFolders =
        ref.watch(libraryFoldersProvider).valueOrNull?.isNotEmpty ?? false;
    final query = ref.watch(librarySearchProvider);
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
                    PopupMenuItem(value: m, child: Text(m.label)),
                ],
              ),
              IconButton(
                onPressed: scan.running ? null : _rescan,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar biblioteca',
              ),
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
              IconButton(
                onPressed: scan.running ? null : _rescan,
                icon: const Icon(Icons.refresh, size: 20),
                color: LannaColors.textMuted,
                tooltip: 'Actualizar biblioteca',
              ),
              FilledButton.icon(
                onPressed: _addFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Añadir carpeta'),
              ),
            ],
      child: Column(
        children: [
          if (scan.running) _ScanBanner(scan: scan),
          Expanded(
            child: _LibraryBody(
              library: library.whenData(
                (books) => _filteredSorted(books, query),
              ),
              continueReading: query.isEmpty ? continueReading : const [],
              query: query,
              view: _view,
              hasFolders: hasFolders,
              scanning: scan.running,
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

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.scan});

  final ScanState scan;

  @override
  Widget build(BuildContext context) {
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
    required this.continueReading,
    required this.query,
    required this.view,
    required this.hasFolders,
    required this.scanning,
    required this.onAddFolder,
    required this.onRescan,
    required this.onBookMenu,
  });

  final AsyncValue<List<Book>> library;
  final List<BookWithProgress> continueReading;
  final String query;
  final _ViewMode view;
  final bool hasFolders;
  final bool scanning;
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
        if (books.isEmpty) {
          return searching
              ? SectionEmpty(
                  icon: Icons.search_off,
                  message: 'Sin resultados para «$query»',
                )
              : FadeIn(
                  child: EmptyLibraryView(
                    hasFolders: hasFolders,
                    scanning: scanning,
                    onAddFolder: onAddFolder,
                    onRescan: onRescan,
                  ),
                );
        }
        return RefreshIndicator(
          onRefresh: onRescan,
          child: CustomScrollView(
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
              ),
              if (view == _ViewMode.grid)
                BookGridSliver(books: books, onMenu: onBookMenu)
              else
                _BookListSliver(books: books, onMenu: onBookMenu),
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
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final String? trailing;

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
            Text(
              text.toUpperCase(),
              style: LannaType.xs.copyWith(color: LannaColors.textMuted),
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
          PopupMenuItem(value: mode, child: Text(mode.label)),
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
  const _BookListSliver({required this.books, required this.onMenu});
  final List<Book> books;
  final void Function(Book book, Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverList.separated(
        itemCount: books.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: LannaColors.borderSubtle),
        itemBuilder: (context, i) => _BookRow(book: books[i], onMenu: onMenu),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s3),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Opacity(
                opacity: book.available ? 1 : 0.4,
                child: BookCover(book: book),
              ),
            ),
            const SizedBox(width: LannaSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.md.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (book.author != null)
                    Text(
                      book.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LannaType.sm.copyWith(
                        color: LannaColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
