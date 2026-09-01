// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'import_controller.dart';
import 'widgets/book_cover.dart';
import 'widgets/continue_reading_row.dart';
import 'widgets/empty_library_view.dart';
import 'widgets/import_progress_card.dart';
import 'widgets/library_sidebar.dart';

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

  void _onSection(LibrarySection section) {
    if (section == LibrarySection.library) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Próximamente')));
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
    final showOverlay = !import.isEmpty && !_overlayHidden;

    return Scaffold(
      body: Row(
        children: [
          LibrarySidebar(
            active: LibrarySection.library,
            onSelect: _onSection,
            onSearchTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Búsqueda: próximamente')),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      count: library.valueOrNull?.length ?? 0,
                      sort: _sort,
                      view: _view,
                      onSort: (s) => setState(() => _sort = s),
                      onView: (v) => setState(() => _view = v),
                      onImport: _pickAndImport,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: DropTarget(
                        onDragEntered: (_) => setState(() => _dragging = true),
                        onDragExited: (_) => setState(() => _dragging = false),
                        onDragDone: (detail) {
                          setState(() => _dragging = false);
                          _startImport(
                            detail.files.map((f) => f.path).toList(),
                          );
                        },
                        child: _LibraryBody(
                          library: library.whenData(_sorted),
                          continueReading: continueReading,
                          view: _view,
                          dragging: _dragging,
                          onImport: _pickAndImport,
                        ),
                      ),
                    ),
                  ],
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
    required this.view,
    required this.dragging,
    required this.onImport,
  });

  final AsyncValue<List<Book>> library;
  final List<BookWithProgress> continueReading;
  final _ViewMode view;
  final bool dragging;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final content = library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (books) => books.isEmpty
          ? EmptyLibraryView(onImport: onImport)
          : CustomScrollView(
              slivers: [
                if (continueReading.isNotEmpty) ...[
                  const _SectionLabel('Seguir leyendo'),
                  SliverToBoxAdapter(
                    child: ContinueReadingRow(items: continueReading),
                  ),
                ],
                _SectionLabel('Todos los libros', trailing: '${books.length}'),
                if (view == _ViewMode.grid)
                  _BookGridSliver(books: books)
                else
                  _BookListSliver(books: books),
                const SliverToBoxAdapter(child: SizedBox(height: 26)),
              ],
            ),
    );

    return Stack(
      children: [
        content,
        if (dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LannaColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LannaColors.accent, width: 2),
                ),
                child: const Center(
                  child: Text(
                    'Suelta para importar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LannaColors.accentStrong,
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
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 12),
        child: Row(
          children: [
            Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
                color: LannaColors.textMuted,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: LannaColors.border,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.sort,
    required this.view,
    required this.onSort,
    required this.onView,
    required this.onImport,
  });

  final int count;
  final _SortMode sort;
  final _ViewMode view;
  final ValueChanged<_SortMode> onSort;
  final ValueChanged<_ViewMode> onView;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: LannaColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Biblioteca',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '$count ${count == 1 ? 'libro' : 'libros'}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LannaColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ViewToggle(view: view, onChanged: onView),
          const SizedBox(width: 10),
          _SortButton(sort: sort, onChanged: onSort),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Importar'),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
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
        borderRadius: BorderRadius.circular(8),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: LannaColors.bg,
          border: Border.all(color: LannaColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.label,
              style: const TextStyle(fontSize: 13, color: LannaColors.text),
            ),
            const SizedBox(width: 6),
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

class _BookGridSliver extends StatelessWidget {
  const _BookGridSliver({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 168,
          childAspectRatio: 0.54,
          crossAxisSpacing: 20,
          mainAxisSpacing: 22,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => _GridTile(book: books[i]),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => context.push('/reader/${book.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: BookCover(book: book),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (book.author != null)
            Text(
              book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: LannaColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _BookListSliver extends StatelessWidget {
  const _BookListSliver({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      sliver: SliverList.separated(
        itemCount: books.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final book = books[i];
          return InkWell(
            onTap: () => context.push('/reader/${book.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: 34, child: BookCover(book: book)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (book.author != null)
                          Text(
                            book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
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
        },
      ),
    );
  }
}
