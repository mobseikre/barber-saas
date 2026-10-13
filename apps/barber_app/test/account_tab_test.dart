import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/account/account_tab.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;
  late FakeAuthRepo auth;
  final now = DateTime.utc(2026, 10, 8, 10);

  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() {
    AppTime.clock = () => now;
    repo = FakeBarberRepo();
    auth = FakeAuthRepo(userId: 'u1', newUserId: 'u1');
  });
  tearDown(() => AppTime.clock = DateTime.now);

  Barber barberEnding(DateTime? ends) => Barber(
    id: 'b1',
    profileId: 'u1',
    salonId: 'salon-1',
    displayName: 'علي القماطي',
    status: BarberStatus.active,
    subscriptionEndsAt: ends,
    createdAt: DateTime(2026),
  );

  SubscriptionPayment paid(DateTime start, DateTime end) => SubscriptionPayment(
    id: 'p1',
    barberId: 'b1',
    amount: 50,
    paidAt: start,
    periodStart: start,
    periodEnd: end,
    recordedBy: 'admin',
  );

  Future<void> pumpAccount(
    WidgetTester tester, {
    Barber? barber,
    Future<Barber?> Function()? loader,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(home: const AccountTab(), barbers: repo, auth: auth, barber: barber, barberLoader: loader),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an active subscription shows the days left, the dates and the progress', (tester) async {
    final ends = now.add(const Duration(days: 12));
    repo.payment = paid(ends.subtract(const Duration(days: 30)), ends);
    await pumpAccount(tester, barber: barberEnding(ends));

    expect(find.text('الاشتراك'), findsOneWidget);
    expect(find.text('باقتك الحالية'), findsOneWidget);
    expect(find.text('الباقة الشهرية'), findsOneWidget);
    expect(find.text('فعّال'), findsOneWidget);
    expect(find.text('20 أكتوبر 2026'), findsOneWidget);
    expect(find.text('12 يوماً'), findsOneWidget);
    expect(find.text('بدأ في 20 سبتمبر 2026 · باقي 12 من 30 يوماً'), findsOneWidget);

    final remaining = tester.getSize(find.byKey(const ValueKey('progress-remaining')));
    final elapsed = tester.getSize(find.byKey(const ValueKey('progress-elapsed')));
    expect(remaining.height, greaterThan(0));
    expect(remaining.width / (remaining.width + elapsed.width), closeTo(12 / 30, 0.01));
  });

  testWidgets('an expired subscription is not shown as active and has no days left', (tester) async {
    final ends = now.subtract(const Duration(days: 2));
    repo.payment = paid(ends.subtract(const Duration(days: 30)), ends);
    await pumpAccount(tester, barber: barberEnding(ends));

    expect(find.text('فعّال'), findsNothing);
    expect(find.text('منتهٍ'), findsNWidgets(2), reason: 'the pill and the remaining tile');
    expect(find.textContaining('باقي'), findsNothing);
  });

  testWidgets('a subscription ending today still counts as active with one day left', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(hours: 5))));

    expect(find.text('فعّال'), findsOneWidget);
    expect(find.text('يوم واحد'), findsOneWidget);
  });

  testWidgets('after an extension past the paid period the caption never exceeds the period', (tester) async {
    final ends = now.add(const Duration(days: 45));
    repo.payment = paid(now.subtract(const Duration(days: 10)), now.add(const Duration(days: 20)));
    await pumpAccount(tester, barber: barberEnding(ends));

    expect(find.text('45 يوماً'), findsOneWidget, reason: 'the tile shows the real days left');
    expect(find.textContaining('باقي 30 من 30 يوماً'), findsOneWidget);
    expect(find.textContaining('باقي 45'), findsNothing);
  });

  testWidgets('the status pill puts the dot before the label', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))));

    final label = tester.getCenter(find.text('فعّال'));
    final dot = find.descendant(
      of: find.ancestor(of: find.text('فعّال'), matching: find.byType(Row)).first,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(tester.getCenter(dot).dx, greaterThan(label.dx), reason: 'start is the right side in RTL');
  });

  testWidgets('menu chevrons point left, towards the next screen in RTL', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))));

    final row = find.ancestor(of: find.text('أوقات العمل'), matching: find.byType(InkWell)).first;
    final chevron = tester.widget<Icon>(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.chevron_right_rounded),
      ),
    );
    expect(chevron.icon!.matchTextDirection, isTrue);
    expect(
      find.descendant(of: row, matching: find.byWidgetPredicate((w) => w is Transform && w.transform.storage[0] == -1)),
      findsOneWidget,
      reason: 'the right-pointing glyph is mirrored to point left',
    );
  });

  testWidgets('shows the admin number from the shared constant', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))));

    expect(find.text('للتجديد أو تغيير الباقة'), findsOneWidget);
    expect(find.text(formatLibyanPhone(AppConstants.supportWhatsAppNumber)), findsOneWidget);
    expect(find.byTooltip('اتصال بالإدارة'), findsOneWidget);
  });

  testWidgets('the menu opens working hours and the salon location', (tester) async {
    repo.salonValue = testSalon(ownerId: 'u1');
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))));

    await tester.tap(find.text('أوقات العمل'));
    await tester.pumpAndSettle();
    expect(find.text('حدد ساعات كل يوم وأيام العطلة'), findsOneWidget);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('موقع الصالون'));
    await tester.pumpAndSettle();
    expect(find.text('لم يُحدد الموقع بعد'), findsOneWidget);
  });

  testWidgets('logging out signs the user out', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))));

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pump();

    expect(auth.calls, ['signOut']);
  });

  testWidgets('shows a spinner while loading and a retry when loading fails', (tester) async {
    final completer = Completer<Barber?>();
    var loads = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        home: const AccountTab(),
        barbers: repo,
        auth: auth,
        barberLoader: () {
          loads++;
          if (loads == 1) return completer.future;
          return Future.value(barberEnding(now.add(const Duration(days: 12))));
        },
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.text('باقتك الحالية'), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('باقتك الحالية'), findsOneWidget);
  });

  testWidgets('scrolls on a small screen without overflowing', (tester) async {
    await pumpAccount(tester, barber: barberEnding(now.add(const Duration(days: 12))), size: const Size(320, 480));

    expect(find.text('تسجيل الخروج').hitTestable(), findsNothing, reason: 'below the fold at first');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج').hitTestable(), findsOneWidget);
  });
}
