import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/home/home_shell.dart';
import 'package:customer_app/features/salon/salon_screen.dart';

import 'support/fakes.dart';

const _aliId = '30000000-0000-0000-0000-000000000001';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openApp(
    WidgetTester tester, {
    String? userId = 'customer-1',
    UserRole role = UserRole.customer,
    void Function(TestDeps deps)? before,
  }) async {
    deps = TestDeps(
      auth: FakeAuthRepo(userId: userId, role: role),
    );
    before?.call(deps);
    await pumpPhone(tester, deps.app(const HomeShell()));
  }

  group('push token', () {
    testWidgets('a signed-in customer is asked for notifications and the token is saved', (tester) async {
      await openApp(tester);

      expect(deps.push.calls, ['requestPermission']);
      expect(deps.deviceTokens.saved, {'device-token-1': DevicePlatform.android});
    });

    testWidgets('a visitor browsing without an account is not asked', (tester) async {
      await openApp(tester, userId: null);

      expect(deps.push.calls, isEmpty);
      expect(deps.deviceTokens.calls, isEmpty);
    });

    testWidgets('a barber account signed in to the customer app registers nothing', (tester) async {
      await openApp(tester, role: UserRole.barber);

      expect(deps.deviceTokens.calls, isEmpty);
    });

    testWidgets('logging out deletes the token before the session ends', (tester) async {
      await openApp(tester);
      deps.deviceTokens.calls.clear();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('تسجيل الخروج'));
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(deps.deviceTokens.calls, ['unregister:device-token-1']);
      expect(deps.auth.calls, ['signOut']);
      expect(deps.push.calls.last, 'deleteToken');
    });

    testWidgets('signing in from the account tab registers the device', (tester) async {
      await openApp(tester, userId: null);

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(AppButton, 'تسجيل الدخول'));
      await tester.enterText(fieldLabelled('رقم الهاتف'), '0911002030');
      await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
      await tapVisible(tester, find.widgetWithText(AppButton, 'تسجيل الدخول'));

      expect(deps.deviceTokens.saved.keys, ['device-token-1']);
    });

    testWidgets('a notification while the app is open is shown and reloads my bookings', (tester) async {
      await openApp(tester);
      final loads = deps.myBookings.loads;

      deps.push.deliver(title: 'تم إلغاء موعدك', body: 'ألغى علي القماطي موعدك. السبب: مريض');
      await tester.pumpAndSettle();

      expect(find.text('تم إلغاء موعدك\nألغى علي القماطي موعدك. السبب: مريض'), findsOneWidget);
      await tester.tap(find.text('حجوزاتي'));
      await tester.pumpAndSettle();
      expect(deps.myBookings.loads, greaterThan(loads));
    });
  });

  group('barber links', () {
    void withAli(TestDeps deps) {
      deps.directory.barbers = [listing(id: _aliId, name: 'علي القماطي', lat: 32.8752, lng: 13.1146)];
      deps.directory.team = [SalonBarber(id: _aliId, salonId: 'salon-1', displayName: 'علي القماطي', isBookable: true)];
    }

    Future<void> openWithAli(WidgetTester tester) async {
      await openApp(tester, userId: null);
      withAli(deps);
    }

    testWidgets('a cold start from a QR code link opens the salon page once', (tester) async {
      await openApp(tester, userId: null, before: (deps) => withAli(deps..launchLink = barberLink(_aliId)));

      deps.links.add(barberLink(_aliId));
      await tester.pumpAndSettle();

      expect(find.byType(SalonScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SalonScreen, skipOffstage: false), findsNothing);
      deps.links.add(barberLink(_aliId));
      await tester.pumpAndSettle();

      expect(
        find.byType(SalonScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'the same link opened later still works',
      );
    });

    testWidgets('a QR code link opens the barber in their salon page', (tester) async {
      await openWithAli(tester);

      deps.links.add(barberLink(_aliId));
      await tester.pumpAndSettle();

      final salon = tester.widget<SalonScreen>(find.byType(SalonScreen));
      expect((salon.salonId, salon.barberId), ('salon-1', _aliId));
      expect(find.text('صالون الأناقة'), findsOneWidget);
    });

    testWidgets('a link to a listed barber who cannot be booked opens the salon without choosing someone else', (
      tester,
    ) async {
      const lapsedId = '30000000-0000-0000-0000-0000000000aa';
      await openWithAli(tester);
      deps.directory.barbers = [
        ...deps.directory.barbers,
        listing(id: lapsedId, name: 'كمال المنتصر', bookable: false),
      ];
      deps.directory.team = [
        ...deps.directory.team,
        SalonBarber(id: lapsedId, salonId: 'salon-1', displayName: 'كمال المنتصر'),
      ];

      deps.links.add(barberLink(lapsedId));
      await tester.pumpAndSettle();

      expect(find.byType(SalonScreen), findsOneWidget);
      expect(find.text('كمال المنتصر غير متاح للحجز حالياً'), findsOneWidget);
      expect(find.text('مع علي'), findsNothing, reason: 'علي is not picked behind the customer\'s back');
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'احجز الآن')).onPressed, isNull);
    });

    testWidgets('a link to a barber who is not listed says so', (tester) async {
      await openWithAli(tester);

      deps.links.add(barberLink('30000000-0000-0000-0000-00000000dead'));
      await tester.pumpAndSettle();

      expect(find.byType(SalonScreen), findsNothing);
      expect(find.text('هذا الحلاق غير متاح حالياً'), findsOneWidget);
    });

    testWidgets('a failed lookup shows the error instead of a blank page', (tester) async {
      await openWithAli(tester);
      deps.directory.barbersError = Exception('offline');

      deps.links.add(barberLink(_aliId));
      await tester.pumpAndSettle();

      expect(find.byType(SalonScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('other links are ignored', (tester) async {
      await openWithAli(tester);

      deps.links.add(Uri.parse('https://${AppConstants.appLinkHost}/somewhere'));
      await tester.pumpAndSettle();

      expect(find.byType(SalonScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
