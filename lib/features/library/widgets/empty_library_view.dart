// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class EmptyLibraryView extends StatelessWidget {
  const EmptyLibraryView({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF191820),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3A3742), width: 2),
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
            const SizedBox(height: 18),
            Text(
              'Tu biblioteca está vacía',
              style: AppTheme.reading(fontSize: 20, color: LannaColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Arrastra archivos EPUB o PDF aquí, o impórtalos desde tu equipo',
              style: TextStyle(fontSize: 13, color: LannaColors.textMuted),
            ),
            const SizedBox(height: 20),
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
