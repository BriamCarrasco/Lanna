// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Temas de Lanna. Color semilla tomado del rojo/granate del logo (el gato).
abstract final class AppTheme {
  /// Rojo/granate del collar del gato en el logo.
  static const Color seed = Color(0xFFB52A33);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
