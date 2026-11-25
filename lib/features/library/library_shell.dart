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
import 'widgets/section_scaffold.dart';

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
  final _tabActions = SectionActionsNotifier();
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
    _tabActions.dispose();
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

  static const _bottomSections = [
    LibrarySection.home,
    LibrarySection.library,
    LibrarySection.stats,
    LibrarySection.settings,
  ];

  static const _librarySubsections = [
    LibrarySection.library,
    LibrarySection.favorites,
    LibrarySection.folders,
    LibrarySection.collections,
    LibrarySection.authors,
  ];

  Widget _narrow(LibrarySection section) {
    final inLibrary = _librarySubsections.contains(section);
    final barSection = inLibrary ? LibrarySection.library : section;
    final all = librarySections(context.l10n);
    final sections = [
      for (final s in _bottomSections) all.firstWhere((e) => e.$3 == s),
    ];
    return Scaffold(
      backgroundColor: LannaColors.bg,
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            if (inLibrary) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LannaSpacing.s4,
                  LannaSpacing.s3,
                  LannaSpacing.s2,
                  LannaSpacing.s1,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: LibrarySearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      ValueListenableBuilder<SectionActions?>(
                        valueListenable: _tabActions,
                        builder: (context, value, _) {
                          final actions = value?.widgets ?? const <Widget>[];
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: LannaSpacing.s1),
                              ...actions,
                              if (actions.isEmpty)
                                const SizedBox(width: LannaSpacing.s1),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _LibraryTabs(
                tabs: [
                  for (final s in _librarySubsections)
                    (
                      s,
                      s == LibrarySection.library
                          ? context.l10n.libraryAll
                          : all.firstWhere((e) => e.$3 == s).$2,
                    ),
                ],
                active: section,
                onSelect: (s) => _select(s, section),
              ),
            ],
            Expanded(
              child: inLibrary
                  ? SectionTabsScope(actions: _tabActions, child: widget.child)
                  : widget.child,
            ),
          ],
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
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
              selectedIndex: sections.indexWhere((e) => e.$3 == barSection),
              onDestinationSelected: (i) => _select(sections[i].$3, section),
              labelBehavior: label == null
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.alwaysShow,
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

class _LibraryTabs extends StatefulWidget {
  const _LibraryTabs({
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  final List<(LibrarySection, String)> tabs;
  final LibrarySection active;
  final ValueChanged<LibrarySection> onSelect;

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs> {
  final _keys = <LibrarySection, GlobalKey>{};

  GlobalKey _keyFor(LibrarySection s) => _keys.putIfAbsent(s, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(_LibraryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _reveal(animate: true);
  }

  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[widget.active]?.currentContext;
      if (context == null || !context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: animate ? LannaMotion.slow : Duration.zero,
        curve: LannaMotion.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LannaColors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s2),
        child: Row(
          children: [
            for (final (section, label) in widget.tabs)
              _LibraryTab(
                key: _keyFor(section),
                label: label,
                selected: section == widget.active,
                onTap: () => widget.onSelect(section),
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s3 - 1),
          child: AnimatedContainer(
            duration: LannaMotion.base,
            curve: LannaMotion.ease,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? LannaColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: LannaType.md.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? LannaColors.textStrong
                    : LannaColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
