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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(LannaSpacing.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasFolders
                    ? context.l10n.noBooksInFolders
                    : context.l10n.yourLibraryEmpty,
                style: const TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: LannaColors.textStrong,
                ),
              ),
              const SizedBox(height: LannaSpacing.s3),
              Text(
                hasFolders
                    ? context.l10n.emptyLibraryHintFolders
                    : context.l10n.emptyLibraryHint,
                style: LannaType.base.copyWith(
                  fontSize: 15,
                  height: 1.6,
                  color: LannaColors.textMuted,
                ),
              ),
              const SizedBox(height: LannaSpacing.s6),
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: LannaSpacing.s5,
                    ),
                  ),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(context.l10n.chooseFolder),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
