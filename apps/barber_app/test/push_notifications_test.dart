import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/auth/auth_gate.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';

import 'support/fakes.dart';

class _CountingBookings extends FakeTodayBookings {
  _CountingBookings(this.onBuild) : super(const []);

  final VoidCallback onBuild;

  @override
  Future<List<Booking>> build() {
    onBuild();
    return super.build();
  }
}

void main() {
  late FakePushMessaging push;
  late FakeAuthRepo auth;
  late FakeDeviceTokenRepository tokens;
  var bookingLoads = 0;

  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() {
    push = FakePushMessaging(platform: DevicePlatform.ios);
    auth = FakeAuthRepo(userId: 'u1', role: UserRole.barber);
    tokens = FakeDeviceTokenRepository(log: auth.calls);
    bookingLoads = 0;
  });

  Future<void> pumpGate(WidgetTester tester, {Barber? barber, String? userId = 'u1'}) => pumpPhone(
    tester,
    testApp(
      home: const AuthGate(),
      auth: auth,
      push: push,
      deviceTokens: tokens,
      barberLoader: () async => userId == null ? null : barber ?? fakeBarber,
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        todayBookingsProvider.overrideWith(() => _CountingBookings(() => bookingLoads++)),
      ],
    ),
  );

  testWidgets('a signed-in barber is asked once for notifications and the token is saved', (tester) async {
    await pumpGate(tester);

    expect(push.calls, ['requestPermission']);
    expect(tokens.saved, {'device-token-1': DevicePlatform.ios});
  });

  testWidgets('a pending barber registers too, so activation can reach them later', (tester) async {
    await pumpGate(
      tester,
      barber: Barber(
        id: 'b1',
        profileId: 'u1',
        salonId: 's1',
        displayName: 'علي',
        status: BarberStatus.pending,
        createdAt: DateTime(2026),
      ),
    );

    expect(tokens.saved.keys, ['device-token-1']);
  });

  testWidgets('nothing is asked before sign-in', (tester) async {
    await pumpGate(tester, userId: null);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(push.calls, isEmpty);
    expect(tokens.calls, isEmpty);
  });

  testWidgets('a refused permission saves nothing', (tester) async {
    push.granted = false;
    await pumpGate(tester);

    expect(push.calls, ['requestPermission']);
    expect(tokens.calls, isEmpty);
  });

  testWidgets('logging out deletes the token while the session still exists, then signs out', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('تسجيل الخروج'));

    expect(auth.calls, ['register:device-token-1', 'unregister:device-token-1', 'signOut']);
    expect(tokens.saved, isEmpty);
    expect(push.calls.last, 'deleteToken');
  });

  testWidgets('a notification while the app is open is shown and reloads today\'s bookings', (tester) async {
    await pumpGate(tester);
    final loadsBefore = bookingLoads;

    push.deliver(title: 'حجز جديد', body: 'خالد المقريف حجز قص شعر يوم الخميس، 15 أكتوبر الساعة 7:30 م');
    await tester.pumpAndSettle();

    expect(find.text('حجز جديد\nخالد المقريف حجز قص شعر يوم الخميس، 15 أكتوبر الساعة 7:30 م'), findsOneWidget);
    expect(bookingLoads, greaterThan(loadsBefore));
  });
}
