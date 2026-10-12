import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/account/account_tab.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/home/home_shell.dart';
import 'package:barber_app/features/services/services_screen.dart';
import 'package:barber_app/features/stats/stats_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;

  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() {
    repo = FakeBarberRepo()
      ..statsValue = const BarberStats(
        todayCustomers: 3,
        todayCompleted: 1,
        todayNoShow: 0,
        todayIncome: 25,
        monthCustomers: 40,
        monthIncome: 900,
        topServices: [],
      );
  });

  Future<void> pumpShell(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        home: const HomeShell(),
        barbers: repo,
        overrides: [todayBookingsProvider.overrideWith(() => FakeTodayBookings(const []))],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the tabs open their screens, which are only built on the first visit', (tester) async {
    await pumpShell(tester);

    expect(find.text('حجوزات اليوم'), findsOneWidget);
    expect(find.byType(ServicesScreen), findsNothing);
    expect(find.byType(StatsScreen), findsNothing);
    expect(find.byType(AccountTab), findsNothing);

    await tester.tap(find.text('الخدمات'));
    await tester.pumpAndSettle();
    expect(find.text('خدماتي'), findsOneWidget);

    await tester.tap(find.text('الإحصائيات'));
    await tester.pumpAndSettle();
    expect(find.text('زبائن الشهر'), findsOneWidget);

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    expect(find.text('الاشتراك'), findsOneWidget);

    await tester.tap(find.text('الحجوزات'));
    await tester.pumpAndSettle();
    expect(find.text('حجوزات اليوم'), findsOneWidget);
  });

  testWidgets('the nav labels fit a 320px screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpShell(tester, size: const Size(320, 568));

    for (final label in ['الحجوزات', 'الخدمات', 'الإحصائيات', 'حسابي']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
