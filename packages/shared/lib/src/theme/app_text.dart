import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const cairo = 'packages/shared/Cairo';
}

/// Type scale from the design system board. Sizes are size/line-height.
abstract final class AppText {
  static const _base = TextStyle(fontFamily: AppFonts.cairo, color: AppColors.text);

  /// Sets [weight] on the style and on the `wght` axis of the Cairo variable font.
  static TextStyle weight(TextStyle style, FontWeight weight) =>
      style.copyWith(fontWeight: weight, fontVariations: [FontVariation.weight(weight.value.toDouble())]);

  static final display = weight(_base.copyWith(fontSize: 32, height: 44 / 32), FontWeight.w800);
  static final h1 = weight(_base.copyWith(fontSize: 24, height: 36 / 24), FontWeight.w700);
  static final h2 = weight(_base.copyWith(fontSize: 20, height: 30 / 20), FontWeight.w700);
  static final h3 = weight(_base.copyWith(fontSize: 17, height: 26 / 17), FontWeight.w600);
  static final body = weight(_base.copyWith(fontSize: 15, height: 24 / 15), FontWeight.w400);
  static final bodyStrong = weight(_base.copyWith(fontSize: 15, height: 24 / 15), FontWeight.w600);
  static final caption = weight(_base.copyWith(fontSize: 13, height: 20 / 13), FontWeight.w500);
  static final label = weight(_base.copyWith(fontSize: 12, height: 18 / 12), FontWeight.w700);

  static final button = weight(_base.copyWith(fontSize: 16, height: 1.25), FontWeight.w700);
  static final buttonCompact = weight(_base.copyWith(fontSize: 14, height: 1.25), FontWeight.w700);
  static final buttonSmall = weight(_base.copyWith(fontSize: 15, height: 1.25), FontWeight.w700);
  static final cardTitle = weight(_base.copyWith(fontSize: 16, height: 1.4), FontWeight.w700);
  static final inputLabel = weight(_base.copyWith(fontSize: 14, height: 1.4), FontWeight.w600);
  static final time = weight(_base.copyWith(fontSize: 18, height: 1.2), FontWeight.w800);
  static final incomeValue = weight(_base.copyWith(fontSize: 26, height: 1.2), FontWeight.w800);
  static final tileTitle = weight(_base.copyWith(fontSize: 18, height: 1.4), FontWeight.w800);
  static final statValue = weight(_base.copyWith(fontSize: 32, height: 1.2), FontWeight.w800);
}
