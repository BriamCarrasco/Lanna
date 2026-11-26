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
          final gutter = compact ? LannaSpacing.s4 : LannaSpacing.s8;
          final sections = <Widget>[
            _Section(
              title: context.l10n.reading,
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
                _SettingRow(
                  title: context.l10n.edgeTaps,
                  trailing: _Toggle(
                    value: settings.edgeTaps,
                    onChanged: controller.setEdgeTaps,
                  ),
                ),
                _SettingRow(
                  title: context.l10n.keepAwake,
                  trailing: _Toggle(
                    value: settings.keepAwake,
                    onChanged: controller.setKeepAwake,
                  ),
                ),
                _SettingRow(
                  title: context.l10n.dailyGoalSetting,
                  subtitle: context.l10n.dailyGoalHint,
                  stack: compact,
                  trailing: _Segmented(
                    options: {
                      for (final m in ReaderSettings.dailyGoals) '$m': '$m min',
                    },
                    value: '${settings.dailyGoalMinutes}',
                    onChanged: (v) => controller.setDailyGoal(int.parse(v)),
                  ),
                ),
              ],
            ),
            _Section(
              title: context.l10n.language,
              children: [
                _SettingRow(
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
              ],
            ),
            if (driveSyncEnabled)
              _Section(
                title: context.l10n.syncDrive,
                children: [
                  _SettingRow(
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
                ],
              ),
            _Section(
              title: context.l10n.backupSection,
              children: [
                _SettingRow(
                  title: context.l10n.exportProgress,
                  subtitle: context.l10n.exportProgressHint,
                  trailing: TextButton(
                    onPressed: () => exportProgressFile(context, ref),
                    child: Text(context.l10n.export),
                  ),
                ),
                _SettingRow(
                  title: context.l10n.importProgress,
                  subtitle: context.l10n.importProgressHint,
                  trailing: TextButton(
                    onPressed: () => importProgressFile(context, ref),
                    child: Text(context.l10n.import),
                  ),
                ),
              ],
            ),
          ];
          final folders = _Section(
            title: context.l10n.libraryFolders,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: LannaSpacing.s3),
                child: _Folders(),
              ),
            ],
          );
          final about = _Section(
            title: context.l10n.about,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: LannaSpacing.s3),
                child: _About(),
              ),
            ],
          );
          if (compact) {
            sections.addAll([folders, about]);
          } else {
            sections.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: folders),
                  const SizedBox(width: 48),
                  Expanded(child: about),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              LannaSpacing.s2,
              gutter,
              LannaSpacing.s8,
            ),
            child: _Stack(sections),
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
        Semantics(
          button: true,
          hint: context.l10n.licenses,
          child: InkWell(
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
            child: Text(
              'Lanna $_appVersion · $_license',
              style: LannaType.sm.copyWith(color: LannaColors.text),
            ),
          ),
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

class _Stack extends StatelessWidget {
  const _Stack(this.sections);
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: LannaColors.border),
          sections[i],
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: LannaColors.textStrong,
            ),
          ),
          const SizedBox(height: LannaSpacing.s1),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _RowDivider(),
            children[i],
          ],
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: LannaSpacing.s3),
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
                        ? LannaColors.surfaceActive
                        : Colors.transparent,
                    borderRadius: LannaRadii.brSm,
                  ),
                  child: Text(
                    entry.value,
                    style: LannaType.sm.copyWith(
                      fontWeight: entry.key == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: entry.key == value
                          ? LannaColors.textStrong
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
