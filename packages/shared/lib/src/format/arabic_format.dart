import 'package:intl/intl.dart';

import '../auth/phone.dart';

const _locale = 'ar';

/// Arabic words with Latin digits, as the design shows (الخميس، 8 أكتوبر · 25 د.ل).
abstract final class ArabicFormat {
  static final _dayDate = DateFormat('EEEE، d MMMM', _locale);
  static final _longDate = DateFormat('d MMMM yyyy', _locale);
  static final _time = DateFormat('h:mm a', _locale);
  static final _monthYear = DateFormat('MMMM yyyy', _locale);
  static final _number = NumberFormat.decimalPattern(_locale);

  /// الخميس، 8 أكتوبر
  static String dayDate(DateTime d) => latinDigits(_dayDate.format(d));

  /// 8 أكتوبر 2026
  static String longDate(DateTime d) => latinDigits(_longDate.format(d));

  /// 9:30 م
  static String time(DateTime d) => latinDigits(_time.format(d));

  /// أكتوبر 2026
  static String monthYear(DateTime d) => latinDigits(_monthYear.format(d));

  /// 25 د.ل
  static String price(num amount) => '${number(amount)} د.ل';

  /// 30 دقيقة
  static String minutes(int minutes) => '$minutes دقيقة';

  /// 6,450
  static String number(num value) => latinDigits(_number.format(value));

  /// 9:30 م for a time of day
  static String clock(int hour, int minute) => time(DateTime(2000, 1, 1, hour, minute));

  /// يوم واحد، يومان، 5 أيام، 12 يوماً
  static String days(int count) => switch (count) {
    1 => 'يوم واحد',
    2 => 'يومان',
    >= 3 && <= 10 => '$count أيام',
    _ => '$count يوماً',
  };
}
