import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/data/my_bookings_repository.dart';
import 'package:customer_app/features/bookings/my_bookings_tab.dart';
import 'package:customer_app/features/home/home_shell.dart';
import 'package:customer_app/providers.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openTab(WidgetTester tester, {bool signedIn = true, List<MyBooking> seeds = const []}) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: signedIn ? 'customer-1' : null));
    deps.myBookings.items = seeds;
    await pumpPhone(tester, deps.app(const Scaffold(body: MyBookingsTab())));
  }

  final cancelButton = find.widgetWithText(InkWell, 'إلغاء الحجز');

  testWidgets('while a cancellation is sent the button shows it is working and cannot be pressed again', (
    tester,
  ) async {
    await openTab(tester, seeds: [myBooking()]);
    final gate = Completer<void>();
    deps.bookings.cancelGate = gate;
    deps.bookings.onCancel = deps.myBookings.markCancelled;

    await tapVisible(tester, cancelButton);
    await tester.tap(find.text('نعم، إلغاء الحجز'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final button = find.ancestor(of: find.byType(CircularProgressIndicator), matching: find.byType(ActionButton));
    expect(button, findsOneWidget);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(find.text('إلغاء الحجز؟'), findsNothing, reason: 'no second confirmation opens');

    gate.complete();
    await tester.pumpAndSettle();
    expect(deps.bookings.cancelled, hasLength(1));
    expect(find.text('تم إلغاء الحجز'), findsOneWidget);
    expect(
      find.text('لا توجد حجوزات قادمة'),
      findsOneWidget,
      reason: 'the list was refreshed before the card came back',
    );
  });

  testWidgets('حجوزاتي reloads every time the tab is opened and when the app comes back', (tester) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: 'customer-1'));
    await pumpPhone(tester, deps.app(const HomeShell()));
    final before = deps.myBookings.loads;

    await tester.tap(find.text('حجوزاتي'));
    await tester.pumpAndSettle();
    expect(deps.myBookings.loads, before + 1);

    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حجوزاتي'));
    await tester.pumpAndSettle();
    expect(deps.myBookings.loads, before + 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(deps.myBookings.loads, before + 3);
  });

  testWidgets('a visitor is asked to sign in', (tester) async {
    await openTab(tester, signedIn: false);

    expect(find.text('سجّل الدخول لترى حجوزاتك'), findsOneWidget);
    expect(deps.myBookings.loads, 0);
  });

  testWidgets('upcoming bookings come soonest first with their details, the count and the actions', (tester) async {
    await openTab(
      tester,
      seeds: [
        myBooking(id: 'later', startsIn: const Duration(days: 4), salon: 'حلاق الملوك', price: 15),
        myBooking(id: 'soon', startsIn: const Duration(days: 2, hours: 7, minutes: 30)),
        myBooking(id: 'old', startsIn: const Duration(days: -3), status: BookingStatus.completed),
      ],
    );

    expect(find.text('القادمة (2)'), findsOneWidget);
    final soonest = tester.getTopLeft(find.text('صالون الأناقة')).dy;
    expect(soonest, lessThan(tester.getTopLeft(find.text('حلاق الملوك')).dy));
    expect(find.text('مع علي القماطي · قص شعر · 5:30 م'), findsOneWidget);
    expect(find.text('25 د.ل'), findsOneWidget);
    expect(find.text('الأربعاء'), findsOneWidget);
    expect(find.text('الجمعة'), findsOneWidget);
    expect(find.text('مؤكد'), findsNWidgets(2));
    expect(find.text('الاتجاهات'), findsNWidgets(2));
    expect(cancelButton, findsNWidgets(2));
    expect(find.text('قيّم'), findsNothing, reason: 'past bookings are on the other tab');
  });

  testWidgets('the past tab lists completed, no-show and cancelled bookings with the rating action', (tester) async {
    await openTab(
      tester,
      seeds: [
        myBooking(id: 'a', startsIn: const Duration(days: -11), status: BookingStatus.completed),
        myBooking(id: 'b', startsIn: const Duration(days: -18), status: BookingStatus.completed, rating: 4),
        myBooking(id: 'c', startsIn: const Duration(days: -19), status: BookingStatus.cancelled, salon: 'ستايل مان'),
        myBooking(id: 'd', startsIn: const Duration(days: -20), status: BookingStatus.noShow, salon: 'صالون النخبة'),
      ],
    );
    expect(find.text('لا توجد حجوزات قادمة'), findsOneWidget);

    await tapVisible(tester, find.text('السابقة'));

    expect(find.text('مكتمل'), findsNWidgets(2));
    expect(find.text('ملغي'), findsOneWidget);
    expect(find.text('لم يحضر'), findsOneWidget);
    expect(find.text('قيّم'), findsOneWidget, reason: 'only the completed booking without a review');
    expect(find.text('4'), findsOneWidget, reason: 'the rated one shows its stars instead');
    expect(find.text('مع علي القماطي · قص شعر · 1 أكتوبر'), findsOneWidget);
    expect(cancelButton, findsNothing);
  });

  testWidgets('a confirmed booking whose time has passed is not upcoming', (tester) async {
    await openTab(tester, seeds: [myBooking(startsIn: const Duration(hours: -2))]);

    expect(find.text('القادمة (0)'), findsOneWidget);
    await tapVisible(tester, find.text('السابقة'));
    expect(find.text('مؤكد'), findsOneWidget);
  });

  testWidgets('cancelling asks first, then cancels and moves the booking to the past list', (tester) async {
    await openTab(tester, seeds: [myBooking()]);

    await tapVisible(tester, cancelButton);
    expect(find.text('إلغاء الحجز؟'), findsOneWidget);
    expect(find.textContaining('سيتم إلغاء حجزك في صالون الأناقة يوم الخميس، 15 أكتوبر'), findsOneWidget);
    expect(deps.bookings.cancelled, isEmpty);

    await tapVisible(tester, find.text('نعم، إلغاء الحجز'));

    expect(deps.bookings.cancelled, ['booking-1']);
    expect(find.text('تم إلغاء الحجز'), findsOneWidget);
    expect(find.text('القادمة (0)'), findsOneWidget);
    await tapVisible(tester, find.text('السابقة'));
    expect(find.text('ملغي'), findsOneWidget);
  });

  testWidgets('going back from the confirmation keeps the booking', (tester) async {
    await openTab(tester, seeds: [myBooking()]);

    await tapVisible(tester, cancelButton);
    await tapVisible(tester, find.text('رجوع'));

    expect(deps.bookings.cancelled, isEmpty);
    expect(find.text('القادمة (1)'), findsOneWidget);
  });

  testWidgets('a booking exactly at the cancellation window can still be cancelled', (tester) async {
    await openTab(tester, seeds: [myBooking(startsIn: AppConstants.cancellationWindow)]);

    await tapVisible(tester, cancelButton);

    expect(find.text('إلغاء الحجز؟'), findsOneWidget);
  });

  testWidgets('inside the cancellation window the refusal is explained and nothing is sent', (tester) async {
    await openTab(tester, seeds: [myBooking(startsIn: const Duration(minutes: 90))]);

    await tapVisible(tester, cancelButton);

    expect(find.text('لا يمكن إلغاء هذا الحجز'), findsOneWidget);
    expect(find.textContaining('يمكن إلغاء الحجز حتى ساعتين قبل الموعد فقط'), findsOneWidget);
    expect(find.text('إلغاء الحجز؟'), findsNothing);
    expect(deps.bookings.cancelled, isEmpty);

    await tapVisible(tester, find.text('حسناً'));
    expect(find.text('لا يمكن إلغاء هذا الحجز'), findsNothing);
    expect(find.text('القادمة (1)'), findsOneWidget);
  });

  testWidgets('a booking that already started says so', (tester) async {
    await openTab(tester, seeds: [myBooking(startsIn: const Duration(minutes: -10))]);

    await tapVisible(tester, cancelButton);

    expect(find.text('بدأ موعد هذا الحجز، ولا يمكن إلغاؤه الآن.'), findsOneWidget);
  });

  testWidgets('when the server refuses because of the window, the same explanation shows', (tester) async {
    await openTab(tester, seeds: [myBooking(startsIn: const Duration(hours: 3))]);
    deps.bookings.cancelError = rpcError('cancellation_window_passed');

    await tapVisible(tester, cancelButton);
    await tapVisible(tester, find.text('نعم، إلغاء الحجز'));

    expect(find.text('لا يمكن إلغاء هذا الحجز'), findsOneWidget);
    expect(find.text('تم إلغاء الحجز'), findsNothing);
  });

  testWidgets('any other cancel failure is shown as a message and the booking stays', (tester) async {
    await openTab(tester, seeds: [myBooking()]);
    deps.bookings.cancelError = Exception('offline');

    await tapVisible(tester, cancelButton);
    await tapVisible(tester, find.text('نعم، إلغاء الحجز'));

    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.text('القادمة (1)'), findsOneWidget);
  });

  testWidgets('pulling down reloads the bookings', (tester) async {
    await openTab(tester, seeds: [myBooking()]);
    expect(deps.myBookings.loads, 1);

    deps.myBookings.items = [myBooking(id: 'new', salon: 'حلاق الملوك')];
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(deps.myBookings.loads, 2);
    expect(find.text('حلاق الملوك'), findsOneWidget);
  });

  testWidgets('pulling down works on an empty list too', (tester) async {
    await openTab(tester);
    deps.myBookings.items = [myBooking()];

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('صالون الأناقة'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: 'customer-1'));
    deps.myBookings.loadError = Exception('offline');
    await pumpPhone(tester, deps.app(const Scaffold(body: MyBookingsTab())));
    expect(find.text(genericErrorMessage), findsOneWidget);

    deps.myBookings
      ..loadError = null
      ..items = [myBooking()];
    await tapVisible(tester, find.text('إعادة المحاولة'));

    expect(find.text('صالون الأناقة'), findsOneWidget);
  });

  testWidgets('directions open the maps app at the salon', (tester) async {
    final launcher = FakeLauncher(tester);
    await openTab(tester, seeds: [myBooking()]);

    await tapVisible(tester, find.text('الاتجاهات'));

    expect(launcher.urls, [directionsUri(32.8752, 13.1146)]);
  });

  testWidgets('without a maps app the failure is explained', (tester) async {
    FakeLauncher(tester, opens: false);
    await openTab(tester, seeds: [myBooking()]);

    await tapVisible(tester, find.text('الاتجاهات'));

    expect(find.text('تعذّر فتح الخرائط'), findsOneWidget);
  });

  testWidgets('directions are disabled when the salon has no location', (tester) async {
    await openTab(tester, seeds: [myBooking(latitude: null, longitude: null)]);

    final button = tester.widget<InkWell>(find.widgetWithText(InkWell, 'الاتجاهات'));
    expect(button.onTap, isNull);
  });

  testWidgets('the offline notice shows only while the data comes from the cache', (tester) async {
    await openTab(tester, seeds: [myBooking()]);
    expect(find.textContaining('غير متصل'), findsNothing);

    deps.offline.value = testNow.subtract(const Duration(minutes: 30));
    await tester.pumpAndSettle();
    expect(find.text('غير متصل · آخر تحديث 9:30 ص'), findsOneWidget);
    expect(find.text('صالون الأناقة'), findsOneWidget);

    deps.offline.value = null;
    await tester.pumpAndSettle();
    expect(find.textContaining('غير متصل'), findsNothing);
  });

  testWidgets('a booking whose barber left the directory still shows the barber and salon', (tester) async {
    await openTab(
      tester,
      seeds: [myBooking(barber: 'مراد الزنتاني', salon: 'حلاق الملوك')],
    );

    expect(find.text('حلاق الملوك'), findsOneWidget);
    expect(find.text('مع مراد الزنتاني · قص شعر · 10:00 ص'), findsOneWidget);
  });

  testWidgets('signing out from the account tab clears the bookings list', (tester) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: 'customer-1'));
    deps.myBookings.items = [myBooking()];
    await pumpPhone(tester, deps.app(const HomeShell()));
    await tapVisible(tester, find.text('حجوزاتي'));
    expect(find.text('صالون الأناقة'), findsOneWidget);

    await tapVisible(tester, find.text('حسابي'));
    await tapVisible(tester, find.text('تسجيل الخروج'));
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('حجوزاتي'));

    expect(find.text('صالون الأناقة'), findsNothing);
    expect(find.text('سجّل الدخول لترى حجوزاتك'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(MyBookingsTab)));
    expect(await container.read(myBookingsProvider.future), isEmpty);
  });
}
