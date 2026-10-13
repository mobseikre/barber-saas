import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

import 'package:customer_app/features/salon/salon_hours.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  SalonDayHours day(int weekday, int open, int close) => SalonDayHours(
    weekday: weekday,
    opensAt: TimeOfDay(hour: open, minute: 0),
    closesAt: TimeOfDay(hour: close, minute: 0),
  );

  test('weeklyHours groups consecutive days from Saturday and marks days off', () {
    final hours = [
      for (final d in [6, 0, 1, 2, 3]) day(d, 9, 22),
      day(4, 9, 23),
    ];

    expect(weeklyHours(hours), ['السبت – الأربعاء 9:00 ص – 10:00 م', 'الخميس 9:00 ص – 11:00 م', 'الجمعة عطلة']);
  });

  test('the same hours all week is one line', () {
    expect(weeklyHours([for (var d = 0; d < 7; d++) day(d, 10, 20)]), ['السبت – الجمعة 10:00 ص – 8:00 م']);
  });

  test('a salon without bookable barbers has no hours', () {
    expect(weeklyHours(const []), ['السبت – الجمعة عطلة']);
  });

  test('barbersCount uses the Arabic number forms', () {
    expect(
      [
        for (final n in [1, 2, 3, 10, 11]) barbersCount(n),
      ],
      ['حلاق واحد', 'حلاقان', '3 حلاقين', '10 حلاقين', '11 حلاقاً'],
    );
  });
}
