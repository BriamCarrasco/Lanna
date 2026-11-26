// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../library_scan_controller.dart';
import 'section_scaffold.dart';

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
    return EmptyIntro(
      title: hasFolders
          ? context.l10n.noBooksInFolders
          : context.l10n.yourLibraryEmpty,
      message: hasFolders
          ? context.l10n.emptyLibraryHintFolders
          : context.l10n.emptyLibraryHint,
      action: hasFolders
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
            ),
    );
  }
}
