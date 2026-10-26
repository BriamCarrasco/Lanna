// SPDX-License-Identifier: GPL-3.0-or-later

enum BookFormat {
  epub,
  pdf,
  comic;

  bool get hasSeries => this == pdf || this == comic;
}
