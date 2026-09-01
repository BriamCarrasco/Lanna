// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../epub_view.dart';
import 'epub_js_bridge.dart';

class InAppWebViewEpubView extends StatefulWidget {
  const InAppWebViewEpubView({
    super.key,
    required this.readerUrl,
    required this.callbacks,
  });

  final Uri readerUrl;
  final EpubViewCallbacks callbacks;

  @override
  State<InAppWebViewEpubView> createState() => _InAppWebViewEpubViewState();
}

class _InAppWebViewEpubViewState extends State<InAppWebViewEpubView> {
  InAppWebViewController? _webView;
  bool _disposed = false;

  late final EpubJsController _controller = EpubJsController((source) async {
    if (_disposed || _webView == null) return;
    try {
      await _webView!.evaluateJavascript(source: source);
    } catch (_) {}
  });

  @override
  void dispose() {
    _disposed = true;
    _webView = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(widget.readerUrl)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        supportZoom: false,
        disableContextMenu: true,
        isInspectable: kDebugMode,
        javaScriptEnabled: true,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        supportMultipleWindows: false,
      ),
      onWebViewCreated: (controller) {
        _webView = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onReaderEvent',
          callback: (args) {
            if (!_disposed && args.isNotEmpty) {
              dispatchReaderEvent(args.first, widget.callbacks, _controller);
            }
            return null;
          },
        );
      },
      onConsoleMessage: (_, message) {
        if (kDebugMode) debugPrint('[reader] ${message.message}');
      },
      onReceivedError: (_, request, error) {
        if (!_disposed && request.isForMainFrame == true) {
          widget.callbacks.onError?.call(error.description);
        } else if (kDebugMode) {
          debugPrint('[reader] recurso: ${error.description}');
        }
      },
    );
  }
}
