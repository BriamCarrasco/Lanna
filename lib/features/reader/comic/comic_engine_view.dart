// SPDX-License-Identifier: GPL-3.0-or-later
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
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
          ),
        );
      },
    );
  }
}
