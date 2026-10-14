import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/booking/booking_screen.dart';
import 'package:customer_app/features/salon/salon_screen.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openSalon(WidgetTester tester, {String barberId = 'ali'}) async {
    deps = TestDeps();
    deps.directory.team = [
      SalonBarber(
        id: 'ali',
        salonId: 'salon-1',
        displayName: 'علي القماطي',
        isVip: true,
        isBookable: true,
        ratingAvg: 4.8,
        ratingCount: 212,
      ),
      SalonBarber(
        id: 'mohamed',
        salonId: 'salon-1',
        displayName: 'محمد السويحلي',
        isBookable: true,
        ratingAvg: 4.9,
        ratingCount: 64,
      ),
      SalonBarber(id: 'walid', salonId: 'salon-1', displayName: 'وليد الشريف'),
    ];
    deps.directory.hours = [
      for (final d in [6, 0, 1, 2, 3, 4])
        SalonDayHours(
          weekday: d,
          opensAt: const TimeOfDay(hour: 9, minute: 0),
          closesAt: const TimeOfDay(hour: 22, minute: 0),
        ),
    ];
    deps.barbers.services['mohamed'] = [service('haircut', 'قص شعر', 20, 30, barberId: 'mohamed')];
    await pumpPhone(tester, deps.app(SalonScreen(salonId: 'salon-1', barberId: barberId)));
  }

  testWidgets('shows the salon, its hours and every barber, marking the ones not bookable', (tester) async {
    await openSalon(tester);

    expect(find.text('صالون الأناقة'), findsOneWidget);
    expect(find.text('حي الأندلس، طرابلس · 0.6 كم'), findsOneWidget);
    expect(find.text('السبت – الخميس 9:00 ص – 10:00 م'), findsOneWidget, reason: 'one line per group of days');
    expect(find.text('الجمعة عطلة'), findsOneWidget);
    expect(find.text('مفتوح الآن'), findsOneWidget);
    expect(find.text('3 حلاقين · 2 متاحون للحجز'), findsOneWidget);
    expect(find.text('غير متاح للحجز'), findsOneWidget);
    expect(find.textContaining('غير مشتركين في التطبيق'), findsOneWidget);
    expect(find.text('خدمات وأسعار علي'), findsOneWidget);
    expect(find.text('يبدأ من 15 د.ل'), findsOneWidget);
  });

  testWidgets('choosing another barber shows their services; a barber not bookable cannot be chosen', (tester) async {
    await openSalon(tester);

    await tapVisible(tester, find.text('وليد الشريف'));
    expect(find.text('خدمات وأسعار علي'), findsOneWidget);

    await tapVisible(tester, find.text('محمد السويحلي'));
    expect(find.text('خدمات وأسعار محمد'), findsOneWidget);
    expect(find.text('مع محمد'), findsOneWidget);
    expect(find.text('يبدأ من 20 د.ل'), findsOneWidget);
  });

  testWidgets('a requested barber who cannot be booked is not swapped for another one', (tester) async {
    await openSalon(tester, barberId: 'walid');

    expect(find.text('وليد الشريف غير متاح للحجز حالياً'), findsOneWidget);
    expect(find.text('اختر حلاقاً آخر من الصالون'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing, reason: 'nobody is chosen for the customer');
    expect(find.textContaining('خدمات وأسعار'), findsNothing);
    expect(find.text('اختر حلاقاً متاحاً'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'احجز الآن')).onPressed, isNull);

    await tapVisible(tester, find.text('محمد السويحلي'));

    expect(find.text('وليد الشريف غير متاح للحجز حالياً'), findsNothing);
    expect(find.text('مع محمد'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'احجز الآن')).onPressed, isNotNull);
  });

  testWidgets('a requested barber alone in a salon with nobody bookable gets no hint to choose another', (
    tester,
  ) async {
    deps = TestDeps();
    deps.directory.team = [SalonBarber(id: 'walid', salonId: 'salon-1', displayName: 'وليد الشريف')];
    await pumpPhone(tester, deps.app(const SalonScreen(salonId: 'salon-1', barberId: 'walid')));

    expect(find.text('وليد الشريف غير متاح للحجز حالياً'), findsOneWidget);
    expect(find.text('اختر حلاقاً آخر من الصالون'), findsNothing);
    expect(find.text('لا يوجد حلاق متاح للحجز'), findsOneWidget);
  });

  testWidgets('only the chosen barber carries the check mark', (tester) async {
    await openSalon(tester);
    final check = find.byIcon(Icons.check_rounded);
    Finder tileOf(String name) => find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

    expect(check, findsOneWidget);
    expect(find.descendant(of: tileOf('علي القماطي'), matching: check), findsOneWidget);
    final crown = tester.getRect(find.byIcon(Icons.workspace_premium_rounded));
    expect(crown.overlaps(tester.getRect(check)), isFalse, reason: 'the VIP crown and the check mark do not collide');

    await tapVisible(tester, find.text('محمد السويحلي'));
    expect(check, findsOneWidget);
    expect(find.descendant(of: tileOf('محمد السويحلي'), matching: check), findsOneWidget);
  });

  testWidgets('directions and call open the maps app and the dialer with the salon and the barber', (tester) async {
    final launcher = FakeLauncher(tester);
    await openSalon(tester);

    await tapVisible(tester, find.text('الاتجاهات'));
    await tapVisible(tester, find.byTooltip('اتصال'));

    expect(launcher.urls, [directionsUri(32.8752, 13.1146), Uri.parse('tel:+218912345678')]);
  });

  testWidgets('a salon that fails to load offers a retry', (tester) async {
    deps = TestDeps();
    deps.directory.teamError = Exception('offline');
    await pumpPhone(tester, deps.app(const SalonScreen(salonId: 'salon-1', barberId: 'ali')));
    expect(find.text('تعذّر تحميل الصالون'), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget, reason: 'the error state can be left');

    deps.directory
      ..teamError = null
      ..team = [SalonBarber(id: 'ali', salonId: 'salon-1', displayName: 'علي القماطي', isBookable: true)];
    await tapVisible(tester, find.text('إعادة المحاولة'));

    expect(find.text('اختر حلاقك'), findsOneWidget);
  });

  testWidgets('a salon with nobody listed says it is unavailable and can be left', (tester) async {
    deps = TestDeps();
    deps.directory.team = const [];
    deps.directory.barbers = const [];
    await pumpPhone(
      tester,
      deps.app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const SalonScreen(salonId: 'salon-gone'))),
            child: const Text('فتح'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الصالون غير متاح حالياً'), findsOneWidget);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SalonScreen), findsNothing);
  });

  testWidgets('احجز الآن opens the booking with the chosen barber', (tester) async {
    await openSalon(tester);

    await tester.tap(find.text('احجز الآن'));
    await tester.pumpAndSettle();

    expect(tester.widget<BookingScreen>(find.byType(BookingScreen)).barber.id, 'ali');
  });

  testWidgets('each bookable barber tile shows the next free time, tomorrow when today is full', (tester) async {
    deps = TestDeps();
    final today = dbDate(AppTime.now());
    final free = deps.bookings.slots;
    deps.bookings.slots = (date, duration) => date == today ? const [] : free(date, duration);
    deps.directory.team = [
      SalonBarber(id: 'ali', salonId: 'salon-1', displayName: 'علي القماطي', isBookable: true),
      SalonBarber(id: 'walid', salonId: 'salon-1', displayName: 'وليد الشريف'),
    ];
    await pumpPhone(tester, deps.app(const SalonScreen(salonId: 'salon-1')));

    expect(find.text('غداً 11:30 ص'), findsOneWidget);
    expect(deps.bookings.slotRequests.length, 2, reason: 'one lookup per day, only for the bookable barber');
  });

  test('the next free label names today or tomorrow', () {
    final now = DateTime.utc(2026, 10, 12, 8);
    TimeSlot at(DateTime t) => TimeSlot(startsAt: t, endsAt: t.add(const Duration(minutes: 30)));

    expect(NextFreeLabel.text(at(AppTime.at(now, 16, 0)), now), 'اليوم 4:00 م');
    expect(NextFreeLabel.text(at(AppTime.at(now.add(const Duration(days: 1)), 10, 0)), now), 'غداً 10:00 ص');
  });
}
