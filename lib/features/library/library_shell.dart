// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'widgets/library_sidebar.dart';

final librarySearchProvider = StateProvider<String>((ref) => '');

const _wideBreakpoint = 720.0;

class LibraryShell extends ConsumerStatefulWidget {
  const LibraryShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends ConsumerState<LibraryShell> {
  final _searchController = TextEditingController();
  LibrarySection? _lastSection;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LibrarySection _sectionFor(String path) {
    if (path.startsWith('/folders')) return LibrarySection.folders;
    if (path.startsWith('/collections')) return LibrarySection.collections;
    if (path.startsWith('/authors')) return LibrarySection.authors;
    if (path.startsWith('/settings')) return LibrarySection.settings;
    return LibrarySection.library;
  }

  void _onSearchChanged(String q) =>
      ref.read(librarySearchProvider.notifier).state = q;

  void _select(LibrarySection section, LibrarySection current) {
    if (section != current) goToLibrarySection(context, section);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final section = _sectionFor(path);
    if (_lastSection != null && _lastSection != section) {
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(librarySearchProvider.notifier).state = '';
      });
    }
    _lastSection = section;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return _wide(section);
        }
        return _narrow(section);
      },
    );
  }

  Widget _wide(LibrarySection section) {
    return Scaffold(
      backgroundColor: LannaColors.bg,
      body: SafeArea(
        left: false,
        right: false,
        child: Row(
          children: [
            LibrarySidebar(
              active: section,
              onSelect: (s) => _select(s, section),
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _narrow(LibrarySection section) {
    final showSearch = section != LibrarySection.settings;
    return Scaffold(
      backgroundColor: LannaColors.bg,
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LannaSpacing.s4,
                  LannaSpacing.s3,
                  LannaSpacing.s4,
                  LannaSpacing.s2,
                ),
                child: LibrarySearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                ),
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: librarySections.indexWhere((e) => e.$3 == section),
        onDestinationSelected: (i) => _select(librarySections[i].$3, section),
        destinations: [
          for (final item in librarySections)
            NavigationDestination(icon: Icon(item.$1), label: item.$2),
        ],
      ),
    );
  }
}
