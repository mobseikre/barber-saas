import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/bookings/booking_card.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/bookings/today_bookings_screen.dart';
import 'package:barber_app/providers.dart';

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

  testWidgets('a booking that has not started shows only the cancel button', (tester) async {
    await pump(tester);

    final future = find.ancestor(of: find.text('يوسف المصراتي'), matching: find.byType(BookingCard));
    expect(find.descendant(of: future, matching: find.byType(ActionButton)), findsNothing);
    expect(find.descendant(of: future, matching: find.byTooltip('إلغاء الحجز')), findsOneWidget);

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

  testWidgets('a closed day shows a banner with reopen and hides the close menu', (tester) async {
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
    expect(tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>)).enabled, isFalse);

    await tester.tap(find.text('إعادة الفتح'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['reopen']);
  });

  testWidgets('cancelling requires a reason and passes it with the note', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('إلغاء الحجز').first);
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

    await tester.tap(find.byTooltip('المزيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق بقية اليوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق اليوم'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['close']);
    expect(find.text('تم إغلاق بقية اليوم'), findsOneWidget);
    expect(find.text('أحمد الورفلي'), findsWidgets);
    expect(find.widgetWithText(ActionButton, 'إلغاء الحجز'), findsNWidgets(2));
    expect(find.text('إغلاق'), findsOneWidget, reason: 'cannot finish with bookings left');

    await tester.tap(find.widgetWithText(ActionButton, 'إلغاء الحجز').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مريض'));
    await tester.pump();
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();

    expect(fake.calls.last, 'cancel:3:sick:');
    expect(find.widgetWithText(ActionButton, 'إلغاء الحجز'), findsOneWidget);
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
