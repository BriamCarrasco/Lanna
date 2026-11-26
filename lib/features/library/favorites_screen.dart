// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/text_search.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';
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
      title: context.l10n.favorites,
      subtitle: context.l10n.booksCount(favorites.length),
      child: switch ((favorites.isEmpty, shown.isEmpty)) {
        (true, _) => EmptyIntro(
          title: context.l10n.noFavoritesTitle,
          message: Platform.isAndroid || Platform.isIOS
              ? context.l10n.noFavoritesHintTouch
              : context.l10n.noFavoritesHintPointer,
          action: OutlinedButton(
            onPressed: () => context.go('/library'),
            child: Text(context.l10n.goToLibrary),
          ),
        ),
        (_, true) => SectionEmpty(
          icon: Icons.search_off,
          message: context.l10n.noFavoritesResults,
        ),
        _ => CustomScrollView(
          scrollCacheExtent: const ScrollCacheExtent.viewport(1),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: LannaSpacing.s5)),
            BookGridSliver(
              books: shown,
              onMenu: (book, pos) =>
                  unawaited(showBookMenu(context, ref, book, pos)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: LannaSpacing.s6)),
          ],
        ),
      },
    );
  }
}
