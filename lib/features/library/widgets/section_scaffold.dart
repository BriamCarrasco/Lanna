// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/fade_in.dart';

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backIcon = Icons.chevron_left,
    this.actions = const [],
    required this.child,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: title,
          subtitle: subtitle,
          onBack: onBack,
          backIcon: backIcon,
          actions: actions,
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.backIcon,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: LannaColors.surface,
      padding: EdgeInsets.only(
        left: onBack == null ? LannaSpacing.s6 : LannaSpacing.s1,
        right: LannaSpacing.s6,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(backIcon),
              color: LannaColors.textMuted,
              onPressed: onBack,
            ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.display.copyWith(
                      color: LannaColors.textStrong,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: LannaSpacing.s3),
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: LannaType.md.copyWith(
                        color: LannaColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(width: i == 0 ? LannaSpacing.s4 : LannaSpacing.s2),
            actions[i],
          ],
        ],
      ),
    );
  }
}

class SectionEmpty extends StatelessWidget {
  const SectionEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: LannaColors.textMuted),
            const SizedBox(height: LannaSpacing.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LannaType.md.copyWith(color: LannaColors.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: LannaSpacing.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
