import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  tearDown(() => AppTime.clock = DateTime.now);

  test('now() is Tripoli wall time whatever the device zone', () {
    AppTime.clock = () => DateTime.utc(2026, 10, 10, 22, 30);
    final now = AppTime.now();

    expect((now.year, now.month, now.day, now.hour, now.minute), (2026, 10, 11, 0, 30));
    expect(now.toUtc(), DateTime.utc(2026, 10, 10, 22, 30), reason: 'same instant');
  });

  test('a Tripoli day starts at 22:00 UTC the previous evening', () {
    final range = AppTime.dayRange(DateTime.utc(2026, 10, 10, 23, 30));

    expect(range.start.toUtc(), DateTime.utc(2026, 10, 10, 22));
    expect(range.end.toUtc(), DateTime.utc(2026, 10, 11, 22));
  });

  test('dbDate is the Tripoli calendar date', () {
    expect(dbDate(DateTime.utc(2026, 10, 10, 21, 59)), '2026-10-10');
    expect(dbDate(DateTime.utc(2026, 10, 10, 22)), '2026-10-11');
  });

  test('startOfDay and at build Tripoli times from any instant', () {
    final instant = DateTime.utc(2026, 10, 11, 21, 59);

    expect(AppTime.startOfDay(instant).toUtc(), DateTime.utc(2026, 10, 10, 22));
    expect(AppTime.at(instant, 9, 30).toUtc(), DateTime.utc(2026, 10, 11, 7, 30));
  });

  test('nextQuarterHour rounds up inside the day and rolls over at midnight', () {
    expect(AppTime.nextQuarterHour(DateTime.utc(2026, 10, 11, 8, 7)).toUtc(), DateTime.utc(2026, 10, 11, 8, 15));
    expect(AppTime.nextQuarterHour(DateTime.utc(2026, 10, 11, 8, 0)).toUtc(), DateTime.utc(2026, 10, 11, 8, 15));

    final midnight = AppTime.nextQuarterHour(DateTime.utc(2026, 10, 11, 21, 50));
    expect((midnight.day, midnight.hour, midnight.minute), (12, 0, 0));
    expect(midnight.toUtc(), DateTime.utc(2026, 10, 11, 22));
  });

  test('booking times are parsed into Tripoli wall time', () {
    final range = parseTstzRange('["2026-10-10 22:30:00+00","2026-10-10 23:00:00+00")');

    expect((range.start.day, range.start.hour, range.start.minute), (11, 0, 30));
    expect(ArabicFormat.time(range.start), '12:30 ص');
    expect(range.end.difference(range.start), const Duration(minutes: 30));
  });

  test('hasStarted follows the app clock', () {
    final b = Booking.fromJson(_booking(range: '["2026-10-11 08:00:00+00","2026-10-11 08:30:00+00")'));

    AppTime.clock = () => DateTime.utc(2026, 10, 11, 7, 59);
    expect(b.hasStarted, isFalse);
    AppTime.clock = () => DateTime.utc(2026, 10, 11, 8);
    expect(b.hasStarted, isTrue);
  });

  test('dbDate and dbWeekday use the Tripoli calendar day', () {
    final lateSaturdayUtc = DateTime.utc(2026, 10, 10, 22, 30);

    expect(dbDate(lateSaturdayUtc), '2026-10-11');
    expect(dbWeekday(AppTime.from(lateSaturdayUtc)), 0, reason: 'Sunday in Tripoli is weekday 0 in Postgres');
    expect(dbWeekday(DateTime(2026, 10, 10)), 6);
  });

  test('a confirmed booking stays upcoming until it ends', () {
    AppTime.clock = () => DateTime.utc(2026, 10, 10, 8, 15);
    Booking at(int startMinute) => Booking(
      id: 'b',
      barberId: 'x',
      serviceId: 's',
      price: 25,
      durationMin: 30,
      startsAt: DateTime.utc(2026, 10, 10, 8, startMinute),
      endsAt: DateTime.utc(2026, 10, 10, 8, startMinute + 30),
      status: BookingStatus.confirmed,
      source: BookingSource.app,
      createdAt: DateTime.utc(2026),
    );

    expect(at(0).isUpcoming, isTrue, reason: 'it started but has not ended');
    expect(at(-30).isUpcoming, isFalse);
  });
}

Map<String, dynamic> _booking({required String range}) => {
  'id': 'k1',
  'barber_id': 'b1',
  'customer_id': 'c1',
  'service_id': 's1',
  'price': 25,
  'duration_min': 30,
  'time_range': range,
  'status': 'confirmed',
  'source': 'app',
  'created_at': '2026-10-10T08:00:00+00:00',
};
