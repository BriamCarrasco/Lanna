// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../reader_theme.dart';

const _panelBg = Color(0xFF1F1E24);
const _panelBorder = Color(0xFF322F39);
const _fieldBg = Color(0xFF17161B);
const _fieldActive = Color(0xFF26242C);

class AppearancePanel extends StatelessWidget {
  const AppearancePanel({
    super.key,
    required this.settings,
    required this.onPreset,
    required this.onFontFamily,
    required this.onFontScale,
    required this.onLineHeight,
    required this.onColumns,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderThemePreset> onPreset;
  final ValueChanged<String> onFontFamily;
  final ValueChanged<int> onFontScale;
  final ValueChanged<double> onLineHeight;
  final ValueChanged<String> onColumns;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 50,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Apariencia',
              style: AppTheme.reading(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LannaColors.text,
              ),
            ),
          ),
          _Row(
            label: 'Tema',
            child: Row(
              children: [
                for (final preset in ReaderThemePreset.values) ...[
                  if (preset != ReaderThemePreset.values.first)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _Swatch(
                      preset: preset,
                      selected: preset == settings.preset,
                      onTap: () => onPreset(preset),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Fuente',
            child: _Segmented(
              options: const {'serif': 'Serif', 'sans': 'Sans'},
              value: settings.fontFamily,
              serifKey: 'serif',
              onChanged: onFontFamily,
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Tamaño',
            child: _SizeSlider(
              value: settings.fontScale,
              onChanged: onFontScale,
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Interlínea',
            child: _LineHeightSegmented(
              value: settings.lineHeight,
              onChanged: onLineHeight,
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            label: 'Páginas',
            child: _Segmented(
              options: const {'auto': 'Auto', 'single': '1', 'double': '2'},
              value: settings.columns,
              onChanged: onColumns,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: LannaColors.textMuted,
            ),
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
    required this.onTap,
  });
  final ReaderThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: preset.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? LannaColors.accent : _panelBorder,
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
    required this.onChanged,
    this.serifKey,
  });
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String? serifKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: entry.key == value
                        ? _fieldActive
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: entry.key == serifKey
                          ? AppFonts.serif
                          : AppFonts.ui,
                      color: entry.key == value
                          ? LannaColors.text
                          : LannaColors.textMuted,
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
  const _SizeSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 34,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          const Text(
            'A',
            style: TextStyle(fontSize: 12, color: LannaColors.textMuted),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: LannaColors.accent,
                inactiveTrackColor: _panelBorder,
                thumbColor: LannaColors.accent,
                overlayColor: LannaColors.accent.withValues(alpha: 0.12),
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
          const Text(
            'A',
            style: TextStyle(fontSize: 19, color: LannaColors.text),
          ),
        ],
      ),
    );
  }
}

class _LineHeightSegmented extends StatelessWidget {
  const _LineHeightSegmented({required this.value, required this.onChanged});
  final double value;
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
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(ReaderSettings.lineHeights[i]),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: i == nearest ? _fieldActive : _fieldBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == nearest ? LannaColors.accent : _panelBorder,
                  ),
                ),
                child: Icon(
                  _icons[i],
                  size: 16,
                  color: i == nearest
                      ? LannaColors.text
                      : LannaColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
