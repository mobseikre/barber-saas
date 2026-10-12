import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Outline border that also paints the 4px focus ring around the field.
class FocusRingBorder extends OutlineInputBorder {
  const FocusRingBorder({super.borderSide, super.borderRadius});

  @override
  FocusRingBorder copyWith({BorderSide? borderSide, BorderRadius? borderRadius, double? gapPadding}) {
    return FocusRingBorder(borderSide: borderSide ?? this.borderSide, borderRadius: borderRadius ?? this.borderRadius);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final ring = borderRadius.resolve(textDirection).toRRect(rect).inflate(AppSizes.focusRing / 2);
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.focusRing
        ..color = AppColors.red50,
    );
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }
}
