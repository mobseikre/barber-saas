import 'package:flutter_test/flutter_test.dart';
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

  test('ArabicFormat.number groups thousands with Latin digits', () {
    expect(ArabicFormat.number(340), '340');
    expect(ArabicFormat.number(6450), '6,450');
    expect(ArabicFormat.number(12.5), '12.5');
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
}
