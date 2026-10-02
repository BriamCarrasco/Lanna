// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../reader_theme.dart';

class ReaderPanelFrame extends StatelessWidget {
  const ReaderPanelFrame({
    super.key,
    required this.chrome,
    required this.children,
  });

  final ReaderChrome chrome;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: chrome.panelBackground,
        border: Border(right: BorderSide(color: chrome.panelBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
