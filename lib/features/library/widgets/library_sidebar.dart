// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

enum LibrarySection {
  library,
  favorites,
  folders,
  collections,
  authors,
  stats,
  settings,
}

const librarySections = <(IconData, String, LibrarySection)>[
  (Icons.menu_book_outlined, 'Biblioteca', LibrarySection.library),
  (Icons.favorite_border, 'Favoritos', LibrarySection.favorites),
  (Icons.folder_outlined, 'Carpetas', LibrarySection.folders),
  (
    Icons.collections_bookmark_outlined,
    'Colecciones',
    LibrarySection.collections,
  ),
  (Icons.person_outline, 'Autores', LibrarySection.authors),
  (Icons.insights_outlined, 'Estadísticas', LibrarySection.stats),
  (Icons.settings_outlined, 'Ajustes', LibrarySection.settings),
];

void goToLibrarySection(BuildContext context, LibrarySection section) {
  switch (section) {
    case LibrarySection.library:
      context.go('/');
    case LibrarySection.favorites:
      context.go('/favorites');
    case LibrarySection.folders:
      context.go('/folders');
    case LibrarySection.collections:
      context.go('/collections');
    case LibrarySection.authors:
      context.go('/authors');
    case LibrarySection.stats:
      context.go('/stats');
    case LibrarySection.settings:
      context.go('/settings');
  }
}

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.active,
    required this.onSelect,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
  });

  final LibrarySection active;
  final ValueChanged<LibrarySection> onSelect;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: LannaColors.surfaceHigh,
        border: Border(right: BorderSide(color: LannaColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        LannaSpacing.s4,
        LannaSpacing.s5,
        LannaSpacing.s4,
        LannaSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LannaSpacing.s1 + 2,
            ),
            child: Row(
              children: [
                Image.asset('assets/logo/lanna.png', width: 34, height: 34),
                const SizedBox(width: LannaSpacing.s3 - 2),
                Flexible(
                  child: Text(
                    'Lanna',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LannaType.display.copyWith(
                      color: LannaColors.textStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LannaSpacing.s5),

          if (searchController != null && onSearchChanged != null) ...[
            LibrarySearchField(
              controller: searchController!,
              focusNode: searchFocusNode,
              onChanged: onSearchChanged!,
            ),
            const SizedBox(height: LannaSpacing.s5),
          ],

          Expanded(
            child: SingleChildScrollView(
              child: _NavSection(active: active, onSelect: onSelect),
            ),
          ),
          const _AccountChip(),
        ],
      ),
    );
  }
}

bool get _desktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LannaSpacing.fieldHeight,
      padding: const EdgeInsets.only(left: LannaSpacing.s3 - 2, right: 4),
      decoration: BoxDecoration(
        color: LannaColors.bg,
        borderRadius: LannaRadii.brMd,
        border: Border.all(color: LannaColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 15, color: LannaColors.textMuted),
          const SizedBox(width: LannaSpacing.s2),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              cursorColor: LannaColors.accent,
              cursorWidth: 1.5,
              style: LannaType.md.copyWith(color: LannaColors.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar en la biblioteca',
                hintStyle: LannaType.md.copyWith(color: LannaColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: LannaSpacing.s2,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? (_desktop
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            Platform.isMacOS ? '⌘F' : 'Ctrl F',
                            style: LannaType.micro.copyWith(
                              color: LannaColors.textMuted,
                            ),
                          ),
                        )
                      : const SizedBox(width: 4))
                : InkWell(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    borderRadius: LannaRadii.brPill,
                    child: const Padding(
                      padding: EdgeInsets.all(LannaSpacing.s1 + 2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: LannaColors.textMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({required this.active, required this.onSelect});

  final LibrarySection active;
  final ValueChanged<LibrarySection> onSelect;

  static const _items = librarySections;

  static const _itemHeight = 36.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final index = _items.indexWhere((e) => e.$3 == active);
    return SizedBox(
      height: _items.length * (_itemHeight + _gap) - _gap,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: LannaMotion.slow,
            curve: LannaMotion.ease,
            top: index * (_itemHeight + _gap),
            left: 0,
            right: 0,
            height: _itemHeight,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: LannaColors.surfaceActive,
                borderRadius: LannaRadii.brMd,
              ),
            ),
          ),
          Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                _NavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: i == index,
                  height: _itemHeight,
                  onTap: () => onSelect(_items[i].$3),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap,
        borderRadius: LannaRadii.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s3 - 1),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: selected ? 1 : 0),
                duration: LannaMotion.slow,
                curve: LannaMotion.ease,
                builder: (context, t, _) => Icon(
                  icon,
                  size: 17,
                  color: Color.lerp(
                    LannaColors.textMuted,
                    LannaColors.accent,
                    t,
                  ),
                ),
              ),
              const SizedBox(width: LannaSpacing.s3 - 1),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: LannaMotion.base,
                  curve: LannaMotion.ease,
                  style: LannaType.md.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? LannaColors.text : LannaColors.textMuted,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LannaSpacing.s3,
        vertical: LannaSpacing.s2 + 1,
      ),
      decoration: BoxDecoration(
        color: LannaColors.bg,
        borderRadius: LannaRadii.brPill,
        border: Border.all(color: LannaColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 17,
            color: LannaColors.textMuted,
          ),
          const SizedBox(width: LannaSpacing.s2 + 1),
          Expanded(
            child: Text(
              'Google Drive · Sin conectar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LannaType.sm.copyWith(color: LannaColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
