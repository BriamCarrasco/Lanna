// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum LibrarySection { library, collections, authors, settings }

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.active,
    required this.onSelect,
    this.searchController,
    this.onSearchChanged,
  });

  final LibrarySection active;
  final ValueChanged<LibrarySection> onSelect;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: LannaColors.surfaceHigh,
        border: Border(right: BorderSide(color: LannaColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Image.asset('assets/logo/lanna.png', width: 34, height: 34),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Lanna',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.reading(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: LannaColors.textStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (searchController != null && onSearchChanged != null) ...[
            _SearchField(
              controller: searchController!,
              onChanged: onSearchChanged!,
            ),
            const SizedBox(height: 22),
          ],

          _NavItem(
            icon: Icons.menu_book_outlined,
            label: 'Biblioteca',
            selected: active == LibrarySection.library,
            onTap: () => onSelect(LibrarySection.library),
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Colecciones',
            selected: active == LibrarySection.collections,
            onTap: () => onSelect(LibrarySection.collections),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Autores',
            selected: active == LibrarySection.authors,
            onTap: () => onSelect(LibrarySection.authors),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Ajustes',
            selected: active == LibrarySection.settings,
            onTap: () => onSelect(LibrarySection.settings),
          ),

          const Spacer(),
          const _AccountChip(),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: LannaColors.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LannaColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 15, color: LannaColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: LannaColors.accent,
              cursorWidth: 1.5,
              style: const TextStyle(fontSize: 13, color: LannaColors.text),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar en la biblioteca',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: LannaColors.textMuted,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: 4)
                : InkWell(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? LannaColors.surfaceActive : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? LannaColors.accent : LannaColors.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? LannaColors.text : LannaColors.textMuted,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: LannaColors.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LannaColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: LannaColors.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Google Drive',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Sin conectar',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: LannaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
