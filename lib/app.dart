// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/reader/reader_settings_provider.dart';
import 'l10n/l10n.dart';

class LannaApp extends ConsumerWidget {
  const LannaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(
      readerSettingsProvider.select((s) => s.valueOrNull?.language),
    );
    return MaterialApp.router(
      title: 'Lanna',
      locale: switch (language) {
        'es' || 'en' => Locale(language!),
        _ => null,
      },
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: resolveAppLocale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
