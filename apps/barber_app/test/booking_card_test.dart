import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/bookings/booking_card.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 9);
  setUp(() => AppTime.clock = () => now);
  tearDown(() => AppTime.clock = DateTime.now);

  late List<String> taps;

  Future<void> pumpCard(WidgetTester tester, Booking b, {bool isNext = false, bool busy = false}) async {
    taps = [];
    await pumpPhone(
      tester,
      testApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: BookingCard(
              booking: b,
              isNext: isNext,
              busy: busy,
              onAttended: () => taps.add('attended'),
              onNoShow: () => taps.add('no_show'),
              onCancel: () => taps.add('cancel'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tooltip(String message) => find.byWidgetPredicate((w) => w is Tooltip && w.message == message);

  testWidgets('a started app booking offers a call, attended, no-show and cancel', (tester) async {
    await pumpCard(
      tester,
      booking(id: '1', name: 'أحمد', startsAt: now.subtract(const Duration(minutes: 5)), phone: '218911002030'),
    );

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('قص شعر · 30 دقيقة'), findsOneWidget);
    expect(tooltip('اتصال'), findsOneWidget);
    expect(find.byType(StatusBadge), findsNothing);

    await tester.tap(find.text('حضر'));
    await tester.tap(find.text('لم يحضر'));
    await tester.tap(tooltip('إلغاء الحجز'));
    expect(taps, ['attended', 'no_show', 'cancel']);
  });

  testWidgets('before it starts only cancel is offered', (tester) async {
    await pumpCard(tester, booking(id: '1', name: 'أحمد', startsAt: now.add(const Duration(hours: 1))));

    expect(find.text('حضر'), findsNothing);
    expect(find.text('لم يحضر'), findsNothing);
    expect(tooltip('إلغاء الحجز'), findsOneWidget);
    expect(tooltip('اتصال'), findsNothing, reason: 'no phone on this booking');
  });

  testWidgets('a closed booking shows its status badge and no actions', (tester) async {
    await pumpCard(
      tester,
      booking(
        id: '1',
        name: 'سالم',
        startsAt: now.subtract(const Duration(hours: 2)),
        status: BookingStatus.completed,
        phone: '218911002030',
      ),
    );

    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('مكتمل'), findsOneWidget);
    expect(tooltip('اتصال'), findsNothing);
    expect(tooltip('إلغاء الحجز'), findsNothing);
    expect(find.text('حضر'), findsNothing);
  });

  testWidgets('a manual booking is labelled and has no call button', (tester) async {
    await pumpCard(
      tester,
      booking(id: '1', name: 'يوسف', startsAt: now.add(const Duration(hours: 1)), source: BookingSource.manual),
    );

    expect(find.text('يدوي'), findsOneWidget);
    expect(tooltip('اتصال'), findsNothing);
  });

  testWidgets('the next booking gets the red outline and the label', (tester) async {
    await pumpCard(tester, booking(id: '1', name: 'أحمد', startsAt: now.add(const Duration(hours: 1))), isNext: true);

    expect(find.text('التالي'), findsOneWidget);
    expect(tester.widget<AppCard>(find.byType(AppCard)).highlighted, isTrue);
  });

  testWidgets('while busy the actions are disabled', (tester) async {
    await pumpCard(
      tester,
      booking(id: '1', name: 'أحمد', startsAt: now.subtract(const Duration(minutes: 5))),
      busy: true,
    );

    await tester.tap(find.text('حضر'), warnIfMissed: false);
    await tester.tap(find.text('لم يحضر'), warnIfMissed: false);
    await tester.tap(tooltip('إلغاء الحجز'), warnIfMissed: false);
    expect(taps, isEmpty);
  });
}
