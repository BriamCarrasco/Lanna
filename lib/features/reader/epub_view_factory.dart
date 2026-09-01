// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'epub_view.dart';
import 'platform/inappwebview_epub_view.dart';

enum ReaderEngine { auto, inAppWebView, windowsWebView }

Widget createEpubView({
  Key? key,
  required Uri readerUrl,
  required EpubViewCallbacks callbacks,
  ReaderEngine engine = ReaderEngine.auto,
}) {
  if (engine == ReaderEngine.windowsWebView && kDebugMode) {
    debugPrint(
      '[reader] fallback webview_windows no disponible; uso inappwebview',
    );
  }
  return InAppWebViewEpubView(
    key: key,
    readerUrl: readerUrl,
    callbacks: callbacks,
  );
}
