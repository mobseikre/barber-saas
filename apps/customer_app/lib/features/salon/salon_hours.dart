import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// The week from Saturday, one line per run of days with the same hours.
List<String> weeklyHours(List<SalonDayHours> hours) {
  final byDay = {for (final h in hours) h.weekday: h};
  String? label(int day) {
    final h = byDay[day];
    return h == null ? null : '${_clock(h.opensAt)} – ${_clock(h.closesAt)}';
  }

  final days = ArabicFormat.weekdays.keys.toList();
  final lines = <String>[];
  var start = 0;
  for (var i = 1; i <= days.length; i++) {
    if (i < days.length && label(days[i]) == label(days[start])) continue;
    final names = i - 1 == start
        ? ArabicFormat.weekdays[days[start]]!
        : '${ArabicFormat.weekdays[days[start]]} – ${ArabicFormat.weekdays[days[i - 1]]}';
    lines.add('$names ${label(days[start]) ?? 'عطلة'}');
    start = i;
  }
  return lines;
}

String _clock(TimeOfDay t) => ArabicFormat.clock(t.hour, t.minute);

/// 1 متاح للحجز، 4 متاحون للحجز
String availableCount(int count) => count == 1 ? '1 متاح للحجز' : '$count متاحون للحجز';

/// حلاق واحد، حلاقان، 3 حلاقين، 11 حلاقاً
String barbersCount(int count) => switch (count) {
  1 => 'حلاق واحد',
  2 => 'حلاقان',
  >= 3 && <= 10 => '$count حلاقين',
  _ => '$count حلاقاً',
};
