// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_theme.dart';
import '../library/widgets/library_sidebar.dart';
import '../reader/reader_settings_provider.dart';
import '../reader/reader_theme.dart';

const _appVersion = '0.1.0';
const _license = 'GPL-3.0-or-later';
const _sourceUrl = 'https://github.com/BriamCarrasco/lanna';

final _storagePathProvider = FutureProvider<String>((ref) async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'library', 'books');
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(readerSettingsProvider).valueOrNull ?? const ReaderSettings();
    final controller = ref.read(readerSettingsControllerProvider);

    return Scaffold(
      backgroundColor: LannaColors.bg,
      body: Row(
        children: [
          LibrarySidebar(
            active: LibrarySection.settings,
            onSelect: (section) {
              switch (section) {
                case LibrarySection.settings:
                  return;
                case LibrarySection.library:
                  context.go('/');
                case LibrarySection.collections:
                case LibrarySection.authors:
                  context.go('/');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente')),
                  );
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  color: LannaColors.surface,
                  child: Text(
                    'Ajustes',
                    style: AppTheme.reading(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: LannaColors.textStrong,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Section(
                          title: 'LECTURA',
                          child: Column(
                            children: [
                              _SettingRow(
                                title: 'Animación de paso de página',
                                subtitle: 'Efecto al avanzar entre páginas',
                                trailing: _Segmented(
                                  options: const {
                                    'curl': 'Curl',
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _Section(
                          title: 'SINCRONIZACIÓN · GOOGLE DRIVE',
                          child: _SettingRow(
                            title: 'Google Drive',
                            subtitle: 'Sin conectar',
                            trailing: OutlinedButton(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Section(
                                title: 'BIBLIOTECA',
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    14,
                                  ),
                                  child: _StoragePath(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _Section(
                                title: 'ACERCA DE',
                                child: const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: _About(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _StoragePath extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(_storagePathProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Carpeta de almacenamiento',
          style: TextStyle(fontSize: 12.5, color: LannaColors.textMuted),
        ),
        const SizedBox(height: 6),
        SelectableText(
          path.valueOrNull ?? '—',
          style: const TextStyle(fontSize: 12.5, color: LannaColors.text),
        ),
        const SizedBox(height: 10),
        _LinkText(
          'Copiar ruta',
          onTap: () {
            final value = path.valueOrNull;
            if (value == null) return;
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ruta copiada')),
            );
          },
        ),
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
          style: const TextStyle(fontSize: 12.5, color: LannaColors.text),
        ),
        const SizedBox(height: 10),
        _LinkText(
          'Copiar enlace del código fuente',
          onTap: () {
            Clipboard.setData(const ClipboardData(text: _sourceUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enlace copiado')),
            );
          },
        ),
        const SizedBox(height: 6),
        _LinkText(
          'Buscar actualizaciones',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actualizaciones: próximamente')),
          ),
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
        style: const TextStyle(
          fontSize: 12.5,
          color: LannaColors.accent,
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
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: LannaColors.textMuted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1C22),
            border: Border.all(color: LannaColors.border),
            borderRadius: BorderRadius.circular(11),
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
  });

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: LannaColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: LannaColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LannaColors.bg,
        borderRadius: BorderRadius.circular(8),
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
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: entry.key == value
                      ? LannaColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
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
    );
  }
}
