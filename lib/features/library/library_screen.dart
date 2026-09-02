// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/fade_in.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'import_controller.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_cover.dart';
import 'widgets/book_grid.dart';
import 'widgets/continue_reading_row.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/import_progress_card.dart';
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
  bool _dragging = false;
  bool _overlayHidden = false;
  _SortMode _sort = _SortMode.recent;
  _ViewMode _view = _ViewMode.grid;

  static const _extensions = ['epub', 'pdf'];

  Future<void> _pickAndImport() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      dialogTitle: 'Importar libros',
    );
    if (files.isEmpty) return;
    _startImport(files.map((f) => f.path).whereType<String>().toList());
  }

  void _startImport(List<String> paths) {
    if (paths.isEmpty) return;
    setState(() => _overlayHidden = false);
    ref.read(importControllerProvider.notifier).importPaths(paths);
  }

  void _showBookMenu(Book book, Offset globalPosition) {
    unawaited(showBookMenu(context, ref, book, globalPosition));
  }

  List<Book> _filteredSorted(List<Book> books, String rawQuery) {
    final query = foldForSearch(rawQuery);
    final matched = query.isEmpty
        ? books
        : books
              .where(
                (b) =>
                    matchesQuery(b.title, query) ||
                    matchesQuery(b.author ?? '', query),
              )
              .toList();
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
    final import = ref.watch(importControllerProvider);
    final query = ref.watch(librarySearchProvider);
    final showOverlay = !import.isEmpty && !_overlayHidden;
    final count = library.valueOrNull?.length ?? 0;
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Stack(
      children: [
        SectionScaffold(
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
                    onPressed: _pickAndImport,
                    icon: const Icon(Icons.add),
                    tooltip: 'Importar libros',
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
                  FilledButton.icon(
                    onPressed: _pickAndImport,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Importar'),
                  ),
                ],
          child: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (detail) {
              setState(() => _dragging = false);
              _startImport(detail.files.map((f) => f.path).toList());
            },
            child: _LibraryBody(
              library: library.whenData(
                (books) => _filteredSorted(books, query),
              ),
              continueReading: query.isEmpty ? continueReading : const [],
              query: query,
              view: _view,
              dragging: _dragging,
              onImport: _pickAndImport,
              onBookMenu: _showBookMenu,
            ),
          ),
        ),
        if (showOverlay)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.55),
              child: ImportProgressCard(
                progress: import,
                onDismiss: () {
                  if (import.isRunning) {
                    setState(() => _overlayHidden = true);
                  } else {
                    ref.read(importControllerProvider.notifier).clear();
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.library,
    required this.continueReading,
    required this.query,
    required this.view,
    required this.dragging,
    required this.onImport,
    required this.onBookMenu,
  });

  final AsyncValue<List<Book>> library;
  final List<BookWithProgress> continueReading;
  final String query;
  final _ViewMode view;
  final bool dragging;
  final VoidCallback onImport;
  final void Function(Book book, Offset globalPosition) onBookMenu;

  @override
  Widget build(BuildContext context) {
    final searching = query.trim().isNotEmpty;
    final content = library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (books) {
        if (books.isEmpty) {
          return searching
              ? SectionEmpty(
                  icon: Icons.search_off,
                  message: 'Sin resultados para «$query»',
                )
              : FadeIn(child: EmptyLibraryView(onImport: onImport));
        }
        return CustomScrollView(
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
            const SliverToBoxAdapter(child: SizedBox(height: LannaSpacing.s6)),
          ],
        );
      },
    );

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: dragging ? 1 : 0,
              duration: LannaMotion.fast,
              curve: LannaMotion.ease,
              child: Container(
                margin: const EdgeInsets.all(LannaSpacing.s3),
                decoration: BoxDecoration(
                  color: LannaColors.accentTint,
                  borderRadius: LannaRadii.brXl,
                  border: Border.all(color: LannaColors.accent, width: 2),
                ),
                child: Center(
                  child: Text(
                    'Suelta para importar',
                    style: LannaType.lg.copyWith(
                      color: LannaColors.accentStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
      onTap: () => context.push('/reader/${book.id}'),
      onLongPress: () => _menuFromCenter(context),
      onSecondaryTapUp: (d) => onMenu(book, d.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s3),
        child: Row(
          children: [
            SizedBox(width: 34, child: BookCover(book: book)),
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
