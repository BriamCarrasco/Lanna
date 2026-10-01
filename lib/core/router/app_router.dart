// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/authors_screen.dart';
import '../../features/library/collections_screen.dart';
import '../../features/library/folders_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/library_shell.dart';
import '../../features/reader/reader_entry.dart';
import '../../features/settings/settings_screen.dart';
import '../theme/tokens.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/reader/:bookId',
        name: 'reader',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: ReaderEntry(bookId: state.pathParameters['bookId']!),
          transitionDuration: LannaMotion.base,
          reverseTransitionDuration: LannaMotion.fast,
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: LannaMotion.ease,
                ),
                child: child,
              ),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => LibraryShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/folders',
            name: 'folders',
            builder: (context, state) => const FoldersScreen(),
          ),
          GoRoute(
            path: '/authors',
            name: 'authors',
            builder: (context, state) => const AuthorsScreen(),
          ),
          GoRoute(
            path: '/collections',
            name: 'collections',
            builder: (context, state) => const CollectionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'collection',
                builder: (context, state) =>
                    CollectionScreen(collectionId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
