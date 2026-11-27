// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/l10n.dart';
import 'authors_screen.dart';
import 'collections_screen.dart';
import 'favorites_screen.dart';
import 'folders_screen.dart';
import 'library_screen.dart';
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
  final _tabActions = {
    for (final s in _librarySubsections) s: SectionActionsNotifier(),
  };
  final _swipePosition = ValueNotifier<double>(0);
  bool _swiping = false;
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
    for (final notifier in _tabActions.values) {
      notifier.dispose();
    }
    _swipePosition.dispose();
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
        return _narrow(section, path);
      },
    );
  }

  Widget _wide(LibrarySection section) {
    _swiping = false;
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

  static const _swipeRoots = {
    '/library',
    '/favorites',
    '/folders',
    '/collections',
    '/authors',
  };

  static Widget _screenFor(LibrarySection section) => switch (section) {
    LibrarySection.favorites => const FavoritesScreen(),
    LibrarySection.folders => const FoldersScreen(),
    LibrarySection.collections => const CollectionsScreen(),
    LibrarySection.authors => const AuthorsScreen(),
    _ => const LibraryScreen(),
  };

  Widget _narrow(LibrarySection section, String path) {
    final inLibrary = _librarySubsections.contains(section);
    final swipe = inLibrary && _swipeRoots.contains(path);
    if (swipe && !_swiping) {
      _swipePosition.value = _librarySubsections.indexOf(section).toDouble();
    }
    _swiping = swipe;
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
                      ValueListenableBuilder<double>(
                        valueListenable: _swipePosition,
                        builder: (context, position, _) {
                          final shown = swipe
                              ? _librarySubsections[position.round().clamp(
                                  0,
                                  _librarySubsections.length - 1,
                                )]
                              : section;
                          return ValueListenableBuilder<SectionActions?>(
                            valueListenable: _tabActions[shown]!,
                            builder: (context, value, _) {
                              final actions =
                                  value?.widgets ?? const <Widget>[];
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
                position: swipe ? _swipePosition : null,
                onSelect: (s) => _select(s, section),
              ),
            ],
            Expanded(
              child: !inLibrary
                  ? widget.child
                  : swipe
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _Dormant(child: widget.child),
                        Positioned.fill(
                          child: _SwipeSections(
                            sections: _librarySubsections,
                            active: section,
                            position: _swipePosition,
                            onSettled: (s) => _select(s, section),
                            pageFor: (s) => SectionTabsScope(
                              actions: _tabActions[s]!,
                              child: _screenFor(s),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SectionTabsScope(
                      actions: _tabActions[section]!,
                      child: widget.child,
                    ),
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

class _Dormant extends SingleChildRenderObjectWidget {
  const _Dormant({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDormant();

  @override
  SingleChildRenderObjectElement createElement() => _DormantElement(this);
}

class _DormantElement extends SingleChildRenderObjectElement {
  _DormantElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {}
}

class _RenderDormant extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

class _SwipeSections extends StatefulWidget {
  const _SwipeSections({
    required this.sections,
    required this.active,
    required this.position,
    required this.onSettled,
    required this.pageFor,
  });

  final List<LibrarySection> sections;
  final LibrarySection active;
  final ValueNotifier<double> position;
  final ValueChanged<LibrarySection> onSettled;
  final Widget Function(LibrarySection section) pageFor;

  @override
  State<_SwipeSections> createState() => _SwipeSectionsState();
}

class _SwipeSectionsState extends State<_SwipeSections> {
  late final PageController _controller = PageController(
    initialPage: _indexOf(widget.active),
  )..addListener(_track);

  void _track() {
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page != null) widget.position.value = page;
  }

  int _indexOf(LibrarySection section) =>
      math.max(0, widget.sections.indexOf(section));

  @override
  void didUpdateWidget(_SwipeSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    final target = _indexOf(widget.active);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final page = _controller.page?.round() ?? target;
      if (page == target) return;
      if ((page - target).abs() == 1) {
        _controller.animateToPage(
          target,
          duration: LannaMotion.slow,
          curve: LannaMotion.ease,
        );
      } else {
        _controller.jumpToPage(target);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 || !_controller.hasClients) return false;
    final page = _controller.page?.round();
    if (page == null) return false;
    final section = widget.sections[page];
    if (section != widget.active) widget.onSettled(section);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.sections.length,
        itemBuilder: (context, i) => widget.pageFor(widget.sections[i]),
      ),
    );
  }
}

class _LibraryTabs extends StatefulWidget {
  const _LibraryTabs({
    required this.tabs,
    required this.active,
    required this.onSelect,
    this.position,
  });

  final List<(LibrarySection, String)> tabs;
  final LibrarySection active;
  final ValueListenable<double>? position;
  final ValueChanged<LibrarySection> onSelect;

  @override
  State<_LibraryTabs> createState() => _LibraryTabsState();
}

class _LibraryTabsState extends State<_LibraryTabs> {
  static const _tabPadding = LannaSpacing.s3 - 1;
  static const _rowPadding = LannaSpacing.s2;

  final _scroll = ScrollController();
  int? _revealed;

  static final _labelStyle = LannaType.md.copyWith(fontWeight: FontWeight.w600);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _activeIndex =>
      math.max(0, widget.tabs.indexWhere((t) => t.$1 == widget.active));

  List<double> _labelWidths(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return [
      for (final (_, label) in widget.tabs)
        () {
          final painter = TextPainter(
            text: TextSpan(text: label, style: _labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width.ceilToDouble();
          painter.dispose();
          return width;
        }(),
    ];
  }

  void _reveal(int index, List<double> starts, List<double> widths) {
    if (_revealed == index) return;
    final animate = _revealed != null;
    _revealed = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final center = _rowPadding + starts[index] + widths[index] / 2;
      final target = (center - position.viewportDimension / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (animate) {
        _scroll.animateTo(
          target,
          duration: LannaMotion.slow,
          curve: LannaMotion.ease,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labelWidths(context);
    final widths = [for (final w in labels) w + _tabPadding * 2];
    final starts = <double>[];
    var x = 0.0;
    for (final w in widths) {
      starts.add(x);
      x += w;
    }

    Widget strip(double position) {
      final last = widget.tabs.length - 1;
      final clamped = position.clamp(0.0, last.toDouble());
      final from = clamped.floor();
      final to = math.min(from + 1, last);
      final t = clamped - from;
      final left =
          (starts[from] + (starts[to] - starts[from]) * t) + _tabPadding;
      final width = labels[from] + (labels[to] - labels[from]) * t;
      final selected = clamped.round();
      _reveal(selected, starts, widths);

      return Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.tabs.length; i++)
                _LibraryTab(
                  width: widths[i],
                  label: widget.tabs[i].$2,
                  style: _labelStyle,
                  selected: i == selected,
                  onTap: () => widget.onSelect(widget.tabs[i].$1),
                ),
            ],
          ),
          Positioned(
            left: left,
            width: width,
            bottom: 0,
            height: 2,
            child: const ColoredBox(color: LannaColors.accent),
          ),
        ],
      );
    }

    final position = widget.position;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LannaColors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
        child: position == null
            ? strip(_activeIndex.toDouble())
            : ValueListenableBuilder<double>(
                valueListenable: position,
                builder: (context, value, _) => strip(value),
              ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.width,
    required this.label,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final TextStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 44,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: LannaMotion.fast,
              curve: LannaMotion.ease,
              style: style.copyWith(
                color: selected
                    ? LannaColors.textStrong
                    : LannaColors.textMuted,
              ),
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }
}
