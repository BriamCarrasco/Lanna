// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/local/app_database.dart';
import '../series_group.dart';
import 'book_actions.dart';
import 'book_grid.dart';

Future<void> showSeries(BuildContext context, SeriesEntry series) {
  return showDialog(
    context: context,
    builder: (_) => SeriesSheet(seriesKey: series.key, name: series.name),
  );
}

class SeriesSheet extends ConsumerWidget {
  const SeriesSheet({super.key, required this.seriesKey, required this.name});

  final String seriesKey;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).valueOrNull ?? const <Book>[];
    final progress =
        ref.watch(progressByBookProvider).valueOrNull ??
        const <String, double>{};
    final volumes = volumesOf(library, seriesKey);
    final finished = volumes.where((b) => (progress[b.id] ?? 0) >= 0.99).length;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 600;

    return Dialog(
      backgroundColor: LannaColors.surfaceHigh,
      insetPadding: narrow
          ? const EdgeInsets.all(LannaSpacing.s3)
          : const EdgeInsets.symmetric(
              horizontal: LannaSpacing.s8,
              vertical: LannaSpacing.s6,
            ),
      shape: const RoundedRectangleBorder(borderRadius: LannaRadii.brLg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: size.height * (narrow ? 0.92 : 0.86),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s6,
                LannaSpacing.s5,
                LannaSpacing.s3,
                LannaSpacing.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LannaType.title.copyWith(
                            fontFamily: AppFonts.serif,
                            color: LannaColors.textStrong,
                          ),
                        ),
                        const SizedBox(height: LannaSpacing.s1),
                        Text(
                          '${volumes.length} '
                          '${volumes.length == 1 ? 'tomo' : 'tomos'}'
                          '${finished > 0 ? ' · $finished leídos' : ''}',
                          style: LannaType.sm.copyWith(
                            color: LannaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LannaColors.border),
            Flexible(
              child: volumes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(LannaSpacing.s6),
                      child: Text('Esta serie ya no tiene tomos'),
                    )
                  : CustomScrollView(
                      shrinkWrap: true,
                      slivers: [
                        const SliverToBoxAdapter(
                          child: SizedBox(height: LannaSpacing.s5),
                        ),
                        BookGridSliver(
                          books: volumes,
                          progress: progress,
                          onMenu: (book, pos) =>
                              unawaited(showBookMenu(context, ref, book, pos)),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: LannaSpacing.s6),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
