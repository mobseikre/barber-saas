import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

void main() {
  test('ArabicFormat.days uses the right Arabic number form', () {
    expect(ArabicFormat.days(1), 'يوم واحد');
    expect(ArabicFormat.days(2), 'يومان');
    expect(ArabicFormat.days(3), '3 أيام');
    expect(ArabicFormat.days(10), '10 أيام');
    expect(ArabicFormat.days(11), '11 يوماً');
    expect(ArabicFormat.days(30), '30 يوماً');
  });

  test('ArabicFormat has the short date parts the booking cards use', () async {
    await initializeDateFormatting('ar');
    final day = DateTime(2026, 10, 1);

    expect(ArabicFormat.dayMonth(day), '1 أكتوبر');
    expect(ArabicFormat.month(day), 'أكتوبر');
    expect(ArabicFormat.weekday(day), 'الخميس');
  });

  test('directionsUri points Google Maps at the coordinates', () {
    expect(
      directionsUri(32.875, 13.115).toString(),
      'https://www.google.com/maps/dir/?api=1&destination=32.875%2C13.115',
    );
  });

  test('ArabicFormat.number groups thousands with Latin digits', () {
    expect(ArabicFormat.number(340), '340');
    expect(ArabicFormat.number(6450), '6,450');
    expect(ArabicFormat.number(12.5), '12.5');
  });

  test('ArabicFormat.hours uses the right Arabic number form', () {
    expect(
      [
        for (final n in [1, 2, 3, 10, 12]) ArabicFormat.hours(n),
      ],
      ['ساعة', 'ساعتين', '3 ساعات', '10 ساعات', '12 ساعة'],
    );
  });

  test('ArabicFormat.distance shows kilometres, with one decimal below 10 km', () {
    expect(ArabicFormat.distance(800), '0.8 كم');
    expect(ArabicFormat.distance(2149), '2.1 كم');
    expect(ArabicFormat.distance(12400), '12 كم');
  });

  test('BarberStats reads the barber_stats result', () {
    final stats = BarberStats.fromJson({
      'today_customers': 12,
      'today_completed': 5,
      'today_no_show': 1,
      'today_income': 340,
      'month_customers': 214,
      'month_income': 6450.5,
      'top_services': [
        {'name_ar': 'قص شعر', 'count': 98},
        {'name_ar': 'لحية', 'count': 54},
      ],
    });

    expect((stats.todayCustomers, stats.todayCompleted, stats.todayNoShow), (12, 5, 1));
    expect((stats.todayIncome, stats.monthCustomers, stats.monthIncome), (340.0, 214, 6450.5));
    expect(stats.topServices.map((s) => (s.nameAr, s.count)), [('قص شعر', 98), ('لحية', 54)]);
  });

  test('BarberStats with no services in the month', () {
    final stats = BarberStats.fromJson({
      'today_customers': 0,
      'today_completed': 0,
      'today_no_show': 0,
      'today_income': 0,
      'month_customers': 0,
      'month_income': 0,
      'top_services': <dynamic>[],
    });

    expect(stats.topServices, isEmpty);
    expect(stats.monthIncome, 0.0);
  });

  test('ArabicFormat.firstName takes the first word of a full name', () {
    expect(ArabicFormat.firstName('  علي القماطي '), 'علي');
    expect(ArabicFormat.firstName('محمد'), 'محمد');
  });
}
