import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants.dart';

/// Wall-clock time in [AppConstants.timezone], whatever the device is set to.
abstract final class AppTime {
  static tz.Location? _location;

  static tz.Location get location => _location ??= () {
    tzdata.initializeTimeZones();
    return tz.getLocation(AppConstants.timezone);
  }();

  static DateTime Function() clock = DateTime.now;

  static DateTime now() => tz.TZDateTime.from(clock(), location);

  static DateTime from(DateTime instant) => tz.TZDateTime.from(instant, location);

  static DateTime startOfDay(DateTime instant) => at(instant, 0, 0);

  static DateTime at(DateTime instant, int hour, int minute) {
    final d = from(instant);
    return tz.TZDateTime(location, d.year, d.month, d.day, hour, minute);
  }

  static ({DateTime start, DateTime end}) dayRange(DateTime instant) {
    final d = from(instant);
    return (start: startOfDay(d), end: tz.TZDateTime(location, d.year, d.month, d.day + 1));
  }

  static DateTime nextQuarterHour(DateTime from) {
    final t = AppTime.from(from.add(const Duration(minutes: 15)));
    return at(t, t.hour, t.minute - t.minute % 15);
  }
}
