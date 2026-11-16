// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/comic/comic_book.dart';
import '../../../data/local/app_database.dart';
import '../../../l10n/l10n.dart';
import '../series_group.dart';

List<String> seriesNames(List<Book> books) {
  final byKey = <String, String>{};
  for (final book in books) {
    final key = seriesKeyOf(book);
    if (key != null) byKey.putIfAbsent(key, () => book.series!.trim());
  }
  return byKey.values.toList()..sort(compareNatural);
}

Future<String?> askSeriesName(
  BuildContext context, {
  required String title,
  required String confirm,
  required List<String> suggestions,
  String initial = '',
  bool allowRemove = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SeriesNameDialog(
      title: title,
      confirm: confirm,
      suggestions: suggestions,
      initial: initial,
      allowRemove: allowRemove,
    ),
  );
}

Future<void> editBookSeries(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final repo = ref.read(bookRepositoryProvider);
  final library = ref.read(libraryProvider).valueOrNull ?? const <Book>[];
  final current = seriesKeyOf(book) == null ? '' : book.series!.trim();
  final result = await askSeriesName(
    context,
    title: context.l10n.seriesOf(book.title),
    confirm: context.l10n.save,
    suggestions: seriesNames(library),
    initial: current,
    allowRemove: current.isNotEmpty,
  );
  if (result == null) return;
  await repo.setSeries([book.id], result);
}

Future<String?> renameSeries(
  BuildContext context,
  WidgetRef ref,
  SeriesEntry series,
) async {
  final library = ref.read(libraryProvider).valueOrNull ?? const <Book>[];
  final name = await askSeriesName(
    context,
    title: context.l10n.renameSeries,
    confirm: context.l10n.rename,
    suggestions: [
      for (final n in seriesNames(library))
        if (foldForSearch(n) != series.key) n,
    ],
    initial: series.name,
  );
  if (name == null || name.isEmpty) return null;
  await ref.read(bookRepositoryProvider).setSeries([
    for (final b in series.volumes) b.id,
  ], name);
  return name;
}

typedef SeriesMove = ({String name, Map<String, String?> previous});

Future<SeriesMove?> moveBooksToSeries(
  BuildContext context,
  WidgetRef ref,
  List<Book> books,
) async {
  if (books.isEmpty) return null;
  final library = ref.read(libraryProvider).valueOrNull ?? const <Book>[];
  final keys = {for (final b in books) seriesKeyOf(b)};
  final shared = keys.length == 1 && keys.single != null;
  final name = await askSeriesName(
    context,
    title: books.length == 1
        ? context.l10n.moveToASeries
        : context.l10n.moveVolumesToSeries(books.length),
    confirm: context.l10n.move,
    suggestions: seriesNames(library),
    initial: shared ? books.first.series!.trim() : '',
    allowRemove: keys.any((k) => k != null),
  );
  if (name == null) return null;
  final previous = {for (final b in books) b.id: b.series};
  await ref
      .read(bookRepositoryProvider)
      .setSeries(previous.keys.toList(), name);
  return (name: name, previous: previous);
}

Future<bool> confirmArchiveSeries(
  BuildContext context,
  String name,
  int volumes,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text(context.l10n.archiveSeriesTitle(name)),
      content: Text(context.l10n.archiveSeriesBody(volumes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.archive),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<bool> confirmSplitSeries(
  BuildContext context,
  String name,
  int volumes,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text(context.l10n.splitSeriesTitle(name)),
      content: Text(context.l10n.splitSeriesBody(volumes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.split),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _SeriesNameDialog extends StatefulWidget {
  const _SeriesNameDialog({
    required this.title,
    required this.confirm,
    required this.suggestions,
    required this.initial,
    required this.allowRemove,
  });

  final String title;
  final String confirm;
  final List<String> suggestions;
  final String initial;
  final bool allowRemove;

  @override
  State<_SeriesNameDialog> createState() => _SeriesNameDialogState();
}

class _SeriesNameDialogState extends State<_SeriesNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  Iterable<String> _options(TextEditingValue value) {
    final query = foldForSearch(value.text);
    return [
      for (final name in widget.suggestions)
        if (matchesQuery(name, query) && foldForSearch(name) != query) name,
    ].take(6);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text(
        widget.title,
        style: LannaType.title.copyWith(
          fontFamily: AppFonts.serif,
          color: LannaColors.textStrong,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focus,
          optionsBuilder: _options,
          onSelected: (name) => _controller.text = name,
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            decoration: InputDecoration(hintText: context.l10n.seriesName),
            onSubmitted: (_) => _submit(),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: LannaColors.surfaceActive,
              elevation: 8,
              shape: const RoundedRectangleBorder(
                borderRadius: LannaRadii.brMd,
                side: BorderSide(color: LannaColors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 240,
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: LannaSpacing.s1,
                  ),
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LannaSpacing.s3,
                            vertical: LannaSpacing.s2,
                          ),
                          child: Text(
                            option,
                            style: LannaType.md.copyWith(
                              color: LannaColors.text,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (widget.allowRemove)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(context.l10n.removeFromSeries),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirm),
          ),
        ),
      ],
    );
  }
}
