// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/text_search.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/lanna_dialog.dart';
import '../../core/widgets/lanna_menu.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';
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
      title: context.l10n.newCollection,
      onSubmit: (name) =>
          ref.read(bookRepositoryProvider).createCollection(name),
    );

    return SectionScaffold(
      title: context.l10n.collections,
      subtitle: context.l10n.collectionsCount(collections.length),
      actions: [
        if (compact)
          IconButton(
            onPressed: create,
            icon: const Icon(Icons.add, size: 20, color: LannaColors.textMuted),
            tooltip: context.l10n.newCollection,
          )
        else
          FilledButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.newCollection),
          ),
      ],
      child: collections.isEmpty
          ? SectionEmpty(
              icon: Icons.folder_outlined,
              message: query.isEmpty
                  ? context.l10n.createCollectionHint
                  : context.l10n.noCollectionMatches,
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
                    context.l10n.booksCount(c.bookCount),
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
    final name = match.isEmpty
        ? context.l10n.collection
        : match.first.collection.name;
    final repo = ref.read(bookRepositoryProvider);
    final compact = MediaQuery.sizeOf(context).width < 720;
    void addBooks() => showDialog<void>(
      context: context,
      builder: (_) => _AddBooksDialog(collectionId: collectionId),
    );

    return SectionScaffold(
      title: name,
      subtitle: context.l10n.booksCount(books.length),
      onBack: () => context.go('/collections'),
      actions: [
        if (compact)
          IconButton(
            onPressed: addBooks,
            icon: const Icon(Icons.add),
            tooltip: context.l10n.addBooks,
          )
        else
          TextButton.icon(
            onPressed: addBooks,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.addBooks),
          ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'rename') {
              await promptName(
                context,
                title: context.l10n.renameCollection,
                initial: name,
                onSubmit: (n) => repo.renameCollection(collectionId, n),
              );
            } else if (value == 'delete') {
              await repo.deleteCollection(collectionId);
              if (context.mounted) context.go('/collections');
            }
          },
          itemBuilder: (_) => [
            lannaMenuItem(
              value: 'rename',
              icon: Icons.edit_outlined,
              label: context.l10n.rename,
            ),
            lannaMenuItem(
              value: 'delete',
              icon: Icons.delete_outline,
              label: context.l10n.deleteCollection,
              danger: true,
            ),
          ],
        ),
      ],
      child: books.isEmpty
          ? SectionEmpty(
              icon: Icons.folder_open_outlined,
              message: context.l10n.emptyCollection,
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

    return LannaDialog(
      title: context.l10n.booksInCollection,
      children: [
        Flexible(
          child: library.isEmpty
              ? Text(
                  context.l10n.libraryEmpty,
                  style: LannaType.md.copyWith(color: LannaColors.textMuted),
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
                          if (v ?? false) {
                            unawaited(
                              repo.addBookToCollection(collectionId, book.id),
                            );
                          } else {
                            unawaited(
                              repo.removeBookFromCollection(
                                collectionId,
                                book.id,
                              ),
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
            child: Text(context.l10n.done),
          ),
        ),
      ],
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
        decoration: InputDecoration(hintText: context.l10n.name),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}
