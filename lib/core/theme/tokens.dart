// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'app_theme.dart';

abstract final class LannaSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;

  static const double screenGutter = s6;
  static const double barHeight = 48;
  static const double fieldHeight = 36;
}

abstract final class LannaRadii {
  static const Radius xs = Radius.circular(4);
  static const Radius sm = Radius.circular(6);
  static const Radius md = Radius.circular(8);
  static const Radius lg = Radius.circular(12);
  static const Radius xl = Radius.circular(16);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius brXs = BorderRadius.all(xs);
  static const BorderRadius brSm = BorderRadius.all(sm);
  static const BorderRadius brMd = BorderRadius.all(md);
  static const BorderRadius brLg = BorderRadius.all(lg);
  static const BorderRadius brXl = BorderRadius.all(xl);
  static const BorderRadius brPill = BorderRadius.all(pill);
}

abstract final class LannaType {
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle lg = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle base = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 14,
    height: 1.45,
  );
  static const TextStyle md = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 13,
    height: 1.4,
  );
  static const TextStyle sm = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 12,
    height: 1.4,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 11,
    height: 1.35,
  );
  static const TextStyle xs = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    height: 1.3,
  );
}

abstract final class LannaElevation {
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 50, offset: Offset(0, 24)),
  ];
}

abstract final class LannaMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 320);
  static const Cubic ease = Cubic(0.2, 0, 0, 1);
}
