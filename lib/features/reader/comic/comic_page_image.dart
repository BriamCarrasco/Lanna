// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../data/comic/comic_archive.dart';

@immutable
class ComicPageImage extends ImageProvider<ComicPageImage> {
  const ComicPageImage(this.archive, this.index);

  final ComicArchive archive;
  final int index;

  @override
  Future<ComicPageImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    ComicPageImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: 'comic page $index',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await archive.page(index);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ComicPageImage &&
      identical(other.archive, archive) &&
      other.index == index;

  @override
  int get hashCode => Object.hash(identityHashCode(archive), index);
}
