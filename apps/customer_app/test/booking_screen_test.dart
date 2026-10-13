import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/booking/booking_confirmed_screen.dart';
import 'package:customer_app/features/booking/booking_screen.dart';
import 'package:customer_app/providers.dart';
import 'package:customer_app/widgets/app_chip.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openBooking(WidgetTester tester, {bool signedIn = true}) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: signedIn ? 'customer-1' : null));
    await pumpPhone(tester, deps.app(const Text('HOME')));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => BookingScreen(barber: ali)));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, {String service = 'قص شعر', String time = '11:30 ص'}) async {
    await tapVisible(tester, find.textContaining(service));
    await tapVisible(tester, find.text(time));
  }

  Future<void> confirm(WidgetTester tester) => tapVisible(tester, find.widgetWithText(FilledButton, 'تأكيد الحجز'));

  testWidgets('today is preselected, slots load for the chosen service and the summary fills in', (tester) async {
    await openBooking(tester);

    expect(find.text('اختر الخدمة لعرض المواعيد المتاحة'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'تأكيد الحجز')).onPressed, isNull);

    await choose(tester);

    expect(deps.bookings.slotRequests, ['2026-10-12:30']);
    expect(find.text('علي · قص شعر · الاثنين، 12 أكتوبر · 11:30 ص'), findsOneWidget);
    expect(find.text('25 د.ل'), findsWidgets);
  });

  testWidgets('a day off cannot be picked', (tester) async {
    await openBooking(tester);
    await tapVisible(tester, find.textContaining('قص شعر'));
    deps.bookings.slotRequests.clear();

    await tapVisible(tester, find.text('الجمعة'));

    expect(deps.bookings.slotRequests, isEmpty, reason: 'Friday is the day off in weekHours');
  });

  testWidgets('a visitor signs in when confirming and the booking continues where they left it', (tester) async {
    await openBooking(tester, signedIn: false);
    await choose(tester);

    await confirm(tester);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(deps.bookings.created, isEmpty);

    await tester.enterText(fieldLabelled('رقم الهاتف'), '0911002030');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(deps.auth.calls, ['signIn:218911002030']);
    expect(deps.bookings.created.single.serviceId, 'haircut');
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
    expect(find.text('تم تأكيد حجزك'), findsOneWidget);
  });

  testWidgets('a visitor who signs up at confirm gets the same booking confirmed', (tester) async {
    await openBooking(tester, signedIn: false);
    await choose(tester);
    await confirm(tester);

    await tapVisible(tester, find.text('إنشاء حساب'));
    await tester.enterText(fieldLabelled('الاسم'), 'زائر جديد');
    await tester.enterText(fieldLabelled('رقم الهاتف'), '0917000001');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'إنشاء الحساب'));

    expect(deps.auth.calls, ['signUp:218917000001:زائر جديد:customer']);
    final booked = deps.bookings.created.single;
    expect((booked.barberId, booked.serviceId), ('ali', 'haircut'));
    expect(AppTime.from(booked.startsAt), AppTime.at(testNow, 11, 30));
    expect(find.text('تم تأكيد حجزك'), findsOneWidget);
    expect(find.text('11:30 ص'), findsOneWidget);
  });

  testWidgets('a confirmed booking reloads my bookings', (tester) async {
    await openBooking(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(BookingScreen)));
    await container.read(myBookingsProvider.future);
    expect(deps.myBookings.loads, 1);

    await choose(tester);
    await confirm(tester);
    await container.read(myBookingsProvider.future);

    expect(deps.myBookings.loads, 2);
  });

  testWidgets('a barber account is refused at login and nothing is booked', (tester) async {
    await openBooking(tester, signedIn: false);
    deps.auth.role = UserRole.barber;
    await choose(tester);
    await confirm(tester);

    await tester.enterText(fieldLabelled('رقم الهاتف'), '0912345678');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(find.text('هذا الرقم مسجّل كحلاق، استخدم تطبيق الحلاقين'), findsOneWidget);
    expect(deps.auth.calls, ['signIn:218912345678', 'signOut']);
    expect(deps.bookings.created, isEmpty);
  });

  testWidgets('retrying after a network error sends the same idempotency key', (tester) async {
    await openBooking(tester);
    deps.bookings.errors.add(Exception('SocketException: Connection reset'));
    await choose(tester);

    await confirm(tester);
    expect(find.text(genericErrorMessage), findsOneWidget);

    await confirm(tester);

    final keys = [for (final c in deps.bookings.created) c.key];
    expect(keys, hasLength(2));
    expect(keys.toSet(), hasLength(1));
    expect(find.byType(BookingConfirmedScreen), findsOneWidget);
  });

  testWidgets('choosing another time after an error uses a new key', (tester) async {
    await openBooking(tester);
    deps.bookings.errors.add(Exception('timeout'));
    await choose(tester);
    await confirm(tester);

    await tapVisible(tester, find.text('12:30 م'));
    await confirm(tester);

    expect({for (final c in deps.bookings.created) c.key}, hasLength(2));
  });

  testWidgets('a taken slot is explained, cleared and the times reloaded', (tester) async {
    await openBooking(tester);
    deps.bookings.errors.add(rpcError('slot_not_available'));
    await choose(tester);
    deps.bookings.slotRequests.clear();

    await confirm(tester);

    expect(find.text('هذا الموعد لم يعد متاحاً، اختر وقتاً آخر'), findsOneWidget);
    expect(deps.bookings.slotRequests, ['2026-10-12:30']);
    expect(find.text('اختر الخدمة والوقت'), findsOneWidget);
    expect(find.byType(BookingConfirmedScreen), findsNothing);
  });

  for (final (code, message) in [
    ('booking_limit_reached', 'وصلت إلى الحد الأقصى للحجوزات القادمة (2)، ألغِ حجزاً لتحجز موعداً جديداً'),
    ('customer_blocked', 'تم إيقاف الحجز لحسابك بعد 3 مرات عدم حضور. تواصل مع الدعم'),
    ('idempotency_key_reused', 'تغيّر اختيارك أثناء إرسال الحجز، أكّد الحجز مرة أخرى'),
    ('barber_not_bookable', 'هذا الحلاق غير متاح للحجز حالياً'),
  ]) {
    testWidgets('$code is shown in Arabic and keeps the choice', (tester) async {
      await openBooking(tester);
      deps.bookings.errors.add(rpcError(code));
      await choose(tester);

      await confirm(tester);

      expect(find.text(message), findsOneWidget);
      expect(find.text('علي · قص شعر · الاثنين، 12 أكتوبر · 11:30 ص'), findsOneWidget);
    });
  }

  testWidgets('a blocked customer is offered the support chat', (tester) async {
    final launcher = FakeLauncher(tester);
    await openBooking(tester);
    deps.bookings.errors.add(rpcError('customer_blocked'));
    await choose(tester);
    expect(find.text('تواصل مع الدعم'), findsNothing);

    await confirm(tester);
    await tapVisible(tester, find.text('تواصل مع الدعم'));

    expect(launcher.urls.single.host, 'wa.me');
    expect(launcher.urls.single.path, '/${AppConstants.supportWhatsAppNumber}');
  });

  testWidgets('the steps, the chosen day, time and service follow the design colours', (tester) async {
    await openBooking(tester);
    await choose(tester);

    Color? fill(Finder f) => tester.widget<Material>(find.ancestor(of: f, matching: find.byType(Material)).first).color;
    Color? ink(Finder f) => tester.widget<Text>(f).style?.color;
    final today = find.ancestor(of: find.text('12'), matching: find.byType(Column)).first;
    Finder price(String p) => find.descendant(of: find.byType(AppChip), matching: find.text(p));

    expect(fill(find.text('11:30 ص')), AppColors.red400);
    expect(ink(find.text('11:30 ص')), AppColors.text);
    expect(fill(find.text('12')), AppColors.blue900);
    expect(ink(find.descendant(of: today, matching: find.text('اليوم'))), AppColors.red300);
    expect(ink(price('25 د.ل')), AppColors.red300);
    expect(ink(price('15 د.ل')), AppColors.text3);
    final bars = tester
        .widgetList<Container>(
          find.byWidgetPredicate((w) => w is Container && w.constraints?.maxHeight == AppSpacing.xs),
        )
        .map((c) => (c.decoration as BoxDecoration).color)
        .toList();
    expect(bars, [AppColors.blue900, AppColors.blue900, AppColors.blue900, AppColors.blue900, AppColors.red400]);
  });

  testWidgets('a failed load of the services offers a retry', (tester) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: 'customer-1'));
    deps.barbers.servicesError = Exception('offline');
    await pumpPhone(tester, deps.app(BookingScreen(barber: ali)));
    expect(find.text(genericErrorMessage), findsOneWidget);

    deps.barbers.servicesError = null;
    await tapVisible(tester, find.text('إعادة المحاولة'));

    expect(find.textContaining('قص شعر'), findsOneWidget);
  });

  testWidgets('after closing time the first day offered is tomorrow, not today', (tester) async {
    AppTime.clock = () => DateTime.utc(2026, 10, 12, 20, 30);
    await openBooking(tester);

    await tapVisible(tester, find.textContaining('قص شعر'));

    expect(deps.bookings.slotRequests, ['2026-10-13:30']);
  });

  testWidgets('the cancellation hint uses the Arabic dual', (tester) async {
    await openBooking(tester);

    expect(find.textContaining('حتى ساعتين قبل الموعد'), findsOneWidget);
  });

  testWidgets('a day without free times says so', (tester) async {
    await openBooking(tester);
    deps.bookings.slots = (_, _) => const [];

    await tapVisible(tester, find.textContaining('قص شعر'));

    expect(find.text('لا توجد مواعيد متاحة في هذا اليوم، جرّب يوماً آخر'), findsOneWidget);
  });
}
