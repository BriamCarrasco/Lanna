// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class ReaderBar extends StatelessWidget {
  const ReaderBar({
    super.key,
    required this.visible,
    required this.fromTop,
    required this.child,
  });

  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: fromTop ? 0 : null,
      bottom: fromTop ? null : 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(0, fromTop ? -1 : 1),
          duration: LannaMotion.base,
          curve: LannaMotion.ease,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: LannaMotion.fast,
            curve: LannaMotion.ease,
            child: child,
          ),
        ),
      ),
    );
  }
}

class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({super.key, required this.open, required this.child});

  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSwitcher(
        duration: LannaMotion.base,
        switchInCurve: LannaMotion.ease,
        switchOutCurve: LannaMotion.ease,
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
        child: open ? child : const SizedBox.shrink(),
      ),
    );
  }
}

class ReaderCornerPanel extends StatelessWidget {
  const ReaderCornerPanel({
    super.key,
    required this.open,
    required this.child,
    required this.right,
    required this.bottom,
  });

  final bool open;
  final Widget child;
  final double right;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: AnimatedSwitcher(
        duration: LannaMotion.base,
        switchInCurve: LannaMotion.ease,
        switchOutCurve: LannaMotion.ease,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(animation),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        ),
        child: open ? child : const SizedBox.shrink(),
      ),
    );
  }
}
