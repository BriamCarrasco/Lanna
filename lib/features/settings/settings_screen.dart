// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/features.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/book_repository.dart';
import '../../data/local/app_database.dart';
import '../../l10n/l10n.dart';
import '../library/library_scan_controller.dart';
import '../library/widgets/section_scaffold.dart';
import '../reader/reader_settings_provider.dart';
import '../reader/reader_theme.dart';
import 'archived_books_dialog.dart';
import 'progress_backup.dart';

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.linkOpenFailed)));
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
      title: context.l10n.settings,
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
                  title: context.l10n.reading,
                  child: Column(
                    children: [
                      _SettingRow(
                        title: context.l10n.pageAnimation,
                        subtitle: context.l10n.pageAnimationHint,
                        stack: compact,
                        trailing: _Segmented(
                          options: {
                            'curl': context.l10n.animationCurl,
                            'slide': context.l10n.animationSlide,
                            'fade': context.l10n.animationFade,
                            'none': context.l10n.animationNone,
                          },
                          value: settings.pageAnimation,
                          onChanged: controller.setPageAnimation,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: context.l10n.edgeTaps,
                        trailing: _Toggle(
                          value: settings.edgeTaps,
                          onChanged: controller.setEdgeTaps,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: context.l10n.keepAwake,
                        trailing: _Toggle(
                          value: settings.keepAwake,
                          onChanged: controller.setKeepAwake,
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: context.l10n.dailyGoalSetting,
                        subtitle: context.l10n.dailyGoalHint,
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
                  title: context.l10n.language,
                  child: _SettingRow(
                    title: context.l10n.appLanguage,
                    stack: compact,
                    trailing: _Segmented(
                      options: {
                        'system': context.l10n.languageSystem,
                        'es': 'Español',
                        'en': 'English',
                      },
                      value: settings.language,
                      onChanged: controller.setLanguage,
                    ),
                  ),
                ),
                if (driveSyncEnabled) ...[
                  const SizedBox(height: LannaSpacing.s5),
                  _Section(
                    title: context.l10n.syncDrive,
                    child: _SettingRow(
                      title: 'Google Drive',
                      subtitle: context.l10n.notConnected,
                      trailing: OutlinedButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              SnackBar(content: Text(context.l10n.driveSoon)),
                            ),
                        child: Text(context.l10n.connect),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: LannaSpacing.s5),
                _Section(
                  title: context.l10n.readingProgress,
                  child: Column(
                    children: [
                      _SettingRow(
                        title: context.l10n.exportProgress,
                        subtitle: context.l10n.exportProgressHint,
                        stack: compact,
                        trailing: OutlinedButton.icon(
                          onPressed: () => exportProgressFile(context, ref),
                          icon: const Icon(Icons.upload_outlined, size: 18),
                          label: Text(context.l10n.export),
                        ),
                      ),
                      const _RowDivider(),
                      _SettingRow(
                        title: context.l10n.importProgress,
                        subtitle: context.l10n.importProgressHint,
                        stack: compact,
                        trailing: OutlinedButton.icon(
                          onPressed: () => importProgressFile(context, ref),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(context.l10n.import),
                        ),
                      ),
                    ],
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
                      _Section(
                        title: context.l10n.libraryFolders,
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
                      _Section(
                        title: context.l10n.about,
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
    context.l10n,
    ref
        .read(libraryScanProvider.notifier)
        .addFolder(dialogTitle: context.l10n.chooseBooksFolder),
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
        title: Text(context.l10n.removeFolderTitle(folder.name)),
        content: Text(context.l10n.removeFolderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LannaColors.danger,
              foregroundColor: LannaColors.surface,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.remove),
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
              ? context.l10n.noFolderHint
              : context.l10n.foldersHint,
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
                tooltip: context.l10n.removeFolder,
              ),
            ],
          ),
        ],
        const SizedBox(height: LannaSpacing.s3),
        _LinkText(context.l10n.addFolder, onTap: () => _add(context, ref)),
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
                context.l10n.archivedBooksCount(archived),
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
        _LinkText(
          context.l10n.originTitle,
          onTap: () => context.go('/settings/origin'),
        ),
        const SizedBox(height: LannaSpacing.s2),
        _LinkText(
          context.l10n.sourceCode,
          onTap: () => _openUrl(context, _sourceUrl),
        ),
        const SizedBox(height: LannaSpacing.s2),
        _LinkText(
          context.l10n.checkUpdates,
          onTap: () => _openUrl(context, _releasesUrl),
        ),
        const SizedBox(height: LannaSpacing.s2),
        _LinkText(
          context.l10n.licenses,
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Lanna',
            applicationVersion: '$_appVersion · $_license',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(LannaSpacing.s3),
              child: Image.asset(
                'assets/logo/lanna.png',
                width: 56,
                height: 56,
              ),
            ),
            applicationLegalese: context.l10n.legalNotice,
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
