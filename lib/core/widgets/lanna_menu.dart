// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

const lannaMenuItemHeight = 40.0;

PopupMenuItem<T> lannaMenuItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool danger = false,
}) {
  final color = danger ? LannaColors.danger : LannaColors.text;
  return PopupMenuItem<T>(
    value: value,
    height: lannaMenuItemHeight,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? color : LannaColors.textMuted),
        const SizedBox(width: LannaSpacing.s3),
        Expanded(
          child: Text(label, style: LannaType.md.copyWith(color: color)),
        ),
      ],
    ),
  );
}

PopupMenuItem<T> lannaChoiceItem<T>({
  required T value,
  required String label,
  required bool selected,
}) {
  return PopupMenuItem<T>(
    value: value,
    height: lannaMenuItemHeight,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? const Icon(Icons.check, size: 16, color: LannaColors.accent)
              : null,
        ),
        const SizedBox(width: LannaSpacing.s3),
        Expanded(
          child: Text(
            label,
            style: LannaType.md.copyWith(
              color: selected ? LannaColors.textStrong : LannaColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

const lannaPopupMenuTheme = PopupMenuThemeData(
  color: LannaColors.surfaceHigh,
  surfaceTintColor: Colors.transparent,
  elevation: 12,
  shadowColor: Colors.black,
  menuPadding: EdgeInsets.symmetric(vertical: LannaSpacing.s1 + 2),
  shape: RoundedRectangleBorder(
    borderRadius: LannaRadii.brLg,
    side: BorderSide(color: LannaColors.border),
  ),
  textStyle: TextStyle(fontFamily: AppFonts.ui, color: LannaColors.text),
);
