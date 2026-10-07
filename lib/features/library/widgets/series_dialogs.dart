// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/book_repository.dart';
import '../../../data/comic/comic_book.dart';
import '../../../data/local/app_database.dart';
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
    title: 'Serie de «${book.title}»',
    confirm: 'Guardar',
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
    title: 'Renombrar serie',
    confirm: 'Renombrar',
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

Future<bool> confirmSplitSeries(
  BuildContext context,
  String name,
  int volumes,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LannaColors.surfaceHigh,
      title: Text('¿Separar «$name»?'),
      content: Text(
        'Los $volumes tomos volverán a aparecer como libros sueltos en la '
        'biblioteca. No se borra ningún archivo ni progreso de lectura.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Separar'),
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
            decoration: const InputDecoration(hintText: 'Nombre de la serie'),
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
            child: const Text('Quitar de la serie'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
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
