// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

import 'epub_view.dart';
import 'native/book_source.dart';
import 'native/native_epub_view.dart';

Widget createEpubView({
  Key? key,
  required NativeBookSource source,
  required EpubViewCallbacks callbacks,
  String? initialLocator,
  double? initialPercent,
}) => NativeEpubView(
  key: key,
  source: source,
  callbacks: callbacks,
  initialLocator: initialLocator,
  initialPercent: initialPercent,
);
