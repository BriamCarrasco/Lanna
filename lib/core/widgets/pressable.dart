// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  void _setDown(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  void _setHover(bool value) {
    if (_hover != value && mounted) setState(() => _hover = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = reduce
        ? 1.0
        : _down
        ? widget.scale
        : _hover
        ? 1.012
        : 1.0;
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setDown(false);
                widget.onLongPress!.call();
              },
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: AnimatedScale(
          scale: scale,
          duration: LannaMotion.fast,
          curve: LannaMotion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}
