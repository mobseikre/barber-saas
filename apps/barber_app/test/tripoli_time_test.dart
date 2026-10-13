import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/bookings/today_bookings_screen.dart';
import 'package:barber_app/providers.dart';

import 'support/fakes.dart';

void main() {
  tearDown(() => AppTime.clock = DateTime.now);

  Future<FakeTodayBookings> openManualSheet(WidgetTester tester) async {
    final fake = FakeTodayBookings(const []);
    await pumpPhone(
      tester,
      testApp(
        home: const TodayBookingsScreen(),
        overrides: [
          todayBookingsProvider.overrideWith(() => fake),
          barberServicesProvider.overrideWith((_) async => [haircut]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة حجز يدوي'));
    await tester.pumpAndSettle();
    return fake;
  }

  Future<void> submitManual(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'مراد');
    await tester.tap(find.byType(DropdownButtonFormField<BarberService>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('قص شعر').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة الحجز'));
    await tester.pumpAndSettle();
  }

  testWidgets('the manual booking default and start are Tripoli wall time', (tester) async {
    AppTime.clock = () => DateTime.utc(2026, 10, 11, 8, 7);
    final fake = await openManualSheet(tester);

    expect(
      find.text('10:15 ص'),
      findsOneWidget,
      reason: '08:07 UTC is 10:07 in Tripoli, rounded up to the next quarter',
    );

    await submitManual(tester);
    expect(fake.manualStarts.single.toUtc(), DateTime.utc(2026, 10, 11, 8, 15));
  });

  testWidgets('near midnight the default start rolls over to the next Tripoli day', (tester) async {
    AppTime.clock = () => DateTime.utc(2026, 10, 11, 21, 50);
    final fake = await openManualSheet(tester);

    expect(find.text('12:00 ص'), findsOneWidget);

    await submitManual(tester);
    expect(fake.manualStarts.single.toUtc(), DateTime.utc(2026, 10, 11, 22));
  });

  testWidgets('near midnight a picked time stays on the default start day', (tester) async {
    AppTime.clock = () => DateTime.utc(2026, 10, 11, 21, 50);
    final fake = await openManualSheet(tester);

    await tester.tap(find.text('12:00 ص'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final inputs = find.descendant(of: find.byType(TimePickerDialog), matching: find.byType(TextField));
    await tester.enterText(inputs.at(0), '1');
    await tester.enterText(inputs.at(1), '15');
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();
    expect(find.text('1:15 ص'), findsOneWidget);

    await submitManual(tester);
    expect(
      fake.manualStarts.single.toUtc(),
      DateTime.utc(2026, 10, 11, 23, 15),
      reason: '01:15 on 12 October in Tripoli, not 01:15 on the 11th which has already passed',
    );
  });
  testWidgets('the header date is the Tripoli date even when UTC is still on the previous day', (tester) async {
    AppTime.clock = () => DateTime.utc(2026, 10, 10, 22, 30);
    await pumpPhone(
      tester,
      testApp(
        home: const TodayBookingsScreen(),
        overrides: [todayBookingsProvider.overrideWith(() => FakeTodayBookings(const []))],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الأحد، 11 أكتوبر'), findsOneWidget);
  });

  testWidgets('today\'s bookings reload for the new day at Tripoli midnight', (tester) async {
    var elapsed = Duration.zero;
    final start = DateTime.utc(2026, 10, 11, 21, 59, 30);
    AppTime.clock = () => start.add(elapsed);
    final repo = _DayRecordingRepo();
    final container = ProviderContainer(
      overrides: [
        currentBarberProvider.overrideWith((_) async => fakeBarber),
        bookingRepositoryProvider.overrideWithValue(repo),
      ],
    );

    container.listen(todayBookingsProvider, (_, _) {});
    await tester.pump();
    expect(repo.days, ['2026-10-11']);

    elapsed = const Duration(seconds: 31);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(repo.days, ['2026-10-11', '2026-10-12']);
    container.dispose();
  });
}

class _DayRecordingRepo implements BookingRepository {
  final days = <String>[];

  @override
  Future<List<Booking>> bookingsForDay({required String barberId, required DateTime day}) async {
    final d = AppTime.from(day);
    days.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
