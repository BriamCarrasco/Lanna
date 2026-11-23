// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../library/widgets/section_scaffold.dart';

class OriginScreen extends StatelessWidget {
  const OriginScreen({super.key});

  static const _wideFrom = 840.0;
  static const _compactBelow = 480.0;
  static const _textColumn = 760.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionScaffold(
      title: l10n.originTitle,
      onBack: () => context.go('/settings'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gutter = switch (width) {
            < _compactBelow => LannaSpacing.s5,
            < _wideFrom => LannaSpacing.s8,
            _ => LannaSpacing.s10,
          };
          final inner = width - gutter * 2;
          final large = width >= 1600;
          final name = _Story(
            title: l10n.originNameTitle,
            text: l10n.originNameText,
            large: large,
          );
          final logo = _Story(
            title: l10n.originLogoTitle,
            text: l10n.originLogoText,
            large: large,
          );
          final zoe = _Photo(label: l10n.originLogoPhoto, aspectRatio: 4 / 5);

          if (width < _wideFrom) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Photo(label: l10n.originNamePhoto, aspectRatio: 4 / 3),
                  const SizedBox(height: LannaSpacing.s6),
                  name,
                  const SizedBox(height: 48),
                  logo,
                  const SizedBox(height: LannaSpacing.s6),
                  SizedBox(width: inner * 0.6, child: zoe),
                ],
              ),
            );
          }

          final textWidth = math.min(_textColumn, inner * 0.4);
          final photoArea = inner - textWidth - 64;
          final lannaWidth = math.min(
            photoArea,
            constraints.maxHeight * 0.7 * 3 / 2,
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(
                  textWidth: textWidth,
                  text: name,
                  photo: SizedBox(
                    width: lannaWidth,
                    child: _Photo(
                      label: l10n.originNamePhoto,
                      aspectRatio: 3 / 2,
                    ),
                  ),
                ),
                const SizedBox(height: 72),
                _Row(
                  textWidth: textWidth,
                  text: logo,
                  photo: SizedBox(width: lannaWidth * 0.34, child: zoe),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.textWidth,
    required this.text,
    required this.photo,
  });

  final double textWidth;
  final Widget text;
  final Widget photo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: textWidth, child: text),
        const SizedBox(width: 64),
        photo,
      ],
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.title, required this.text, required this.large});

  final String title;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: LannaType.display.copyWith(
            fontSize: large ? 30 : 24,
            color: LannaColors.textStrong,
          ),
        ),
        const SizedBox(height: LannaSpacing.s3),
        Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: large ? 21 : 18,
            height: 1.6,
            color: LannaColors.text,
          ),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, required this.aspectRatio});

  final String label;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: LannaColors.surface,
          borderRadius: LannaRadii.brMd,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: LannaType.sm.copyWith(color: LannaColors.textMuted),
          ),
        ),
      ),
    );
  }
}
