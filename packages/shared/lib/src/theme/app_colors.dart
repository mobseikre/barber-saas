import 'package:flutter/material.dart';

/// Design tokens from design/design.html — "نظام التصميم — الأساسيات".
abstract final class AppColors {
  static const blue950 = Color(0xFF0A1540);
  static const blue900 = Color(0xFF13225A);
  static const blue800 = Color(0xFF1B3180);
  static const poleBlue = Color(0xFF2448B8);
  static const bluePressed = Color(0xFF2A45A3);
  static const blue300 = Color(0xFF93A2D3);
  static const blue100 = Color(0xFFE7ECFA);

  static const red700 = Color(0xFFB3141C);
  static const red600 = Color(0xFFC81E26);
  static const poleRed = Color(0xFFD62828);
  static const red400 = Color(0xFFFF5C62);
  static const red300 = Color(0xFFFF8A8F);
  static const red100 = Color(0xFFFBE0E1);
  static const red50 = Color(0xFFFEF1F1);
  static const vipText = Color(0xFF8A1016);

  static const poleChrome = Color(0xFFDCE2EC);
  static const poleChromeShade = Color(0xFFAEB8CA);

  static const text = blue900;
  static const text2 = Color(0xFF4B5565);
  static const text3 = Color(0xFF5E6878);
  static const border = Color(0xFFDCE1EC);
  static const dividerSoft = Color(0xFFE8ECF4);
  static const bg = Color(0xFFF4F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const switchOff = Color(0xFFD4D8DF);
  static const onDarkMuted = Color(0xFFCBD3EC);
  static const onDarkInactive = Color(0xFFA8B5DF);

  static const info = Color(0xFF1E4FB8);
  static const infoBg = Color(0xFFE5EDFC);
  static const success = Color(0xFF16794A);
  static const successBg = Color(0xFFE3F4EA);
  static const warning = Color(0xFFA4520B);
  static const warningBg = Color(0xFFFCEEDC);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFDE8E7);

  static const cardShadow = BoxShadow(color: Color(0x1413225A), blurRadius: 20, offset: Offset(0, 6));
}
