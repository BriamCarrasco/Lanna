// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/text_search.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'book_search.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_grid.dart';
import 'widgets/section_scaffold.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites =
        ref.watch(favoritesProvider).valueOrNull ?? const <Book>[];
    final query = foldForSearch(ref.watch(librarySearchProvider));
    final shown = [
      for (final b in favorites)
        if (bookMatches(b, query)) b,
    ];

    return SectionScaffold(
      title: 'Favoritos',
      subtitle:
          '${favorites.length} ${favorites.length == 1 ? 'libro' : 'libros'}',
      child: favorites.isEmpty
          ? const SectionEmpty(
              icon: Icons.favorite_border,
              message:
                  'Todavía no tienes favoritos. Abre el menú de un libro '
                  '(clic derecho o mantener presionado) y elige '
                  '«Añadir a favoritos».',
            )
          : shown.isEmpty
          ? const SectionEmpty(
              icon: Icons.search_off,
              message: 'Sin resultados en tus favoritos',
            )
          : CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s5),
                ),
                BookGridSliver(
                  books: shown,
                  onMenu: (book, pos) =>
                      unawaited(showBookMenu(context, ref, book, pos)),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s6),
                ),
              ],
            ),
    );
  }
}
