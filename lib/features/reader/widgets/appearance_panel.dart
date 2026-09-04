// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../reader_theme.dart';

class AppearancePanel extends StatelessWidget {
  const AppearancePanel({
    super.key,
    required this.settings,
    required this.onPreset,
    required this.onColumns,
    this.bookFontAvailable = false,
    this.onFontFamily,
    this.onFontScale,
    this.onLineHeight,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderThemePreset> onPreset;
  final ValueChanged<String> onColumns;
  final bool bookFontAvailable;
  final ValueChanged<String>? onFontFamily;
  final ValueChanged<int>? onFontScale;
  final ValueChanged<double>? onLineHeight;

  bool get _typography =>
      onFontFamily != null && onFontScale != null && onLineHeight != null;

  @override
  Widget build(BuildContext context) {
    final chrome = ReaderChrome.of(settings.preset);
    return Container(
      width: 360,
      padding: const EdgeInsets.all(LannaSpacing.s5),
      decoration: BoxDecoration(
        color: chrome.panelBackground,
        borderRadius: LannaRadii.brLg,
        border: Border.all(color: chrome.panelBorder),
        boxShadow: LannaElevation.e3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: LannaSpacing.s4),
            child: Text(
              'Apariencia',
              style: LannaType.base.copyWith(
                fontFamily: AppFonts.serif,
                fontWeight: FontWeight.w600,
                color: chrome.onBar,
              ),
            ),
          ),
          _Row(
            label: 'Tema',
            chrome: chrome,
            child: Row(
              children: [
                for (final preset in ReaderThemePreset.values) ...[
                  if (preset != ReaderThemePreset.values.first)
                    const SizedBox(width: LannaSpacing.s2),
                  Expanded(
                    child: _Swatch(
                      preset: preset,
                      selected: preset == settings.preset,
                      borderColor: chrome.panelBorder,
                      onTap: () => onPreset(preset),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_typography) ...[
            const SizedBox(height: LannaSpacing.s3),
            _Row(
              label: 'Fuente',
              chrome: chrome,
              child: _Segmented(
                options: bookFontAvailable
                    ? const {'serif': 'Serif', 'sans': 'Sans', 'book': 'Libro'}
                    : const {'serif': 'Serif', 'sans': 'Sans'},
                value: settings.fontFamily,
                serifKey: 'serif',
                chrome: chrome,
                onChanged: onFontFamily!,
              ),
            ),
            const SizedBox(height: LannaSpacing.s3),
            _Row(
              label: 'Tamaño',
              chrome: chrome,
              child: _SizeSlider(
                value: settings.fontScale,
                chrome: chrome,
                onChanged: onFontScale!,
              ),
            ),
            const SizedBox(height: LannaSpacing.s3),
            _Row(
              label: 'Interlínea',
              chrome: chrome,
              child: _LineHeightSegmented(
                value: settings.lineHeight,
                chrome: chrome,
                onChanged: onLineHeight!,
              ),
            ),
          ],
          const SizedBox(height: LannaSpacing.s3),
          _Row(
            label: 'Páginas',
            chrome: chrome,
            child: _Segmented(
              options: const {'auto': 'Auto', 'single': '1', 'double': '2'},
              value: settings.columns,
              chrome: chrome,
              onChanged: onColumns,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.chrome, required this.child});
  final String label;
  final ReaderChrome chrome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: LannaType.micro.copyWith(color: chrome.onBarMuted),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.preset,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });
  final ReaderThemePreset preset;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: preset.background,
          borderRadius: LannaRadii.brMd,
          border: Border.all(
            color: selected ? ReaderChrome.accent : borderColor,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.value,
    required this.chrome,
    required this.onChanged,
    this.serifKey,
  });
  final Map<String, String> options;
  final String value;
  final ReaderChrome chrome;
  final ValueChanged<String> onChanged;
  final String? serifKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: chrome.fieldBackground,
        borderRadius: LannaRadii.brMd,
        border: Border.all(color: chrome.panelBorder),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: LannaSpacing.s2 - 1,
                  ),
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? chrome.fieldActive
                        : Colors.transparent,
                    borderRadius: LannaRadii.brSm,
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: LannaType.sm.copyWith(
                      fontFamily: entry.key == serifKey
                          ? AppFonts.serif
                          : AppFonts.ui,
                      color: entry.key == value
                          ? chrome.onBar
                          : chrome.onBarMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SizeSlider extends StatelessWidget {
  const _SizeSlider({
    required this.value,
    required this.chrome,
    required this.onChanged,
  });
  final int value;
  final ReaderChrome chrome;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: LannaSpacing.s3 - 2),
      height: 34,
      decoration: BoxDecoration(
        color: chrome.fieldBackground,
        borderRadius: LannaRadii.brMd,
        border: Border.all(color: chrome.panelBorder),
      ),
      child: Row(
        children: [
          Text('A', style: LannaType.sm.copyWith(color: chrome.onBarMuted)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: ReaderChrome.accent,
                inactiveTrackColor: chrome.panelBorder,
                thumbColor: ReaderChrome.accent,
                overlayColor: ReaderChrome.accent.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.5,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: value.toDouble().clamp(
                  ReaderSettings.minScale.toDouble(),
                  ReaderSettings.maxScale.toDouble(),
                ),
                min: ReaderSettings.minScale.toDouble(),
                max: ReaderSettings.maxScale.toDouble(),
                onChanged: (v) => onChanged((v / 5).round() * 5),
              ),
            ),
          ),
          Text(
            'A',
            style: LannaType.title.copyWith(
              fontFamily: AppFonts.ui,
              color: chrome.onBar,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineHeightSegmented extends StatelessWidget {
  const _LineHeightSegmented({
    required this.value,
    required this.chrome,
    required this.onChanged,
  });
  final double value;
  final ReaderChrome chrome;
  final ValueChanged<double> onChanged;

  static const _icons = [
    Icons.density_small,
    Icons.density_medium,
    Icons.density_large,
  ];

  @override
  Widget build(BuildContext context) {
    var nearest = 0;
    for (var i = 1; i < ReaderSettings.lineHeights.length; i++) {
      if ((ReaderSettings.lineHeights[i] - value).abs() <
          (ReaderSettings.lineHeights[nearest] - value).abs()) {
        nearest = i;
      }
    }

    return Row(
      children: [
        for (var i = 0; i < ReaderSettings.lineHeights.length; i++) ...[
          if (i > 0) const SizedBox(width: LannaSpacing.s2),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(ReaderSettings.lineHeights[i]),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: i == nearest
                      ? chrome.fieldActive
                      : chrome.fieldBackground,
                  borderRadius: LannaRadii.brMd,
                  border: Border.all(
                    color: i == nearest
                        ? ReaderChrome.accent
                        : chrome.panelBorder,
                  ),
                ),
                child: Icon(
                  _icons[i],
                  size: 16,
                  color: i == nearest ? chrome.onBar : chrome.onBarMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
