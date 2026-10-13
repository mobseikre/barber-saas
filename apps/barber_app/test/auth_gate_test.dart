import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/auth/auth_gate.dart';
import 'package:barber_app/features/auth/pending_activation_screen.dart';
import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/features/home/home_shell.dart';
import 'package:barber_app/providers.dart';

import 'support/fakes.dart';

void main() {
  Future<void> pumpGate(WidgetTester tester, UserRole role) async {
    await pumpPhone(
      tester,
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          currentBarberProvider.overrideWith((_) async => null),
          currentProfileProvider.overrideWith(
            (_) async =>
                Profile(id: 'u1', role: role, fullName: 'سالم', phone: '218911002030', createdAt: DateTime(2026)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: AppTheme.locale,
          supportedLocales: AppTheme.supportedLocales,
          localizationsDelegates: AppTheme.localizationsDelegates,
          home: const AuthGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a customer account is told this is not a barber account', (tester) async {
    await pumpGate(tester, UserRole.customer);

    expect(find.text('هذا ليس حساب حلاق'), findsOneWidget);
    expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('while the profile is loading the gate shows the splash, not the pending screen', (tester) async {
    await pumpPhone(
      tester,
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          currentBarberProvider.overrideWith((_) async => null),
          currentProfileProvider.overrideWith((_) => Completer<Profile?>().future),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const AuthGate()),
      ),
    );
    await tester.pump();

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
    expect(find.text('هذا ليس حساب حلاق'), findsNothing);
  });

  testWidgets('a barber without a barber row is asked to complete the registration', (tester) async {
    await pumpGate(tester, UserRole.barber);

    expect(find.text('أكمل تسجيلك'), findsOneWidget);
    expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
    expect(find.text('هذا ليس حساب حلاق'), findsNothing);
  });

  Barber barberWith(BarberStatus status, {Duration? endsIn}) => Barber(
    id: 'b1',
    profileId: 'u1',
    salonId: 's1',
    displayName: 'علي',
    status: status,
    subscriptionEndsAt: endsIn == null ? null : DateTime.now().add(endsIn),
    createdAt: DateTime(2026),
  );

  Future<void> pumpSignedIn(WidgetTester tester, Future<Barber?> Function() loader, {String? userId = 'u1'}) async {
    await pumpPhone(
      tester,
      testApp(
        home: const AuthGate(),
        barberLoader: loader,
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          todayBookingsProvider.overrideWith(() => FakeTodayBookings(const [])),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without a session the gate shows the login screen', (tester) async {
    await pumpSignedIn(tester, () async => null, userId: null);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('a bookable barber lands on the home shell', (tester) async {
    await pumpSignedIn(tester, () async => barberWith(BarberStatus.active, endsIn: const Duration(days: 10)));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('حجوزات اليوم'), findsOneWidget);
    expect(find.byType(PendingActivationScreen), findsNothing);
  });

  final notBookable = {
    'pending': barberWith(BarberStatus.pending),
    'lapsed': barberWith(BarberStatus.active, endsIn: const Duration(days: -1)),
    'suspended': barberWith(BarberStatus.suspended, endsIn: const Duration(days: 10)),
    'rejected': barberWith(BarberStatus.rejected),
  };
  for (final entry in notBookable.entries) {
    testWidgets('a ${entry.key} barber sees the pending activation screen', (tester) async {
      await pumpSignedIn(tester, () async => entry.value);

      expect(find.byType(PendingActivationScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
    });
  }

  testWidgets('a failed barber load offers a retry that loads again', (tester) async {
    var calls = 0;
    await pumpSignedIn(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return barberWith(BarberStatus.active, endsIn: const Duration(days: 10));
    });

    expect(find.text('تعذّر الاتصال بالخادم'), findsOneWidget);
    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.text('Exception: offline'), findsNothing);

    await tester.tap(find.text(RetryMessage.retryLabel));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(HomeShell), findsOneWidget);
  });
}
