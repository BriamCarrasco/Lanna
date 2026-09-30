// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../reader_theme.dart';

class ReaderScrubber extends StatefulWidget {
  const ReaderScrubber({
    super.key,
    required this.value,
    required this.chrome,
    required this.onSeek,
    required this.trailingLabel,
    this.bubbleLabel,
    this.rtl = false,
  });

  final double value;
  final bool rtl;
  final ReaderChrome chrome;
  final ValueChanged<double> onSeek;
  final String Function(double fraction) trailingLabel;
  final String Function(double fraction)? bubbleLabel;

  @override
  State<ReaderScrubber> createState() => _ReaderScrubberState();
}

class _ReaderScrubberState extends State<ReaderScrubber> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final current = (_drag ?? widget.value).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: ReaderChrome.accent,
              inactiveTrackColor: chrome.progressTrack,
              thumbColor: ReaderChrome.accent,
              overlayColor: ReaderChrome.accent.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
              trackShape: const RoundedRectSliderTrackShape(),
              showValueIndicator: widget.bubbleLabel != null
                  ? ShowValueIndicator.onlyForContinuous
                  : ShowValueIndicator.never,
              valueIndicatorColor: chrome.panelBackground,
              valueIndicatorTextStyle: LannaType.sm.copyWith(
                color: chrome.onBar,
              ),
            ),
            child: Directionality(
              textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Slider(
                value: current,
                label: widget.bubbleLabel?.call(current),
                onChanged: (v) => setState(() => _drag = v),
                onChangeEnd: (v) {
                  setState(() => _drag = null);
                  widget.onSeek(v);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: LannaSpacing.s2),
        Text(
          widget.trailingLabel(current),
          style: LannaType.micro.copyWith(color: chrome.onBarMuted),
        ),
      ],
    );
  }
}
