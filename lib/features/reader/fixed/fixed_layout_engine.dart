// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../data/epub/epub_book.dart';
import '../reader_engine.dart';

const fixedSpreadMinWidth = 820.0;

int? pageFromLocator(String? locator) {
  if (locator == null || !locator.startsWith('page:')) return null;
  return int.tryParse(locator.substring(5).split('#').first);
}

abstract class FixedLayoutEngine extends StatefulWidget {
  const FixedLayoutEngine({
    super.key,
    required this.callbacks,
    this.initialLocator,
  });

  final ReaderEngineCallbacks callbacks;
  final String? initialLocator;
}

abstract class FixedLayoutEngineState<W extends FixedLayoutEngine>
    extends State<W>
    implements ReaderEngineController {
  final GlobalKey _boundary = GlobalKey();

  int _first = 1;
  int _spreadSize = 1;
  String _columnMode = 'auto';
  Color _background = const Color(0xFF121116);
  double _insetTop = 0;
  double _insetBottom = 0;
  Size _viewport = Size.zero;
  bool _ready = false;

  int get pageCount;

  Size? pageSize(int page) => null;

  Widget buildPage(BuildContext context, int page, Alignment alignment);

  List<EpubTocEntry> get toc => const [];

  bool get fitsInsets => true;

  Future<void> prepare() async {}

  void onPageChanged() {}

  int get currentPage => _first;

  List<int> get visiblePages => _pagesOf(_spreadIndex);

  @override
  ReaderCapabilities get capabilities => const ReaderCapabilities();

  @override
  bool get rtl => false;

  @override
  int get chapterCount => 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    try {
      await prepare();
    } catch (error) {
      widget.callbacks.onError?.call('No se pudo abrir el libro\n$error');
      return;
    }
    if (!mounted) return;
    if (pageCount == 0) {
      widget.callbacks.onError?.call('El libro no tiene páginas');
      return;
    }
    setState(() {
      _first = _align(pageFromLocator(widget.initialLocator) ?? 1);
      _ready = true;
    });
    widget.callbacks.onReady?.call(this);
    if (toc.isNotEmpty) widget.callbacks.onTocLoaded?.call(toc);
    widget.callbacks.onPageCount?.call(pageCount);
    _emit();
  }

  int get _spreadIndex => (_first - 1) ~/ _spreadSize;

  int get _spreadCount =>
      pageCount == 0 ? 0 : (pageCount + _spreadSize - 1) ~/ _spreadSize;

  int _firstOf(int spread) => spread * _spreadSize + 1;

  int _align(int page) =>
      _firstOf((page.clamp(1, math.max(1, pageCount)) - 1) ~/ _spreadSize);

  List<int> _pagesOf(int spread) {
    final first = _firstOf(spread);
    return [
      for (var p = first; p < first + _spreadSize && p <= pageCount; p++) p,
    ];
  }

  int _resolveSpreadSize(double width) => switch (_columnMode) {
    'single' => 1,
    'double' => 2,
    _ => width >= fixedSpreadMinWidth ? 2 : 1,
  };

  void _syncSpread({bool notify = true}) {
    if (_viewport.isEmpty) return;
    final next = _resolveSpreadSize(_viewport.width);
    if (next == _spreadSize) return;
    _spreadSize = next;
    _first = _align(_first);
    if (!_ready || !notify) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  void _onViewport(Size size) {
    if (size.isEmpty || size == _viewport) return;
    _viewport = size;
    _syncSpread();
  }

  void _emit() {
    if (!_ready) return;
    final pages = _pagesOf(_spreadIndex);
    final last = pages.last;
    widget.callbacks.onLocationChanged?.call(
      ReaderLocation(
        cfi: 'page:$_first',
        href: 'page:$_first',
        percentage: last / pageCount,
        chapterIndex: _first - 1,
        label: last > _first
            ? 'Páginas $_first–$last de $pageCount'
            : 'Página $_first de $pageCount',
        atStart: _spreadIndex == 0,
        atEnd: _spreadIndex >= _spreadCount - 1,
      ),
    );
  }

  void _go(int page) {
    if (!_ready) return;
    final target = _align(page);
    if (target != _first) {
      setState(() => _first = target);
      onPageChanged();
    }
    widget.callbacks.onRendered?.call();
    _emit();
  }

  @override
  String scrubLabel(double fraction) {
    final page = (fraction * pageCount).ceil().clamp(1, math.max(1, pageCount));
    return 'Pág. $page de $pageCount';
  }

  @override
  Future<void> next() async {
    final spread = _spreadIndex;
    if (spread + 1 >= _spreadCount) return;
    _go(_firstOf(spread + 1));
  }

  @override
  Future<void> previous() async {
    final spread = _spreadIndex;
    if (spread <= 0) return;
    _go(_firstOf(spread - 1));
  }

  @override
  Future<void> goToCfi(String cfi) async {
    final page = pageFromLocator(cfi);
    if (page != null) _go(page);
  }

  @override
  Future<void> goToPercentage(double percentage) async {
    _go((percentage * pageCount).ceil());
  }

  @override
  Future<void> applyPresentation(ReaderPresentation presentation) async {
    _background = _parseColor(presentation.background, _background);
    _columnMode = presentation.columnMode;
    _syncSpread();
    if (mounted) setState(() {});
  }

  @override
  Future<void> setInsets(double top, double bottom) async {
    if (_insetTop == top && _insetBottom == bottom) return;
    _insetTop = top;
    _insetBottom = bottom;
    if (mounted && fitsInsets) setState(() {});
  }

  @override
  Future<void> setAnimating(bool value) async {}

  @override
  Future<void> search(String query) async {
    widget.callbacks.onSearchResults?.call(query, const []);
  }

  @override
  Future<void> applyHighlights(List<HighlightSpec> highlights) async {}

  @override
  Future<void> addHighlight(String cfi, String color) async {}

  @override
  Future<void> removeHighlight(String cfi) async {}

  @override
  Future<void> clearSelection() async {
    widget.callbacks.onSelectionCleared?.call();
  }

  @override
  Future<ui.Image?> snapshot() async {
    final object = _boundary.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;
    if (!object.hasSize || object.debugNeedsPaint) return null;
    try {
      return await object.toImage(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      return null;
    }
  }

  static Color _parseColor(String? value, Color fallback) {
    if (value == null) return fallback;
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  EdgeInsets get _padding => fitsInsets
      ? EdgeInsets.fromLTRB(20, _insetTop + 8, 20, _insetBottom + 8)
      : EdgeInsets.zero;

  Widget _spread(BuildContext context, int spread) {
    final pages = _pagesOf(spread);
    if (pages.isEmpty) return const SizedBox.expand();
    final ordered = rtl ? pages.reversed.toList() : pages;

    Alignment alignFor(int i) {
      if (ordered.length == 1) return Alignment.center;
      return i == 0 ? Alignment.centerRight : Alignment.centerLeft;
    }

    final sizes = [for (final p in ordered) pageSize(p)];
    if (sizes.every((s) => s != null && !s.isEmpty)) {
      final width = sizes.fold<double>(0, (sum, s) => sum + s!.width);
      final height = sizes.fold<double>(0, (h, s) => math.max(h, s!.height));
      return Padding(
        padding: _padding,
        child: Center(
          child: AspectRatio(
            aspectRatio: width / height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < ordered.length; i++)
                  Expanded(
                    flex: math.max(1, (sizes[i]!.width * 100).round()),
                    child: buildPage(context, ordered[i], Alignment.center),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: _padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++)
            Expanded(child: buildPage(context, ordered[i], alignFor(i))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _onViewport(constraints.biggest);
        final current = _spreadIndex;
        final window = [
          for (final s in [current - 1, current + 1, current])
            if (s >= 0 && s < _spreadCount) s,
        ];
        return RepaintBoundary(
          key: _boundary,
          child: ColoredBox(
            color: _background,
            child: !_ready
                ? const SizedBox.expand()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final s in window)
                        Offstage(
                          key: ValueKey('spread-$_spreadSize-$s'),
                          offstage: s != current,
                          child: TickerMode(
                            enabled: s == current,
                            child: _spread(context, s),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
