// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

class EmptyLibraryView extends StatelessWidget {
  const EmptyLibraryView({super.key, required this.onImport});

  final VoidCallback onImport;

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
              'Tu biblioteca está vacía',
              style: LannaType.title.copyWith(color: LannaColors.text),
            ),
            const SizedBox(height: LannaSpacing.s2),
            Text(
              'Arrastra archivos EPUB o PDF aquí, o impórtalos desde tu equipo',
              style: LannaType.md.copyWith(color: LannaColors.textMuted),
            ),
            const SizedBox(height: LannaSpacing.s5),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Importar libros'),
            ),
          ],
        ),
      ),
    );
  }
}
