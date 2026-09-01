// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../reader_theme.dart';

class ReaderBarButton extends StatelessWidget {
  const ReaderBarButton({
    super.key,
    this.icon,
    this.label,
    this.active = false,
    this.tooltip,
    this.size = 19,
    this.color = LannaColors.textMuted,
    required this.onTap,
  });

  final IconData? icon;
  final String? label;
  final bool active;
  final String? tooltip;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? ReaderChrome.accent : this.color;
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: icon != null
            ? Icon(icon, size: size, color: color)
            : Text(
                label!,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
