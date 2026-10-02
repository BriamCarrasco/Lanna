// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../library_filters.dart';

const _panelWidth = 340.0;

const sheetBreakpoint = 600.0;

Future<void> showFiltersPanel(
  BuildContext anchor, {
  required LibraryFilters filters,
  required ValueChanged<LibraryFilters> onChanged,
}) {
  final panelKey = GlobalKey();
  return showGeneralDialog<void>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Cerrar filtros',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: LannaMotion.fast,
    pageBuilder: (context, _, _) => _AdaptivePanel(
      anchor: anchor,
      child: FiltersPanel(
        key: panelKey,
        initial: filters,
        onChanged: onChanged,
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: LannaMotion.ease),
      child: child,
    ),
  );
}

class _AdaptivePanel extends StatefulWidget {
  const _AdaptivePanel({required this.anchor, required this.child});

  final BuildContext anchor;
  final Widget child;

  @override
  State<_AdaptivePanel> createState() => _AdaptivePanelState();
}

class _AdaptivePanelState extends State<_AdaptivePanel> {
  Rect? _anchorRect;

  Rect? _measure() {
    if (!widget.anchor.mounted) return null;
    final box = widget.anchor.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void initState() {
    super.initState();
    _anchorRect = _measure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.sizeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = _measure();
      if (rect != null && rect != _anchorRect) {
        setState(() => _anchorRect = rect);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final rect = _anchorRect;
    if (screen.width < sheetBreakpoint || rect == null) {
      return _sheet(screen);
    }
    return _popover(screen, rect);
  }

  Widget _scrollable(double maxHeight) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(child: widget.child),
  );

  Widget _sheet(Size screen) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: LannaColors.surfaceHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: LannaSpacing.s3),
                decoration: const BoxDecoration(
                  color: LannaColors.border,
                  borderRadius: LannaRadii.brPill,
                ),
              ),
              _scrollable(screen.height * 0.85),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popover(Size screen, Rect rect) {
    final width = (screen.width - LannaSpacing.s4 * 2).clamp(0.0, _panelWidth);
    final right = (screen.width - rect.right).clamp(
      LannaSpacing.s4,
      screen.width - width,
    );
    final top = rect.bottom + LannaSpacing.s2;
    final maxHeight = (screen.height - top - LannaSpacing.s4).clamp(
      160.0,
      screen.height,
    );
    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          width: width,
          child: Material(
            color: LannaColors.surfaceHigh,
            shape: const RoundedRectangleBorder(
              borderRadius: LannaRadii.brLg,
              side: BorderSide(color: LannaColors.border),
            ),
            elevation: 12,
            shadowColor: Colors.black,
            clipBehavior: Clip.antiAlias,
            child: _scrollable(maxHeight),
          ),
        ),
      ],
    );
  }
}

class FiltersPanel extends StatefulWidget {
  const FiltersPanel({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final LibraryFilters initial;
  final ValueChanged<LibraryFilters> onChanged;

  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  late LibraryFilters _filters = widget.initial;

  void _set(LibraryFilters next) {
    setState(() => _filters = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LannaSpacing.s5,
        LannaSpacing.s4,
        LannaSpacing.s5,
        LannaSpacing.s3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtros',
            style: LannaType.base.copyWith(
              fontFamily: AppFonts.serif,
              fontWeight: FontWeight.w600,
              color: LannaColors.textStrong,
            ),
          ),
          const SizedBox(height: LannaSpacing.s4),
          _Group(
            label: 'Formato',
            children: [
              for (final f in FormatFilter.values)
                FilterPill(
                  label: f.label,
                  selected: _filters.format == f,
                  onTap: () => _set(_filters.copyWith(format: f)),
                ),
            ],
          ),
          const SizedBox(height: LannaSpacing.s4),
          _Group(
            label: 'Estado',
            children: [
              for (final f in ReadFilter.values)
                FilterPill(
                  label: f.label,
                  selected: _filters.read == f,
                  onTap: () => _set(_filters.copyWith(read: f)),
                ),
            ],
          ),
          const SizedBox(height: LannaSpacing.s4),
          const Divider(height: 1, color: LannaColors.borderSubtle),
          const SizedBox(height: LannaSpacing.s2),
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: LannaSpacing.s1,
            children: [
              TextButton(
                onPressed: _filters.active
                    ? () => _set(const LibraryFilters())
                    : null,
                child: const Text('Quitar filtros'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: LannaType.xs.copyWith(
            color: LannaColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: LannaSpacing.s2),
        Wrap(
          spacing: LannaSpacing.s2 - 2,
          runSpacing: LannaSpacing.s2 - 2,
          children: children,
        ),
      ],
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: LannaRadii.brPill,
        child: AnimatedContainer(
          duration: LannaMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: LannaSpacing.s3,
            vertical: LannaSpacing.s2 - 2,
          ),
          decoration: BoxDecoration(
            color: selected ? LannaColors.accentTint : Colors.transparent,
            border: Border.all(
              color: selected ? LannaColors.accent : LannaColors.border,
            ),
            borderRadius: LannaRadii.brPill,
          ),
          child: Text(
            label,
            style: LannaType.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? LannaColors.accentStrong
                  : LannaColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class FiltersButton extends StatefulWidget {
  const FiltersButton({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final LibraryFilters filters;
  final ValueChanged<LibraryFilters> onChanged;

  @override
  State<FiltersButton> createState() => _FiltersButtonState();
}

class _FiltersButtonState extends State<FiltersButton> {
  @override
  Widget build(BuildContext context) {
    final filters = widget.filters;
    final count =
        (filters.format != FormatFilter.all ? 1 : 0) +
        (filters.read != ReadFilter.all ? 1 : 0);
    final active = count > 0;
    final tint = active ? LannaColors.accentStrong : LannaColors.textMuted;
    return Tooltip(
      message: 'Filtros',
      child: InkWell(
        borderRadius: LannaRadii.brPill,
        onTap: () => showFiltersPanel(
          context,
          filters: filters,
          onChanged: widget.onChanged,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LannaSpacing.s3,
            vertical: LannaSpacing.s1 + 1,
          ),
          decoration: BoxDecoration(
            color: active ? LannaColors.accentTint : LannaColors.bg,
            border: Border.all(
              color: active ? LannaColors.accent : LannaColors.border,
            ),
            borderRadius: LannaRadii.brPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 14, color: tint),
              const SizedBox(width: LannaSpacing.s1 + 2),
              Text(
                'Filtros',
                style: LannaType.sm.copyWith(
                  color: active ? LannaColors.accentStrong : LannaColors.text,
                ),
              ),
              if (active) ...[
                const SizedBox(width: LannaSpacing.s1 + 2),
                Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: LannaColors.accent,
                    borderRadius: LannaRadii.brPill,
                  ),
                  child: Text(
                    '$count',
                    style: LannaType.micro.copyWith(
                      fontWeight: FontWeight.w700,
                      color: LannaColors.bg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
