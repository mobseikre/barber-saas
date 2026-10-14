import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/bookings/booking_card.dart';
import 'package:barber_app/features/bookings/subscription_banner.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/bookings/today_bookings_screen.dart';

import 'support/fakes.dart';

void main() {
  late FakeTodayBookings fake;

  List<Booking> sample() {
    final now = DateTime.now();
    return [
      booking(
        id: '1',
        name: 'سالم بن عامر',
        startsAt: now.subtract(const Duration(hours: 2)),
        status: BookingStatus.completed,
      ),
      booking(
        id: '2',
        name: 'عبدالله الزوي',
        startsAt: now.subtract(const Duration(hours: 1)),
        status: BookingStatus.noShow,
      ),
      booking(id: '3', name: 'أحمد الورفلي', startsAt: now.subtract(const Duration(minutes: 5)), phone: '218911002030'),
      booking(
        id: '4',
        name: 'يوسف المصراتي',
        startsAt: now.add(const Duration(hours: 2)),
        source: BookingSource.manual,
      ),
    ];
  }

  Future<void> pump(
    WidgetTester tester, {
    List<Booking>? bookings,
    List<Booking> remaining = const [],
    Object? manualError,
    Completer<void>? gate,
    DayClosure? closure,
    Barber? barber,
  }) async {
    fake = FakeTodayBookings(
      bookings ?? sample(),
      remainingAfterClose: remaining,
      manualError: manualError,
      gate: gate,
    );
    await pumpPhone(
      tester,
      testApp(
        home: const TodayBookingsScreen(),
        closure: closure,
        barber: barber,
        overrides: [
          todayBookingsProvider.overrideWith(() => fake),
          barberServicesProvider.overrideWith((_) async => [haircut]),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows stats, status badges, the next booking and action buttons', (tester) async {
    await pump(tester);

    expect(find.text('حجوزات اليوم'), findsOneWidget);
    expect(find.text('حجز اليوم'), findsOneWidget);
    expect(find.text('4'), findsOneWidget, reason: 'all four bookings count');
    expect(find.text('2'), findsOneWidget, reason: 'two remaining');
    expect(find.text('مكتمل'), findsNWidgets(2), reason: 'stat label and badge');
    expect(find.text('لم يحضر'), findsNWidgets(2), reason: 'one badge and the started booking\'s button');
    expect(find.text('التالي'), findsOneWidget);
    expect(find.text('يدوي'), findsOneWidget);
    expect(find.text('حضر'), findsOneWidget, reason: 'only the booking that has started can be marked');
    expect(find.text('إضافة حجز يدوي'), findsOneWidget);
  });

  testWidgets('the day picker shows the next 14 days with today selected', (tester) async {
    await pump(tester);

    final tiles = tester.widgetList<DayTile>(find.byType(DayTile)).toList();
    expect(tiles.first.label, 'اليوم');
    expect(tiles.first.selected, isTrue);
    expect(tiles[1].label, 'غداً');
    expect(tiles.where((t) => t.selected), hasLength(1));

    final last = AppTime.now().add(const Duration(days: AppConstants.bookingDays - 1));
    final lastTile = find.widgetWithText(DayTile, '${last.day}');
    final strip = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
    await tester.dragUntilVisible(lastTile, strip, const Offset(200, 0));
    expect(tester.widget<DayTile>(lastTile).label, ArabicFormat.weekday(last));
    final beyond = AppTime.now().add(const Duration(days: AppConstants.bookingDays));
    await tester.drag(strip, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(DayTile, '${beyond.day}'),
      findsNothing,
      reason: 'the strip ends after ${AppConstants.bookingDays} days',
    );
  });

  testWidgets('picking tomorrow shows its bookings, and a manual booking goes on that day', (tester) async {
    await pump(tester);
    final tomorrow = AppTime.startOfDay(AppTime.now().add(const Duration(days: 1)));

    await tester.tap(find.text('غداً'));
    await tester.pumpAndSettle();

    expect(find.text('حجوزات غداً'), findsOneWidget);
    expect(find.text(ArabicFormat.dayDate(tomorrow)), findsOneWidget);
    expect(find.text('التالي'), findsNothing, reason: 'the next booking is a today thing');
    expect(find.text('إغلاق بقية اليوم'), findsNothing);

    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();
    expect(find.textContaining(ArabicFormat.dayDate(tomorrow)), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'مراد الترهوني');
    await tester.tap(find.byType(DropdownButtonFormField<BarberService>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('قص شعر').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة الحجز'));
    await tester.pumpAndSettle();

    expect(fake.manualStarts.single, AppTime.at(tomorrow, 10, 0));
  });

  testWidgets('a wrong attended tap can be undone from the snackbar', (tester) async {
    await pump(tester);

    await tester.tap(find.text('حضر'));
    await tester.pumpAndSettle();
    expect(find.text('سُجّل حضور أحمد الورفلي'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['attended:3', 'undo:3']);
  });

  testWidgets('a no-show tap can be undone too', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(ActionButton, 'لم يحضر'));
    await tester.pumpAndSettle();
    expect(find.text('سُجّل عدم حضور أحمد الورفلي'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['no_show:3', 'undo:3']);
  });

  testWidgets('a closed later day says so without the reopen button', (tester) async {
    await pump(
      tester,
      closure: DayClosure(barberId: 'b1', date: DateTime(2026, 10, 20)),
    );
    await tester.tap(find.text('غداً'));
    await tester.pumpAndSettle();

    expect(find.text('هذا اليوم مغلق'), findsOneWidget);
    expect(find.text('إعادة الفتح'), findsNothing);
  });

  testWidgets('closing the rest of today is a visible button on today only', (tester) async {
    await pump(tester);

    expect(find.widgetWithText(ActionButton, 'إغلاق بقية اليوم').hitTestable(), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing, reason: 'no longer hidden behind the avatar');
  });

  testWidgets('with the keyboard up on a small phone the cancel sheet scrolls to its confirm button', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(ActionButton, 'إلغاء الحجز').first);
    await tester.tap(find.text('مريض'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextFormField, 'سيراها الزبون'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    expect(fake.calls, ['cancel:3:sick:']);
  });

  testWidgets('with the keyboard up the manual booking sheet still reaches its add button', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'مراد الترهوني');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<BarberService>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('قص شعر').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إضافة الحجز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة الحجز'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(fake.calls, ['manual:مراد الترهوني']);
  });

  testWidgets('a bookable barber sees no subscription banner', (tester) async {
    await pump(tester);

    expect(find.byType(SubscriptionBanner), findsNothing);
  });

  testWidgets('a lapsed barber works existing bookings, cannot add or close, and can reach the admin', (tester) async {
    final launcher = FakeLauncher(tester);
    await pump(
      tester,
      barber: Barber(
        id: 'b1',
        profileId: 'u1',
        salonId: 's1',
        displayName: 'علي القماطي',
        status: BarberStatus.active,
        subscriptionEndsAt: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime(2026),
      ),
    );

    expect(find.text('انتهى اشتراكك'), findsOneWidget);
    expect(find.text('إضافة حجز يدوي'), findsNothing);
    expect(find.text('إغلاق بقية اليوم'), findsNothing);

    await tester.tap(find.text('حضر'));
    await tester.pump();
    await tapVisible(tester, find.widgetWithText(ActionButton, 'إلغاء الحجز').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مريض'));
    await tester.pump();
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['attended:3', 'cancel:4:sick:']);

    await tester.tap(find.text('تواصل مع الإدارة'));
    await tester.pumpAndSettle();
    expect(launcher.urls.single.host, 'wa.me');
    expect(launcher.urls.single.queryParameters['text'], 'مرحباً، أريد تجديد اشتراكي');
  });

  testWidgets('a booking that has not started shows only the cancel button', (tester) async {
    await pump(tester);

    final future = find.ancestor(of: find.text('يوسف المصراتي'), matching: find.byType(BookingCard));
    expect(find.descendant(of: future, matching: find.byType(ActionButton)), findsOneWidget);
    expect(find.descendant(of: future, matching: find.text('حضر')), findsNothing);
    expect(find.descendant(of: future, matching: find.widgetWithText(ActionButton, 'إلغاء الحجز')), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(future).bottom,
      lessThan(tester.getRect(find.widgetWithText(AppButton, 'إضافة حجز يدوي')).top),
      reason: 'the last card scrolls clear of the add button',
    );
  });

  testWidgets('attended and no-show go through the notifier', (tester) async {
    await pump(tester);

    await tester.tap(find.text('حضر'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ActionButton, 'لم يحضر'));
    await tester.pump();

    expect(fake.calls, ['attended:3', 'no_show:3']);
  });

  testWidgets('a second tap while the first action runs is ignored', (tester) async {
    final gate = Completer<void>();
    await pump(tester, gate: gate);

    await tester.tap(find.text('حضر'));
    await tester.pump();
    await tester.tap(find.text('حضر'), warnIfMissed: false);
    await tester.tap(find.widgetWithText(ActionButton, 'لم يحضر'), warnIfMissed: false);
    await tester.pump();
    expect(fake.calls, ['attended:3']);
    expect(tester.widget<ActionButton>(find.widgetWithText(ActionButton, 'حضر')).onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ActionButton>(find.widgetWithText(ActionButton, 'حضر')).onPressed,
      isNotNull,
      reason: 'buttons come back once the action finishes',
    );
  });

  testWidgets('a closed day shows a banner with reopen and hides the close button', (tester) async {
    await pump(
      tester,
      closure: DayClosure(
        barberId: 'b1',
        date: DateTime(2026, 10, 11),
        fromTime: const TimeOfDay(hour: 20, minute: 15),
      ),
    );

    expect(find.text('اليوم مغلق'), findsOneWidget);
    expect(find.text('لا يمكن للزبائن الحجز بعد 8:15 م'), findsOneWidget);
    expect(find.text('إغلاق بقية اليوم'), findsNothing);

    await tester.tap(find.text('إعادة الفتح'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['reopen']);
  });

  testWidgets('cancelling requires a reason and passes it with the note', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(ActionButton, 'إلغاء الحجز').first);
    await tester.pumpAndSettle();
    expect(find.text('إلغاء الحجز'), findsWidgets);

    final confirm = find.widgetWithText(FilledButton, 'تأكيد الإلغاء');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'disabled until a reason is picked');

    await tester.tap(find.text('ظرف طارئ'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'سيراها الزبون'), 'سأعود غداً');
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(fake.calls, ['cancel:3:emergency:سأعود غداً']);
  });

  testWidgets('close rest of today lists the remaining bookings and lets the barber cancel each one', (tester) async {
    final remaining = sample().where((b) => b.isOpen).toList();
    await pump(tester, remaining: remaining);

    await tester.tap(find.text('إغلاق بقية اليوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق اليوم'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['close']);
    expect(find.text('تم إغلاق بقية اليوم'), findsOneWidget);
    expect(find.text('أحمد الورفلي'), findsWidgets);
    expect(find.widgetWithText(ActionButton, 'إلغاء الحجز'), findsNWidgets(4));
    expect(find.text('إغلاق'), findsOneWidget, reason: 'cannot finish with bookings left');

    await tester.tap(find.widgetWithText(ActionButton, 'إلغاء الحجز').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مريض'));
    await tester.pump();
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();

    expect(fake.calls.last, 'cancel:3:sick:');
    expect(find.widgetWithText(ActionButton, 'إلغاء الحجز'), findsNWidgets(3));
  });

  testWidgets('a rejected manual booking shows the reason inside the sheet', (tester) async {
    await pump(tester, manualError: const PostgrestException(message: 'booking_in_past'));

    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'مراد الترهوني');
    await tester.tap(find.byType(DropdownButtonFormField<BarberService>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('قص شعر').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة الحجز'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['manual:مراد الترهوني']);
    expect(find.text('الوقت المختار قد مضى'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('إضافة الحجز'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('with no enabled services the manual sheet explains why and cannot submit', (tester) async {
    fake = FakeTodayBookings(sample());
    await pumpPhone(
      tester,
      testApp(
        home: const TodayBookingsScreen(),
        overrides: [
          todayBookingsProvider.overrideWith(() => fake),
          barberServicesProvider.overrideWith((_) async => const <BarberService>[]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();

    expect(find.textContaining('فعّل خدماتك أولاً'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<BarberService>), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إضافة الحجز')).onPressed, isNull);
  });

  testWidgets('a failed service load offers a retry that loads again', (tester) async {
    var loads = 0;
    fake = FakeTodayBookings(sample());
    await pumpPhone(
      tester,
      testApp(
        home: const TodayBookingsScreen(),
        overrides: [
          todayBookingsProvider.overrideWith(() => fake),
          barberServicesProvider.overrideWith((_) async {
            loads++;
            if (loads == 1) throw const PostgrestException(message: 'boom', code: '500');
            return [haircut];
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();

    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.text('boom'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.byType(DropdownButtonFormField<BarberService>), findsOneWidget);
  });

  testWidgets('empty day', (tester) async {
    await pump(tester, bookings: const []);
    expect(find.text('لا توجد حجوزات اليوم'), findsOneWidget);
  });

  testWidgets('a failed first load can be retried with the button or by pulling down', (tester) async {
    final repo = _FlakyRepo();
    await pumpPhone(
      tester,
      testApp(home: const TodayBookingsScreen(), overrides: [bookingRepositoryProvider.overrideWithValue(repo)]),
    );
    await tester.pumpAndSettle();

    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.loads, 2, reason: 'pull to refresh reloads even when the error fits on screen');

    repo.fail = false;
    await tester.tap(find.text(RetryMessage.retryLabel));
    await tester.pumpAndSettle();
    expect(repo.loads, 3);
    expect(find.text('سالم'), findsOneWidget);
  });
}

class _FlakyRepo implements BookingRepository {
  var loads = 0;
  var fail = true;

  @override
  Future<List<Booking>> bookingsForDay({required String barberId, required DateTime day}) async {
    loads++;
    if (fail) throw Exception('offline');
    return [booking(id: '1', name: 'سالم', startsAt: AppTime.now().add(const Duration(hours: 1)))];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
