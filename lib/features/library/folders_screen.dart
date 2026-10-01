// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/comic/comic_book.dart';
import '../../data/local/app_database.dart';
import 'library_scan_controller.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_grid.dart';
import 'widgets/section_scaffold.dart';

class FolderLevel {
  const FolderLevel({required this.folders, required this.books});

  final List<({String name, int count})> folders;
  final List<Book> books;
}

FolderLevel browseFolder(List<Book> books, List<String> path) {
  final prefix = path.isEmpty ? '' : '${path.join('/')}/';
  final counts = <String, int>{};
  final here = <Book>[];
  for (final book in books) {
    final relative = book.relativePath;
    if (relative == null || !relative.startsWith(prefix)) continue;
    final rest = relative.substring(prefix.length);
    final slash = rest.indexOf('/');
    if (slash < 0) {
      here.add(book);
    } else {
      final name = rest.substring(0, slash);
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  final names = counts.keys.toList()..sort(compareNatural);
  here.sort((a, b) => compareNatural(a.relativePath!, b.relativePath!));
  return FolderLevel(
    folders: [for (final n in names) (name: n, count: counts[n]!)],
    books: here,
  );
}

List<Book> booksUnder(List<Book> books, List<String> path) {
  final prefix = path.isEmpty ? '' : '${path.join('/')}/';
  return [
    for (final b in books)
      if (b.relativePath?.startsWith(prefix) ?? false) b,
  ];
}

class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  String? _folderId;
  List<String> _path = const [];

  void _enter(String name) => setState(() => _path = [..._path, name]);

  void _up(bool single) => setState(() {
    if (_path.isNotEmpty) {
      _path = _path.sublist(0, _path.length - 1);
    } else if (!single) {
      _folderId = null;
    }
  });

  Future<void> _addFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await ref.read(libraryScanProvider.notifier).addFolder();
      if (report != null) {
        messenger.showSnackBar(SnackBar(content: Text(describeScan(report))));
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo revisar la carpeta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(libraryFoldersProvider).valueOrNull ?? const [];
    final books = ref.watch(libraryProvider).valueOrNull ?? const <Book>[];
    final query = foldForSearch(ref.watch(librarySearchProvider));

    if (folders.isEmpty) {
      return SectionScaffold(
        title: 'Carpetas',
        child: SectionEmpty(
          icon: Icons.folder_outlined,
          message: 'Todavía no elegiste ninguna carpeta',
          action: FilledButton.icon(
            onPressed: _addFolder,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('Elegir carpeta'),
          ),
        ),
      );
    }

    final single = folders.length == 1;
    final folder = single
        ? folders.single
        : folders.where((f) => f.id == _folderId).firstOrNull;

    if (folder == null) {
      return SectionScaffold(
        title: 'Carpetas',
        subtitle:
            '${folders.length} ${folders.length == 1 ? 'carpeta' : 'carpetas'}',
        child: _FolderList(
          entries: [
            for (final f in folders)
              if (query.isEmpty || matchesQuery(f.name, query))
                (
                  name: f.name,
                  count: books.where((b) => b.folderId == f.id).length,
                ),
          ],
          onTap: (name) => setState(() {
            _folderId = folders.firstWhere((f) => f.name == name).id;
            _path = const [];
          }),
        ),
      );
    }

    final inFolder = [
      for (final b in books)
        if (b.folderId == folder.id) b,
    ];
    final atRoot = _path.isEmpty;
    final title = atRoot ? folder.name : _path.last;
    final crumbs = [folder.name, ..._path];

    final Widget body;
    if (query.isNotEmpty) {
      final matches = [
        for (final b in booksUnder(inFolder, _path))
          if (matchesQuery(b.title, query) ||
              matchesQuery(b.author ?? '', query))
            b,
      ];
      body = matches.isEmpty
          ? const SectionEmpty(
              icon: Icons.search_off,
              message: 'Sin resultados en esta carpeta',
            )
          : _LevelView(
              level: FolderLevel(folders: const [], books: matches),
              onEnter: _enter,
            );
    } else {
      final level = browseFolder(inFolder, _path);
      body = level.folders.isEmpty && level.books.isEmpty
          ? const SectionEmpty(
              icon: Icons.folder_open_outlined,
              message: 'Esta carpeta no tiene libros',
            )
          : _LevelView(level: level, onEnter: _enter);
    }

    final canGoUp = !atRoot || !single;
    return PopScope(
      canPop: !canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoUp) _up(single);
      },
      child: SectionScaffold(
        title: title,
        subtitle: crumbs.join('  ›  '),
        onBack: canGoUp ? () => _up(single) : null,
        child: body,
      ),
    );
  }
}

class _LevelView extends ConsumerWidget {
  const _LevelView({required this.level, required this.onEnter});

  final FolderLevel level;
  final ValueChanged<String> onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        if (level.folders.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(top: LannaSpacing.s2),
            sliver: SliverList.separated(
              itemCount: level.folders.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: LannaSpacing.s6,
                color: LannaColors.borderSubtle,
              ),
              itemBuilder: (context, i) {
                final entry = level.folders[i];
                return _FolderTile(
                  name: entry.name,
                  count: entry.count,
                  onTap: () => onEnter(entry.name),
                );
              },
            ),
          ),
        if (level.books.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: LannaSpacing.s5)),
          BookGridSliver(
            books: level.books,
            onMenu: (book, pos) =>
                unawaited(showBookMenu(context, ref, book, pos)),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: LannaSpacing.s6)),
      ],
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.entries, required this.onTap});

  final List<({String name, int count})> entries;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: LannaSpacing.s6,
        color: LannaColors.borderSubtle,
      ),
      itemBuilder: (context, i) => _FolderTile(
        name: entries[i].name,
        count: entries[i].count,
        onTap: () => onTap(entries[i].name),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      leading: const Icon(Icons.folder_outlined, color: LannaColors.textMuted),
      title: Text(name, style: LannaType.base),
      trailing: Text(
        '$count ${count == 1 ? 'libro' : 'libros'}',
        style: LannaType.sm.copyWith(color: LannaColors.textMuted),
      ),
      onTap: onTap,
    );
  }
}
