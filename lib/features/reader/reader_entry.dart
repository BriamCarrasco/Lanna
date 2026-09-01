// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/book_repository.dart';
import '../../data/models/book_format.dart';
import 'pdf/pdf_reader_screen.dart';
import 'reader_screen.dart';

class ReaderEntry extends ConsumerWidget {
  const ReaderEntry({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(findBookProvider(bookId));
    return book.when(
      loading: () => const Scaffold(
        backgroundColor: LannaColors.bg,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _NotFound(),
      data: (b) {
        if (b == null) return _NotFound();
        return b.format == BookFormat.pdf
            ? PdfReaderScreen(bookId: bookId)
            : ReaderScreen(bookId: bookId);
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LannaColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El libro no está en la biblioteca',
              style: TextStyle(color: LannaColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
