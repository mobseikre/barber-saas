import 'package:intl/intl.dart';

import '../auth/phone.dart';

const _locale = 'ar';

/// Arabic words with Latin digits, as the design shows (الخميس، 8 أكتوبر · 25 د.ل).
abstract final class ArabicFormat {
  static final _dayDate = DateFormat('EEEE، d MMMM', _locale);
  static final _longDate = DateFormat('d MMMM yyyy', _locale);
  static final _time = DateFormat('h:mm a', _locale);
  static final _monthYear = DateFormat('MMMM yyyy', _locale);
  static final _dayMonth = DateFormat('d MMMM', _locale);
  static final _month = DateFormat('MMMM', _locale);
  static final _weekday = DateFormat('EEEE', _locale);
  static final _number = NumberFormat.decimalPattern(_locale);

  /// Day names by Postgres weekday (0 = Sunday), in the Libyan week order starting on Saturday.
  static const weekdays = {
    6: 'السبت',
    0: 'الأحد',
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
  };

  /// الخميس، 8 أكتوبر
  static String dayDate(DateTime d) => latinDigits(_dayDate.format(d));

  /// 8 أكتوبر 2026
  static String longDate(DateTime d) => latinDigits(_longDate.format(d));

  /// 9:30 م
  static String time(DateTime d) => latinDigits(_time.format(d));

  /// 8 أكتوبر
  static String dayMonth(DateTime d) => latinDigits(_dayMonth.format(d));

  /// أكتوبر
  static String month(DateTime d) => _month.format(d);

  /// الخميس
  static String weekday(DateTime d) => _weekday.format(d);

  /// أكتوبر 2026
  static String monthYear(DateTime d) => latinDigits(_monthYear.format(d));

  /// 25 د.ل
  static String price(num amount) => '${number(amount)} د.ل';

  /// 30 دقيقة
  static String minutes(int minutes) => '$minutes دقيقة';

  /// 0.8 كم, 12 كم
  static String distance(double meters) {
    final km = meters / 1000;
    return '${latinDigits(km < 10 ? km.toStringAsFixed(1) : km.round().toString())} كم';
  }

  /// 6,450
  static String number(num value) => latinDigits(_number.format(value));

  /// علي for علي القماطي
  static String firstName(String fullName) => fullName.trim().split(' ').first;

  /// 9:30 م for a time of day
  static String clock(int hour, int minute) => time(DateTime(2000, 1, 1, hour, minute));

  /// ساعة، ساعتين، 3 ساعات، 12 ساعة — as in «حتى ساعتين قبل الموعد».
  static String hours(int count) => switch (count) {
    1 => 'ساعة',
    2 => 'ساعتين',
    >= 3 && <= 10 => '$count ساعات',
    _ => '$count ساعة',
  };

  /// يوم واحد، يومان، 5 أيام، 12 يوماً
  static String days(int count) => switch (count) {
    1 => 'يوم واحد',
    2 => 'يومان',
    >= 3 && <= 10 => '$count أيام',
    _ => '$count يوماً',
  };

  /// الباقة الشهرية، الباقة السنوية، باقة 2 أشهر — the plan names of the admin panel's `planLabel`.
  static String planName(int months) => switch (months) {
    1 => 'الباقة الشهرية',
    3 => 'الباقة الربع سنوية',
    6 => 'الباقة النصف سنوية',
    12 => 'الباقة السنوية',
    2 => 'باقة شهرين',
    >= 3 && <= 10 => 'باقة $months أشهر',
    _ => 'باقة $months شهراً',
  };
}
