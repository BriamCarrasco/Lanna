// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_grid.dart';
import 'widgets/section_scaffold.dart';

class AuthorsScreen extends ConsumerStatefulWidget {
  const AuthorsScreen({super.key});

  @override
  ConsumerState<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends ConsumerState<AuthorsScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(libraryProvider).valueOrNull ?? const <Book>[];
    final query = foldForSearch(ref.watch(librarySearchProvider));

    final byAuthor = <String, List<Book>>{};
    for (final book in books) {
      final key = (book.author?.trim().isNotEmpty ?? false)
          ? book.author!.trim()
          : 'Sin autor';
      byAuthor.putIfAbsent(key, () => []).add(book);
    }
    var authors = byAuthor.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_selected == null && query.isNotEmpty) {
      authors = authors.where((a) => matchesQuery(a, query)).toList();
    }

    final selectedBooks = _selected == null
        ? const <Book>[]
        : byAuthor[_selected] ?? const <Book>[];

    return SectionScaffold(
      title: _selected ?? 'Autores',
      subtitle: _selected == null
          ? '${authors.length} ${authors.length == 1 ? 'autor' : 'autores'}'
          : '${selectedBooks.length} '
                '${selectedBooks.length == 1 ? 'libro' : 'libros'}',
      onBack: _selected == null ? null : () => setState(() => _selected = null),
      child: _selected == null
          ? _AuthorList(
              authors: authors,
              countFor: (a) => byAuthor[a]!.length,
              onTap: (a) => setState(() => _selected = a),
            )
          : CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s5),
                ),
                BookGridSliver(
                  books: selectedBooks,
                  onMenu: (book, pos) => showBookMenu(context, ref, book, pos),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s6),
                ),
              ],
            ),
    );
  }
}

class _AuthorList extends StatelessWidget {
  const _AuthorList({
    required this.authors,
    required this.countFor,
    required this.onTap,
  });

  final List<String> authors;
  final int Function(String) countFor;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (authors.isEmpty) {
      return const SectionEmpty(
        icon: Icons.person_outline,
        message: 'No hay libros en la biblioteca',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
      itemCount: authors.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: LannaSpacing.s6,
        color: LannaColors.borderSubtle,
      ),
      itemBuilder: (context, i) {
        final author = authors[i];
        final count = countFor(author);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: LannaSpacing.s6,
          ),
          title: Text(author, style: LannaType.base),
          trailing: Text(
            '$count ${count == 1 ? 'libro' : 'libros'}',
            style: LannaType.sm.copyWith(color: LannaColors.textMuted),
          ),
          onTap: () => onTap(author),
        );
      },
    );
  }
}
