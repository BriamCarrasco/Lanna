// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import 'library_shell.dart';
import 'widgets/book_actions.dart';
import 'widgets/book_grid.dart';
import 'widgets/section_scaffold.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var collections = ref.watch(collectionsProvider).valueOrNull ?? const [];
    final query = foldForSearch(ref.watch(librarySearchProvider));
    if (query.isNotEmpty) {
      collections = collections
          .where((c) => matchesQuery(c.collection.name, query))
          .toList();
    }

    final compact = MediaQuery.sizeOf(context).width < 720;
    void create() => promptName(
      context,
      title: 'Nueva colección',
      onSubmit: (name) =>
          ref.read(bookRepositoryProvider).createCollection(name),
    );

    return SectionScaffold(
      title: 'Colecciones',
      subtitle:
          '${collections.length} '
          '${collections.length == 1 ? 'colección' : 'colecciones'}',
      actions: [
        if (compact)
          IconButton(
            onPressed: create,
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nueva colección',
          )
        else
          FilledButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva colección'),
          ),
      ],
      child: collections.isEmpty
          ? SectionEmpty(
              icon: Icons.folder_outlined,
              message: query.isEmpty
                  ? 'Crea una colección para agrupar tus libros'
                  : 'Ninguna colección coincide con la búsqueda',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s2),
              itemCount: collections.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: LannaSpacing.s6,
                color: LannaColors.borderSubtle,
              ),
              itemBuilder: (context, i) {
                final c = collections[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LannaSpacing.s6,
                  ),
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: LannaColors.textMuted,
                  ),
                  title: Text(c.collection.name, style: LannaType.base),
                  trailing: Text(
                    '${c.bookCount} ${c.bookCount == 1 ? 'libro' : 'libros'}',
                    style: LannaType.sm.copyWith(color: LannaColors.textMuted),
                  ),
                  onTap: () => context.push('/collections/${c.collection.id}'),
                );
              },
            ),
    );
  }
}

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books =
        ref.watch(collectionBooksProvider(collectionId)).valueOrNull ??
        const <Book>[];
    final all = ref.watch(collectionsProvider).valueOrNull ?? const [];
    final match = all.where((c) => c.collection.id == collectionId).toList();
    final name = match.isEmpty ? 'Colección' : match.first.collection.name;
    final repo = ref.read(bookRepositoryProvider);
    final compact = MediaQuery.sizeOf(context).width < 720;
    void addBooks() => showDialog(
      context: context,
      builder: (_) => _AddBooksDialog(collectionId: collectionId),
    );

    return SectionScaffold(
      title: name,
      subtitle: '${books.length} ${books.length == 1 ? 'libro' : 'libros'}',
      onBack: () => context.go('/collections'),
      actions: [
        if (compact)
          IconButton(
            onPressed: addBooks,
            icon: const Icon(Icons.add),
            tooltip: 'Añadir libros',
          )
        else
          TextButton.icon(
            onPressed: addBooks,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir libros'),
          ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'rename') {
              await promptName(
                context,
                title: 'Renombrar colección',
                initial: name,
                onSubmit: (n) => repo.renameCollection(collectionId, n),
              );
            } else if (value == 'delete') {
              await repo.deleteCollection(collectionId);
              if (context.mounted) context.go('/collections');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Renombrar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar colección')),
          ],
        ),
      ],
      child: books.isEmpty
          ? const SectionEmpty(
              icon: Icons.folder_open_outlined,
              message: 'Esta colección está vacía',
            )
          : CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s5),
                ),
                BookGridSliver(
                  books: books,
                  onMenu: (book, pos) => showBookMenu(context, ref, book, pos),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: LannaSpacing.s6),
                ),
              ],
            ),
    );
  }
}

class _AddBooksDialog extends ConsumerWidget {
  const _AddBooksDialog({required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).valueOrNull ?? const <Book>[];
    final inCollection =
        (ref.watch(collectionBooksProvider(collectionId)).valueOrNull ??
                const <Book>[])
            .map((b) => b.id)
            .toSet();
    final repo = ref.read(bookRepositoryProvider);

    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
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
                'Libros en la colección',
                style: LannaType.title.copyWith(color: LannaColors.textStrong),
              ),
              const SizedBox(height: LannaSpacing.s3),
              Flexible(
                child: library.isEmpty
                    ? Text(
                        'La biblioteca está vacía',
                        style: LannaType.md.copyWith(
                          color: LannaColors.textMuted,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final book in library)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: book.author == null
                                  ? null
                                  : Text(
                                      book.author!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              value: inCollection.contains(book.id),
                              onChanged: (v) {
                                if (v == true) {
                                  repo.addBookToCollection(
                                    collectionId,
                                    book.id,
                                  );
                                } else {
                                  repo.removeBookFromCollection(
                                    collectionId,
                                    book.id,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
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

Future<void> promptName(
  BuildContext context, {
  required String title,
  String? initial,
  required Future<void> Function(String name) onSubmit,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NamePromptDialog(title: title, initial: initial),
  );
  if (name != null && name.isNotEmpty) await onSubmit(name);
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
