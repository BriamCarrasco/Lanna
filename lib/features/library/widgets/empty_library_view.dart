// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../library_scan_controller.dart';

class EmptyLibraryView extends StatelessWidget {
  const EmptyLibraryView({
    super.key,
    required this.hasFolders,
    required this.onAddFolder,
    required this.onRescan,
  });

  final bool hasFolders;
  final VoidCallback onAddFolder;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LannaSpacing.s6),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: LannaColors.surfaceHigh,
          borderRadius: LannaRadii.brXl,
          border: Border.all(color: LannaColors.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo/lanna.png',
              width: 84,
              height: 84,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
            const SizedBox(height: LannaSpacing.s4),
            Text(
              hasFolders
                  ? context.l10n.noBooksInFolders
                  : context.l10n.yourLibraryEmpty,
              textAlign: TextAlign.center,
              style: LannaType.title.copyWith(color: LannaColors.text),
            ),
            const SizedBox(height: LannaSpacing.s2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s5),
              child: Text(
                hasFolders
                    ? context.l10n.emptyLibraryHintFolders
                    : context.l10n.emptyLibraryHint,
                textAlign: TextAlign.center,
                style: LannaType.md.copyWith(color: LannaColors.textMuted),
              ),
            ),
            const SizedBox(height: LannaSpacing.s5),
            if (hasFolders)
              Consumer(
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
            else
              FilledButton.icon(
                onPressed: onAddFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(context.l10n.chooseFolder),
              ),
          ],
        ),
      ),
    );
  }
}
