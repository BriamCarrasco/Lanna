// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class LannaDialog extends StatelessWidget {
  const LannaDialog({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.maxWidth = 420,
    this.maxHeight = 520,
    this.serifTitle = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double maxWidth;
  final double maxHeight;
  final bool serifTitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: LannaType.title.copyWith(
                  fontFamily: serifTitle ? AppFonts.serif : null,
                  color: LannaColors.textStrong,
                ),
              ),
              if (subtitle case final text?) ...[
                const SizedBox(height: LannaSpacing.s1),
                Text(
                  text,
                  style: LannaType.sm.copyWith(color: LannaColors.textMuted),
                ),
              ],
              const SizedBox(height: LannaSpacing.s3),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
