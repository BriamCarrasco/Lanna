// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/l10n.dart';
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
  final _searchFocus = FocusNode(debugLabel: 'búsqueda');
  LibrarySection? _lastSection;
  bool _searchFromHome = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    if (_searchFocus.context == null) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _searchFocus.hasFocus) {
      _searchController.clear();
      _onSearchChanged('');
      _searchFocus.unfocus();
      return true;
    }

    final keyboard = HardwareKeyboard.instance;
    final find =
        event.logicalKey == LogicalKeyboardKey.keyF &&
        (keyboard.isControlPressed || keyboard.isMetaPressed);
    final slash = event.character == '/' && !_typing();
    if (!find && !slash) return false;

    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    return true;
  }

  bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        (context.widget is EditableText ||
            context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  LibrarySection _sectionFor(String path) {
    if (path.startsWith('/favorites')) return LibrarySection.favorites;
    if (path.startsWith('/folders')) return LibrarySection.folders;
    if (path.startsWith('/collections')) return LibrarySection.collections;
    if (path.startsWith('/authors')) return LibrarySection.authors;
    if (path.startsWith('/stats')) return LibrarySection.stats;
    if (path.startsWith('/settings')) return LibrarySection.settings;
    if (path.startsWith('/library')) return LibrarySection.library;
    return LibrarySection.home;
  }

  void _onSearchChanged(String q) {
    ref.read(librarySearchProvider.notifier).state = q;
    if (q.isNotEmpty &&
        _sectionFor(GoRouterState.of(context).uri.path) ==
            LibrarySection.home) {
      _searchFromHome = true;
      context.go('/library');
    }
  }

  void _select(LibrarySection section, LibrarySection current) {
    if (section != current) goToLibrarySection(context, section);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final section = _sectionFor(path);
    if (_lastSection != null && _lastSection != section && !_searchFromHome) {
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(librarySearchProvider.notifier).state = '';
      });
    }
    _lastSection = section;
    _searchFromHome = false;

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
              searchFocusNode: _searchFocus,
              onSearchChanged: _onSearchChanged,
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _narrow(LibrarySection section) {
    final showSearch =
        section != LibrarySection.settings &&
        section != LibrarySection.stats &&
        section != LibrarySection.home;
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
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                ),
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final sections = librarySections(context.l10n);
          final theme = NavigationBarTheme.of(context);
          final label = _fittedLabelStyle(
            context,
            theme.labelTextStyle?.resolve({}) ?? const TextStyle(),
            [for (final s in sections) s.$2],
            constraints.maxWidth / sections.length,
          );
          return NavigationBarTheme(
            data: theme.copyWith(
              labelTextStyle: label == null
                  ? null
                  : WidgetStateProperty.all(label),
            ),
            child: NavigationBar(
              selectedIndex: sections.indexWhere((e) => e.$3 == section),
              onDestinationSelected: (i) => _select(sections[i].$3, section),
              labelBehavior: label == null
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final item in sections)
                  NavigationDestination(icon: Icon(item.$1), label: item.$2),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _minLabelSize = 8.5;

  TextStyle? _fittedLabelStyle(
    BuildContext context,
    TextStyle style,
    List<String> labels,
    double slot,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final available = slot - 4;
    if (widest <= available) return style;
    final size = (style.fontSize ?? 12) * available / widest;
    return size < _minLabelSize ? null : style.copyWith(fontSize: size);
  }
}
