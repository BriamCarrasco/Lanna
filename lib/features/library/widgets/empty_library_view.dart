// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/fade_in.dart';
import '../../../l10n/l10n.dart';
import '../library_scan_controller.dart';
import 'section_scaffold.dart';

class EmptyLibraryView extends StatelessWidget {
  const EmptyLibraryView({
    super.key,
    required this.hasFolders,
    required this.onAddFolder,
    required this.onRescan,
    this.welcome = false,
  });

  static const _welcomeBelow = 720.0;

  final bool hasFolders;
  final bool welcome;
  final VoidCallback onAddFolder;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final title = hasFolders
        ? context.l10n.noBooksInFolders
        : context.l10n.yourLibraryEmpty;
    final message = hasFolders
        ? context.l10n.emptyLibraryHintFolders
        : context.l10n.emptyLibraryHint;
    final action = hasFolders
        ? Consumer(
            builder: (context, ref, _) {
              final running = ref.watch(
                libraryScanProvider.select((s) => s.running),
              );
              return OutlinedButton.icon(
                onPressed: running ? null : onRescan,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.l10n.refresh),
              );
            },
          )
        : FilledButton.icon(
            onPressed: onAddFolder,
            style: emptyIntroButtonStyle,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: Text(context.l10n.chooseFolder),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!welcome || constraints.maxWidth >= _welcomeBelow) {
          return EmptyIntro(title: title, message: message, action: action);
        }
        return _Welcome(title: title, message: message, action: action);
      },
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.title,
    required this.message,
    required this.action,
  });

  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeIn(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LannaSpacing.s8,
            vertical: LannaSpacing.s6,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo/lanna.png',
                  width: 112,
                  height: 112,
                  semanticLabel: 'Lanna',
                ),
                const SizedBox(height: LannaSpacing.s4),
                const ExcludeSemantics(
                  child: Text(
                    'Lanna',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: LannaColors.textStrong,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 32,
                  child: Divider(height: 1, color: LannaColors.border),
                ),
                const SizedBox(height: 36),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: LannaColors.textStrong,
                  ),
                ),
                const SizedBox(height: LannaSpacing.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: LannaType.base.copyWith(
                      fontSize: 15,
                      height: 1.6,
                      color: LannaColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: LannaSpacing.s6),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
