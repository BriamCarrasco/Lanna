// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../library/library_scan_controller.dart';
import '../library/widgets/section_scaffold.dart';
import '../reader/reader_settings_provider.dart';
import '../reader/reader_theme.dart';
import 'archived_books_dialog.dart';

const _appVersion = '0.1.0';
const _license = 'GPL-3.0-or-later';
const _sourceUrl = 'https://github.com/BriamCarrasco/lanna';
const _releasesUrl = 'https://github.com/BriamCarrasco/lanna/releases';

Future<void> _openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

Widget _flexChild(bool compact, Widget child) =>
    compact ? child : Expanded(child: child);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(readerSettingsProvider).valueOrNull ?? const ReaderSettings();
    final controller = ref.read(readerSettingsControllerProvider);

    return SectionScaffold(
      title: 'Ajustes',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final gutter = compact ? LannaSpacing.s4 : LannaSpacing.s6;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              gutter,
              gutter,
              LannaSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(
                  title: 'Lectura',
                  child: Column(
                    children: [
                      _SettingRow(
                        title: 'Animación de paso de página',
                        subtitle: 'Efecto al avanzar entre páginas',
                        stack: compact,
                        trailing: _Segmented(
                          options: const {
                            'curl': 'Pasar hoja',
                            'slide': 'Deslizar',
                            'fade': 'Desvanecer',
                            'none': 'Ninguna',
                          },
                          value: settings.pageAnimation,
                          onChanged: controller.setPageAnimation,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: 'Tocar los bordes para pasar página',
                        trailing: _Toggle(
                          value: settings.edgeTaps,
                          onChanged: controller.setEdgeTaps,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: 'Mantener la pantalla encendida al leer',
                        trailing: _Toggle(
                          value: settings.keepAwake,
                          onChanged: controller.setKeepAwake,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: 'Meta diaria de lectura',
                        subtitle: 'La racha cuenta los días en que la cumples',
                        stack: compact,
                        trailing: _Segmented(
                          options: {
                            for (final m in ReaderSettings.dailyGoals)
                              '$m': '$m min',
                          },
                          value: '${settings.dailyGoalMinutes}',
                          onChanged: (v) =>
                              controller.setDailyGoal(int.parse(v)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LannaSpacing.s5),
                _Section(
                  title: 'Sincronización · Google Drive',
                  child: _SettingRow(
                    title: 'Google Drive',
                    subtitle: 'Sin conectar',
                    trailing: OutlinedButton(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sincronización con Drive: próximamente',
                              ),
                            ),
                          ),
                      child: const Text('Conectar'),
                    ),
                  ),
                ),
                const SizedBox(height: LannaSpacing.s5),
                Flex(
                  direction: compact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  children: [
                    _flexChild(
                      compact,
                      const _Section(
                        title: 'Carpetas de la biblioteca',
                        child: Padding(
                          padding: EdgeInsets.all(LannaSpacing.s4),
                          child: _Folders(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: compact ? 0 : LannaSpacing.s4,
                      height: compact ? LannaSpacing.s5 : 0,
                    ),
                    _flexChild(
                      compact,
                      const _Section(
                        title: 'Acerca de',
                        child: Padding(
                          padding: EdgeInsets.all(LannaSpacing.s4),
                          child: _About(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Folders extends ConsumerWidget {
  const _Folders();

  Future<void> _add(BuildContext context, WidgetRef ref) => reportScan(
    ScaffoldMessenger.of(context),
    ref.read(libraryScanProvider.notifier).addFolder(),
  );

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    LibraryFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LannaColors.surfaceHigh,
        title: Text('¿Quitar «${folder.name}»?'),
        content: const Text(
          'Sus libros dejarán de aparecer en la biblioteca, junto con su '
          'progreso, marcadores y subrayados. Los archivos no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LannaColors.danger,
              foregroundColor: LannaColors.surface,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryScanProvider.notifier).removeFolder(folder);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(libraryFoldersProvider).valueOrNull ?? const [];
    final archived = ref.watch(archivedProvider).valueOrNull?.length ?? 0;
    final scanning = ref.watch(libraryScanProvider.select((s) => s.running));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          folders.isEmpty
              ? 'Todavía no elegiste ninguna carpeta. Lanna lee los libros '
                    'desde ahí, sin copiarlos.'
              : 'Lanna lee los libros desde estas carpetas, sin copiarlos.',
          style: LannaType.sm.copyWith(color: LannaColors.textMuted),
        ),
        for (final folder in folders) ...[
          const SizedBox(height: LannaSpacing.s3),
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 18,
                color: LannaColors.textMuted,
              ),
              const SizedBox(width: LannaSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: LannaType.sm.copyWith(color: LannaColors.text),
                    ),
                    if (!folder.location.startsWith('content://'))
                      Text(
                        folder.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LannaType.micro.copyWith(
                          color: LannaColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: scanning
                    ? null
                    : () => _remove(context, ref, folder),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Quitar carpeta',
              ),
            ],
          ),
        ],
        const SizedBox(height: LannaSpacing.s3),
        _LinkText('Añadir carpeta', onTap: () => _add(context, ref)),
        if (archived > 0) ...[
          const SizedBox(height: LannaSpacing.s4),
          const Divider(height: 1, color: LannaColors.borderSubtle),
          const SizedBox(height: LannaSpacing.s3),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: LannaColors.textMuted,
              ),
              const SizedBox(width: LannaSpacing.s2),
              _LinkText(
                'Libros archivados · $archived',
                onTap: () => showArchivedBooks(context),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lanna $_appVersion · $_license',
          style: LannaType.sm.copyWith(color: LannaColors.text),
        ),
        const SizedBox(height: LannaSpacing.s3),
        _LinkText('Código fuente', onTap: () => _openUrl(context, _sourceUrl)),
        const SizedBox(height: LannaSpacing.s2),
        _LinkText(
          'Buscar actualizaciones',
          onTap: () => _openUrl(context, _releasesUrl),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: LannaType.sm.copyWith(
          color: LannaColors.accentStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: LannaSpacing.s3, left: 2),
          child: Text(
            title.toUpperCase(),
            style: LannaType.xs.copyWith(color: LannaColors.textMuted),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: LannaColors.surfaceHigh,
            border: Border.all(color: LannaColors.border),
            borderRadius: LannaRadii.brLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: LannaColors.borderSubtle);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    required this.trailing,
    this.stack = false,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool stack;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: LannaType.md.copyWith(
            fontWeight: FontWeight.w600,
            color: LannaColors.text,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: LannaType.sm.copyWith(color: LannaColors.textMuted),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LannaSpacing.s4,
        vertical: LannaSpacing.s3,
      ),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: LannaSpacing.s3),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            )
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: LannaSpacing.s4),
                trailing,
              ],
            ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: LannaColors.accent,
      inactiveThumbColor: const Color(0xFF6D6A63),
      inactiveTrackColor: LannaColors.border,
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: LannaColors.bg,
          borderRadius: LannaRadii.brMd,
          border: Border.all(color: LannaColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in options.entries)
              GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LannaSpacing.s3,
                    vertical: LannaSpacing.s1 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? LannaColors.accent
                        : Colors.transparent,
                    borderRadius: LannaRadii.brSm,
                  ),
                  child: Text(
                    entry.value,
                    style: LannaType.sm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: entry.key == value
                          ? LannaColors.surface
                          : LannaColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
