// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/comic/comic_archive.dart';
import '../../../data/comic/comic_book.dart';
import '../fixed/fixed_layout_engine.dart';
import 'comic_page_image.dart';

class ComicEngineView extends FixedLayoutEngine {
  const ComicEngineView({
    super.key,
    required this.archive,
    required super.callbacks,
    super.initialLocator,
    super.initialRtl,
  });

  final ComicArchive archive;

  ComicBook get book => archive.book;

  @override
  State<ComicEngineView> createState() => _ComicEngineViewState();
}

class _ComicEngineViewState extends FixedLayoutEngineState<ComicEngineView> {
  @override
  int get pageCount => widget.book.pages.length;

  @override
  bool get naturalRtl => widget.book.rtl;

  @override
  bool get fitsInsets => false;

  final Map<int, Size> _sizes = {};
  final Set<int> _probing = {};

  @override
  Size? pageSize(int page) => _sizes[page];

  @override
  Future<void> prepare() async {
    final start = pageFromLocator(widget.initialLocator) ?? 1;
    await _probe(start, start + 2, notify: false);
    unawaited(_probeAround(start));
  }

  @override
  void onPageChanged() => unawaited(_probeAround(currentPage));

  Future<void> _probeAround(int page) async {
    await _probe(page, page + 6);
    await _probe(page - 3, page - 1);
  }

  Future<void> _probe(int from, int to, {bool notify = true}) async {
    var changed = false;
    for (var p = math.max(1, from); p <= math.min(pageCount, to); p++) {
      if (_sizes.containsKey(p) || !_probing.add(p)) continue;
      final dimensions = await widget.archive.pageDimensions(p - 1);
      _probing.remove(p);
      if (!mounted) return;
      if (dimensions == null) continue;
      _sizes[p] = Size(
        dimensions.width.toDouble(),
        dimensions.height.toDouble(),
      );
      changed = true;
    }
    if (changed && notify) pageSizesChanged();
  }

  @override
  Widget buildPage(BuildContext context, int page, Alignment alignment) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = (constraints.maxWidth * ratio).round().clamp(1, 4096);
        return Image(
          image: ResizeImage(
            ComicPageImage(widget.archive, page - 1),
            width: width,
          ),
          fit: BoxFit.contain,
          alignment: alignment,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
          ),
        );
      },
    );
  }
}
