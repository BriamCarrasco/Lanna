// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Pantalla de biblioteca (placeholder de Fase 0).
/// En la Fase 1 mostrará los libros importados desde SQLite.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lanna')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo/lanna.png', width: 128, height: 128),
            const SizedBox(height: 16),
            Text('Tu biblioteca está vacía', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Importa un EPUB para empezar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null, // Fase 1: importar EPUB
        icon: const Icon(Icons.add),
        label: const Text('Importar'),
      ),
    );
  }
}
