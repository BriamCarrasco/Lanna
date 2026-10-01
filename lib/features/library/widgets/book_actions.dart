// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import 'book_details_dialog.dart';

void openBook(BuildContext context, Book book) {
  if (!book.available) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se encuentra «${book.title}» en su carpeta. '
          'Revisa la carpeta y actualiza la biblioteca.',
        ),
      ),
    );
    return;
  }
  unawaited(context.push('/reader/${book.id}'));
}

Future<void> showBookMenu(
  BuildContext context,
  WidgetRef ref,
  Book book,
  Offset globalPosition,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(40, 40),
      Offset.zero & overlay.size,
    ),
    items: [
      const PopupMenuItem(value: 'open', child: Text('Abrir')),
      const PopupMenuItem(value: 'details', child: Text('Detalles')),
      const PopupMenuItem(
        value: 'collection',
        child: Text('Añadir a colección'),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Text(
          book.folderId != null ? 'Quitar de la biblioteca' : 'Eliminar',
        ),
      ),
    ],
  );
  if (!context.mounted) return;
  switch (selected) {
    case 'open':
      openBook(context, book);
    case 'details':
      unawaited(showBookDetails(context, book));
    case 'collection':
      unawaited(showCollectionPicker(context, ref, book));
    case 'delete':
      final deleted = await confirmDeleteBook(context, ref, book);
      if (deleted && context.mounted) {
        final verb = book.folderId != null ? 'quitado' : 'eliminado';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('«${book.title}» $verb')));
      }
  }
}

Future<void> showCollectionPicker(
  BuildContext context,
  WidgetRef ref,
  Book book,
) {
  return showDialog(
    context: context,
    builder: (_) => _CollectionPicker(book: book),
  );
}

class _CollectionPicker extends ConsumerStatefulWidget {
  const _CollectionPicker({required this.book});
  final Book book;

  @override
  ConsumerState<_CollectionPicker> createState() => _CollectionPickerState();
}

class _CollectionPickerState extends ConsumerState<_CollectionPicker> {
  final _newController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _createAndAdd() async {
    final name = _newController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(bookRepositoryProvider);
    final id = await repo.createCollection(name);
    await repo.addBookToCollection(id, widget.book.id);
    if (mounted) _newController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider).valueOrNull ?? const [];
    final selected =
        ref.watch(bookCollectionsProvider(widget.book.id)).valueOrNull ??
        const <String>{};
    final repo = ref.read(bookRepositoryProvider);

    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s5,
            LannaSpacing.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Añadir a colección',
                style: LannaType.title.copyWith(color: LannaColors.textStrong),
              ),
              const SizedBox(height: LannaSpacing.s3),
              Flexible(
                child: collections.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: LannaSpacing.s5,
                        ),
                        child: Text(
                          'Todavía no tienes colecciones',
                          style: LannaType.md.copyWith(
                            color: LannaColors.textMuted,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final c in collections)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(c.collection.name),
                              value: selected.contains(c.collection.id),
                              onChanged: (v) {
                                if (v == true) {
                                  repo.addBookToCollection(
                                    c.collection.id,
                                    widget.book.id,
                                  );
                                } else {
                                  repo.removeBookFromCollection(
                                    c.collection.id,
                                    widget.book.id,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
              ),
              const Divider(height: LannaSpacing.s5),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newController,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Nueva colección',
                      ),
                      onSubmitted: (_) => _createAndAdd(),
                    ),
                  ),
                  const SizedBox(width: LannaSpacing.s2),
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: LannaColors.accent,
                    onPressed: _createAndAdd,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
