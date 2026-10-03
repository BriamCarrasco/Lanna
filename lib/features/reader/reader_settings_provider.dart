// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_provider.dart';
import 'reader_theme.dart';

final readerSettingsProvider = StreamProvider<ReaderSettings>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchReaderPrefs().map(ReaderSettings.fromRow);
});

class ReaderSettingsController {
  ReaderSettingsController(this._ref);

  final Ref _ref;

  ReaderSettings get _current =>
      _ref.read(readerSettingsProvider).valueOrNull ?? const ReaderSettings();

  Future<void> _save(ReaderSettings next) =>
      _ref.read(appDatabaseProvider).saveReaderPrefs(next.toCompanion());

  Future<void> setPreset(ReaderThemePreset preset) =>
      _save(_current.copyWith(preset: preset));

  Future<void> setFontFamily(String family) =>
      _save(_current.copyWith(fontFamily: family));

  Future<void> changeFontScale(int delta) =>
      _save(_current.copyWith(fontScale: _current.fontScale + delta));

  Future<void> setFontScale(int percent) =>
      _save(_current.copyWith(fontScale: percent));

  Future<void> setLineHeight(double value) =>
      _save(_current.copyWith(lineHeight: value));

  Future<void> setColumns(String mode) =>
      _save(_current.copyWith(columns: mode));

  Future<void> setPageAnimation(String mode) =>
      _save(_current.copyWith(pageAnimation: mode));

  Future<void> setEdgeTaps(bool value) =>
      _save(_current.copyWith(edgeTaps: value));

  Future<void> setKeepAwake(bool value) =>
      _save(_current.copyWith(keepAwake: value));

  Future<void> setPageNumbers(bool value) =>
      _save(_current.copyWith(pageNumbers: value));

  Future<void> setDailyGoal(int minutes) =>
      _save(_current.copyWith(dailyGoalMinutes: minutes));
}

final readerSettingsControllerProvider = Provider(ReaderSettingsController.new);
