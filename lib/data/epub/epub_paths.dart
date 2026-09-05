// SPDX-License-Identifier: GPL-3.0-or-later
String decodeHref(String value) {
  try {
    return Uri.decodeFull(value);
  } catch (_) {
    return value;
  }
}
