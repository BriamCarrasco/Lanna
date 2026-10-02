// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'reader_engine.dart';

Color parseCssColor(String? value, Color fallback) {
  if (value == null) return fallback;
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) hex = 'FF$hex';
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

Future<ui.Image?> captureBoundary(
  GlobalKey boundary,
  BuildContext context,
) async {
  final object = boundary.currentContext?.findRenderObject();
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

mixin EngineHighlights<T extends StatefulWidget> on State<T> {
  List<HighlightSpec> highlights = const [];

  Future<void> applyHighlights(List<HighlightSpec> value) async {
    if (mounted) setState(() => highlights = value);
  }

  Future<void> addHighlight(String cfi, String color) async {
    if (!mounted) return;
    setState(
      () => highlights = [
        ...highlights.where((h) => h.cfi != cfi),
        HighlightSpec(cfi: cfi, color: color),
      ],
    );
  }

  Future<void> removeHighlight(String cfi) async {
    if (!mounted) return;
    setState(() => highlights = highlights.where((h) => h.cfi != cfi).toList());
  }
}
