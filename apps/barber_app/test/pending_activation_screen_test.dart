import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/auth/pending_activation_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  Barber barber(BarberStatus status, {DateTime? endsAt}) => Barber(
    id: 'b1',
    profileId: 'u1',
    salonId: 's1',
    displayName: 'علي',
    status: status,
    subscriptionEndsAt: endsAt,
    createdAt: DateTime(2026),
  );

  Future<void> pumpFor(WidgetTester tester, Barber b) async {
    await pumpPhone(tester, testApp(home: PendingActivationScreen(barber: b)));
    await tester.pumpAndSettle();
  }

  testWidgets('a pending barber sees the review steps with the current one marked', (tester) async {
    await pumpFor(tester, barber(BarberStatus.pending));

    expect(find.text('حسابك بانتظار التفعيل'), findsOneWidget);
    expect(find.text('تم إنشاء الحساب'), findsOneWidget);
    expect(find.text('مراجعة الإدارة'), findsOneWidget);
    expect(find.text('جارٍ الآن'), findsOneWidget);
    expect(find.text('تواصل مع الإدارة'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('a pending barber can prepare their services while waiting', (tester) async {
    final repo = FakeBarberRepo();
    await pumpPhone(
      tester,
      testApp(
        home: PendingActivationScreen(barber: barber(BarberStatus.pending)),
        barbers: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('جهّز خدماتك أثناء الانتظار'));
    await tester.pumpAndSettle();

    expect(find.text('خدماتي'), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.text('حسابك بانتظار التفعيل'), findsOneWidget);
  });

  testWidgets('an active barber whose subscription ended is asked to renew', (tester) async {
    await pumpFor(tester, barber(BarberStatus.active, endsAt: DateTime.now().subtract(const Duration(days: 1))));

    expect(find.text('انتهى اشتراكك'), findsOneWidget);
    expect(find.text('تجديد الاشتراك'), findsOneWidget);
    expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
    expect(find.text('جهّز خدماتك أثناء الانتظار'), findsNothing);
  });

  testWidgets('a suspended barber is told the account is paused, without review steps', (tester) async {
    await pumpFor(tester, barber(BarberStatus.suspended));

    expect(find.text('تم إيقاف حسابك مؤقتاً'), findsOneWidget);
    expect(find.text('جهّز خدماتك أثناء الانتظار'), findsNothing);
    expect(find.text('مراجعة الإدارة'), findsNothing);
    expect(find.text('جارٍ الآن'), findsNothing);
    expect(find.text('تواصل مع الإدارة'), findsOneWidget);
  });

  testWidgets('a rejected barber is told the request was not approved', (tester) async {
    await pumpFor(tester, barber(BarberStatus.rejected));

    expect(find.text('لم تتم الموافقة على حسابك'), findsOneWidget);
    expect(find.text('جهّز خدماتك أثناء الانتظار'), findsNothing);
    expect(find.text('مراجعة الإدارة'), findsNothing);
    expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
  });

  testWidgets('contact admin shows the support number when WhatsApp cannot open', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await pumpFor(tester, barber(BarberStatus.pending));

    await tapVisible(tester, find.text('تواصل مع الإدارة'));

    expect(find.text(supportFallbackMessage), findsOneWidget);
  });
}
