import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/app.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/home/home_shell.dart';
import 'package:barber_app/providers.dart';

import 'support/fakes.dart';

void main() {
  late FakeAuthRepo auth;

  Future<void> openApp(WidgetTester tester) async {
    await pumpPhone(
      tester,
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          currentBarberProvider.overrideWith((_) async => fakeBarber),
          todayBookingsProvider.overrideWith(() => FakeTodayBookings(const [])),
          todayClosureProvider.overrideWith((_) async => null),
          pushMessagingProvider.overrideWithValue(FakePushMessaging()),
          deviceTokenRepositoryProvider.overrideWithValue(FakeDeviceTokenRepository()),
        ],
        child: const BarberApp(),
      ),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '0912345678');
    await tester.enterText(fields.at(1), 'r999DtS7PB8q');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
  }

  testWidgets('a temporary password leads to the change screen before the bookings', (tester) async {
    auth = FakeAuthRepo(role: UserRole.barber, newUserId: 'u1')..signInWithTemporaryPassword = true;
    await openApp(tester);
    await signIn(tester);

    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
    expect(find.text('حجوزات اليوم'), findsNothing);
    expect(find.byType(HomeShell, skipOffstage: false), findsOneWidget);

    await tester.enterText(fieldLabelled('كلمة المرور الجديدة'), 'NewPass-2026');
    await tester.enterText(fieldLabelled('تأكيد كلمة المرور الجديدة'), 'NewPass-2026');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ والمتابعة'));

    expect(auth.calls.last, 'completePasswordChange:NewPass-2026');
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.text('حجوزات اليوم'), findsOneWidget);
  });

  testWidgets('signing out from the change screen goes back to login', (tester) async {
    auth = FakeAuthRepo(userId: 'u1', role: UserRole.barber)..mustChangePassword = true;
    await openApp(tester);
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);

    await tapVisible(tester, find.widgetWithText(TextButton, 'تسجيل الخروج'));

    expect(auth.calls, ['signOut']);
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
