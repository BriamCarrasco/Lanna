// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/library_screen.dart';
import '../../features/reader/reader_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
        routes: [
          GoRoute(
            path: 'reader/:bookId',
            name: 'reader',
            builder: (context, state) =>
                ReaderScreen(bookId: state.pathParameters['bookId']!),
          ),
        ],
      ),
    ],
  );
});
