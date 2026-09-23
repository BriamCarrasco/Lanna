// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import 'epub_view.dart';

enum ReaderThemePreset {
  light(
    'light',
    'Claro',
    Color(0xFFFBF7EE),
    Color(0xFF2B2723),
    Color(0xFFA6483C),
  ),
  sepia(
    'sepia',
    'Sepia',
    Color(0xFFF4ECD8),
    Color(0xFF5B4636),
    Color(0xFF97482C),
  ),
  dark(
    'dark',
    'Oscuro',
    Color(0xFF121116),
    Color(0xFFD4CEC1),
    Color(0xFFE8968D),
  ),
  black(
    'black',
    'Negro',
    Color(0xFF000000),
    Color(0xFFB8B2A6),
    Color(0xFFE8968D),
  );

  const ReaderThemePreset(
    this.id,
    this.label,
    this.background,
    this.foreground,
    this.link,
  );

  final String id;
  final String label;
  final Color background;
  final Color foreground;
  final Color link;

  static ReaderThemePreset fromId(String id) =>
      values.firstWhere((p) => p.id == id, orElse: () => dark);

  String get cssBackground => _hex(background);
  String get cssForeground => _hex(foreground);
  String get cssLink => _hex(link);

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class ReaderChrome {
  const ReaderChrome({
    required this.barBackground,
    required this.barBorder,
    required this.onBar,
    required this.onBarMuted,
    required this.panelBackground,
    required this.panelBorder,
    required this.fieldBackground,
    required this.fieldActive,
    required this.progressTrack,
  });

  final Color barBackground;
  final Color barBorder;
  final Color onBar;
  final Color onBarMuted;
  final Color panelBackground;
  final Color panelBorder;
  final Color fieldBackground;
  final Color fieldActive;
  final Color progressTrack;

  static const Color accent = LannaColors.accent;

  factory ReaderChrome.of(ReaderThemePreset preset) {
    Color mix(double t) => Color.lerp(preset.background, preset.foreground, t)!;
    return ReaderChrome(
      barBackground: preset.background,
      barBorder: mix(0.14),
      onBar: mix(0.74),
      onBarMuted: mix(0.44),
      panelBackground: mix(0.06),
      panelBorder: mix(0.20),
      fieldBackground: mix(0.03),
      fieldActive: mix(0.14),
      progressTrack: mix(0.17),
    );
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.preset = ReaderThemePreset.dark,
    this.fontScale = 110,
    this.fontFamily = 'serif',
    this.lineHeight = 1.7,
    this.columns = 'auto',
    this.pageAnimation = 'slide',
    this.edgeTaps = true,
    this.keepAwake = false,
  });

  static const lineHeights = [1.45, 1.7, 2.0];
  static const pageAnimations = ['curl', 'slide', 'fade', 'none'];

  static const parkedAnimations = <String>[];

  static String sanitizeAnimation(String value) =>
      pageAnimations.contains(value) ? value : 'slide';

  final ReaderThemePreset preset;
  final int fontScale;
  final String fontFamily;
  final double lineHeight;

  final String columns;
  final String pageAnimation;
  final bool edgeTaps;
  final bool keepAwake;

  static const minScale = 70;
  static const maxScale = 220;

  factory ReaderSettings.fromRow(ReaderPref? row) {
    if (row == null) return const ReaderSettings();
    return ReaderSettings(
      preset: ReaderThemePreset.fromId(row.theme),
      fontScale: row.fontScale,
      fontFamily: row.fontFamily,
      lineHeight: row.lineHeight,
      columns: row.columns,
      pageAnimation: sanitizeAnimation(row.pageAnimation),
      edgeTaps: row.edgeTaps,
      keepAwake: row.keepAwake,
    );
  }

  ReaderPrefsCompanion toCompanion() => ReaderPrefsCompanion.insert(
    theme: Value(preset.id),
    fontScale: Value(fontScale),
    fontFamily: Value(fontFamily),
    lineHeight: Value(lineHeight),
    columns: Value(columns),
    pageAnimation: Value(pageAnimation),
    edgeTaps: Value(edgeTaps),
    keepAwake: Value(keepAwake),
  );

  ReaderSettings copyWith({
    ReaderThemePreset? preset,
    int? fontScale,
    String? fontFamily,
    double? lineHeight,
    String? columns,
    String? pageAnimation,
    bool? edgeTaps,
    bool? keepAwake,
  }) => ReaderSettings(
    preset: preset ?? this.preset,
    fontScale: (fontScale ?? this.fontScale).clamp(minScale, maxScale),
    fontFamily: fontFamily ?? this.fontFamily,
    lineHeight: lineHeight ?? this.lineHeight,
    columns: columns ?? this.columns,
    pageAnimation: sanitizeAnimation(pageAnimation ?? this.pageAnimation),
    edgeTaps: edgeTaps ?? this.edgeTaps,
    keepAwake: keepAwake ?? this.keepAwake,
  );

  static const fontFamilies = ['serif', 'sans', 'book'];

  ReaderPresentation toPresentation() => ReaderPresentation(
    background: preset.cssBackground,
    foreground: preset.cssForeground,
    link: preset.cssLink,
    fontSizePercent: fontScale,
    fontFamily: fontFamily,
    lineHeight: lineHeight,
    columnMode: columns,
    pageAnimation: pageAnimation,
    edgeTaps: edgeTaps,
  );
}
