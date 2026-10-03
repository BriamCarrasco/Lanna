// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/lanna_dialog.dart';
import '../../../core/widgets/lanna_menu.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/book_format.dart';
import 'book_details_dialog.dart';
import 'series_dialogs.dart';

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
  final anchor = overlay.globalToLocal(globalPosition);
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      anchor & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      lannaMenuItem(
        value: 'open',
        icon: Icons.menu_book_outlined,
        label: 'Abrir',
      ),
      lannaMenuItem(
        value: 'details',
        icon: Icons.info_outline,
        label: 'Detalles',
      ),
      lannaMenuItem(
        value: 'favorite',
        icon: book.favoritedAt != null ? Icons.favorite : Icons.favorite_border,
        label: book.favoritedAt != null
            ? 'Quitar de favoritos'
            : 'Añadir a favoritos',
      ),
      lannaMenuItem(
        value: 'finished',
        icon: book.finishedAt != null ? Icons.remove_done : Icons.done_all,
        label: book.finishedAt != null
            ? 'Marcar como no terminado'
            : 'Marcar como terminado',
      ),
      lannaMenuItem(
        value: 'collection',
        icon: Icons.collections_bookmark_outlined,
        label: 'Añadir a colección',
      ),
      if (book.format == BookFormat.comic)
        lannaMenuItem(
          value: 'series',
          icon: Icons.layers_outlined,
          label: 'Serie…',
        ),
      const PopupMenuDivider(height: LannaSpacing.s2),
      book.folderId != null
          ? lannaMenuItem(
              value: 'delete',
              icon: Icons.inventory_2_outlined,
              label: 'Archivar',
            )
          : lannaMenuItem(
              value: 'delete',
              icon: Icons.delete_outline,
              label: 'Eliminar',
              danger: true,
            ),
    ],
  );
  if (!context.mounted) return;
  switch (selected) {
    case 'open':
      openBook(context, book);
    case 'details':
      unawaited(showBookDetails(context, book));
    case 'favorite':
      unawaited(
        ref
            .read(bookRepositoryProvider)
            .setFavorite(book.id, book.favoritedAt == null),
      );
    case 'finished':
      unawaited(
        ref
            .read(bookRepositoryProvider)
            .setFinished(book.id, finished: book.finishedAt == null),
      );
    case 'collection':
      unawaited(showCollectionPicker(context, ref, book));
    case 'series':
      unawaited(editBookSeries(context, ref, book));
    case 'delete':
      final deleted = await confirmDeleteBook(context, ref, book);
      if (deleted && context.mounted) {
        final archived = book.folderId != null;
        final repo = ref.read(bookRepositoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '«${book.title}» ${archived ? 'archivado' : 'eliminado'}',
            ),
            persist: false,
            duration: const Duration(seconds: 5),
            action: archived
                ? SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () => unawaited(repo.restoreBook(book.id)),
                  )
                : null,
          ),
        );
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

    return LannaDialog(
      title: 'Añadir a colección',
      maxWidth: 380,
      maxHeight: 460,
      children: [
        Flexible(
          child: collections.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: LannaSpacing.s5,
                  ),
                  child: Text(
                    'Todavía no tienes colecciones',
                    style: LannaType.md.copyWith(color: LannaColors.textMuted),
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
                          if (v ?? false) {
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
    );
  }
}
