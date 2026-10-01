// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/local/app_database.dart';
import 'book_actions.dart';
import 'book_cover.dart';

typedef BookMenuCallback = void Function(Book book, Offset globalPosition);

class BookGridSliver extends StatelessWidget {
  const BookGridSliver({super.key, required this.books, required this.onMenu});

  final List<Book> books;
  final BookMenuCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s6),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 168,
          childAspectRatio: 0.54,
          crossAxisSpacing: LannaSpacing.s5,
          mainAxisSpacing: LannaSpacing.s6,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) =>
            BookGridTile(book: books[i], onMenu: onMenu),
      ),
    );
  }
}

class BookGridTile extends StatelessWidget {
  const BookGridTile({super.key, required this.book, required this.onMenu});

  final Book book;
  final BookMenuCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openBook(context, book),
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        onMenu(book, box.localToGlobal(box.size.center(Offset.zero)));
      },
      onSecondaryTapUp: (d) => onMenu(book, d.globalPosition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: book.available ? 1 : 0.4,
                child: BookCover(book: book),
              ),
            ),
          ),
          const SizedBox(height: LannaSpacing.s2),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LannaType.sm.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (!book.available)
            Text(
              'No disponible',
              style: LannaType.micro.copyWith(color: LannaColors.danger),
            )
          else if (book.author != null)
            Text(
              book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LannaType.micro.copyWith(color: LannaColors.textMuted),
            ),
        ],
      ),
    );
  }
}
