// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../library/widgets/section_scaffold.dart';

class OriginScreen extends StatelessWidget {
  const OriginScreen({super.key});

  static const _twoColumnsFrom = 720.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocks = [
      _OriginBlock(
        title: l10n.originNameTitle,
        text: l10n.originNameText,
        photoLabel: l10n.originNamePhoto,
      ),
      _OriginBlock(
        title: l10n.originLogoTitle,
        text: l10n.originLogoText,
        photoLabel: l10n.originLogoPhoto,
      ),
    ];
    return SectionScaffold(
      title: l10n.originTitle,
      onBack: () => context.go('/settings'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = constraints.maxWidth < 480
              ? LannaSpacing.s4
              : LannaSpacing.screenGutter;
          final wide = constraints.maxWidth >= _twoColumnsFrom;
          return SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: blocks[0]),
                      const SizedBox(width: LannaSpacing.s8),
                      Expanded(child: blocks[1]),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      blocks[0],
                      const SizedBox(height: LannaSpacing.s10),
                      blocks[1],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _OriginBlock extends StatelessWidget {
  const _OriginBlock({
    required this.title,
    required this.text,
    required this.photoLabel,
  });

  final String title;
  final String text;
  final String photoLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoSlot(label: photoLabel),
        const SizedBox(height: LannaSpacing.s5),
        Text(
          title,
          style: LannaType.title.copyWith(color: LannaColors.textStrong),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Text(
          text,
          style: LannaType.title.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.55,
            color: LannaColors.text,
          ),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: LannaColors.surfaceHigh,
            borderRadius: LannaRadii.brXl,
            border: Border.all(color: LannaColors.border),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_outlined,
                  size: 32,
                  color: LannaColors.textMuted,
                ),
                const SizedBox(height: LannaSpacing.s2),
                Text(
                  label,
                  style: LannaType.md.copyWith(color: LannaColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
