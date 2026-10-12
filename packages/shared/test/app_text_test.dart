import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('every text style sets the Cairo wght axis to its font weight', () {
    final styles = [
      AppText.display,
      AppText.h1,
      AppText.h2,
      AppText.h3,
      AppText.body,
      AppText.bodyStrong,
      AppText.caption,
      AppText.label,
      AppText.button,
      AppText.buttonSmall,
      AppText.cardTitle,
      AppText.inputLabel,
      AppText.time,
      AppText.statValue,
    ];
    for (final s in styles) {
      expect(s.fontVariations, [FontVariation.weight(s.fontWeight!.value.toDouble())]);
    }
  });
}
