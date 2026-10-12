import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/stats/stats_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;

  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() {
    AppTime.clock = () => DateTime.utc(2026, 10, 8, 10);
    repo = FakeBarberRepo()
      ..statsValue = const BarberStats(
        todayCustomers: 12,
        todayCompleted: 5,
        todayNoShow: 1,
        todayIncome: 340,
        monthCustomers: 214,
        monthIncome: 6450,
        topServices: [
          ServiceCount(nameAr: 'قص شعر', count: 98),
          ServiceCount(nameAr: 'لحية', count: 54),
          ServiceCount(nameAr: 'أطفال', count: 31),
        ],
      );
  });
  tearDown(() => AppTime.clock = DateTime.now);

  Future<void> pumpStats(WidgetTester tester) async {
    await pumpPhone(tester, testApp(home: const StatsScreen(), barbers: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('shows customers, estimated income and the month', (tester) async {
    await pumpStats(tester);

    expect(find.text('الإحصائيات'), findsOneWidget);
    expect(find.text('أكتوبر 2026'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5 مكتمل · 1 لم يحضر'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('حتى اليوم 8'), findsOneWidget);
    expect(find.text('دخل اليوم التقديري'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
    expect(find.text('6,450'), findsOneWidget);
    expect(find.text('الدخل تقديري ومحسوب من أسعار الحجوزات المكتملة فقط.'), findsOneWidget);
  });

  testWidgets('lists the top services with their counts, the first one highlighted', (tester) async {
    await pumpStats(tester);

    expect(find.text('الخدمة الأكثر طلباً هذا الشهر'), findsOneWidget);
    expect(find.text('قص شعر'), findsNWidgets(2), reason: 'the headline and its bar');
    expect(find.text('98'), findsOneWidget);
    expect(find.text('54'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);

    final track = tester.getSize(find.byKey(const ValueKey('bar-track-قص شعر'))).width;
    final top = tester.getSize(find.byKey(const ValueKey('bar-fill-قص شعر')));
    final second = tester.getSize(find.byKey(const ValueKey('bar-fill-لحية')));
    expect(top.width, track, reason: 'the top service fills its track');
    expect(top.height, greaterThan(0));
    expect(second.width, closeTo(track * 54 / 98, 0.5));
    expect(second.height, greaterThan(0));
  });

  testWidgets('an empty month says so instead of showing bars', (tester) async {
    repo.statsValue = const BarberStats(
      todayCustomers: 0,
      todayCompleted: 0,
      todayNoShow: 0,
      todayIncome: 0,
      monthCustomers: 0,
      monthIncome: 0,
      topServices: [],
    );
    await pumpStats(tester);

    expect(find.text('لا توجد حجوزات هذا الشهر'), findsOneWidget);
    expect(find.text('0 د.ل'), findsNothing);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    repo.failLoads = 1;
    await pumpStats(tester);
    expect(find.text(genericErrorMessage), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('214'), findsOneWidget);
  });

  testWidgets('a top service count of zero draws empty bars instead of failing', (tester) async {
    repo.statsValue = const BarberStats(
      todayCustomers: 0,
      todayCompleted: 0,
      todayNoShow: 0,
      todayIncome: 0,
      monthCustomers: 0,
      monthIncome: 0,
      topServices: [ServiceCount(nameAr: 'قص شعر', count: 0)],
    );
    await pumpStats(tester);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('bar-fill-قص شعر'))).width, greaterThan(0));
  });
}
