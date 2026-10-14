import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

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

  Future<FakeBarberRepo> openSetup(WidgetTester tester, {FakePhotoService? photos, FakeAuthRepo? auth}) async {
    final repo = FakeBarberRepo();
    await pumpPhone(
      tester,
      testApp(
        home: PendingActivationScreen(barber: barber(BarberStatus.pending)),
        barbers: repo,
        photos: photos,
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('جهّز حسابك أثناء الانتظار'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('the setup sheet lists everything a pending barber can prepare', (tester) async {
    await openSetup(tester);

    expect(find.text('الخدمات والأسعار'), findsOneWidget);
    expect(find.text('أوقات العمل والاستراحات'), findsOneWidget);
    expect(find.text('موقع الصالون'), findsOneWidget);
    expect(find.text('صورتك'), findsOneWidget);
  });

  testWidgets('a pending barber can set their working hours and salon location while waiting', (tester) async {
    await openSetup(tester);

    await tester.tap(find.text('أوقات العمل والاستراحات'));
    await tester.pumpAndSettle();
    expect(find.text('حدد ساعات كل يوم وأيام العطلة'), findsOneWidget);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('جهّز حسابك أثناء الانتظار'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('موقع الصالون'));
    await tester.pumpAndSettle();
    expect(find.text('لم يُحدد الموقع بعد'), findsOneWidget);
  });

  testWidgets('a pending barber can upload their photo while waiting', (tester) async {
    final repo = await openSetup(
      tester,
      photos: FakePhotoService(testPhoto),
      auth: FakeAuthRepo(userId: 'u1'),
    );

    await tester.tap(find.text('صورتك'));
    await tester.pumpAndSettle();

    expect(repo.uploads.single, {'user': 'u1', 'barber': 'b1', 'bytes': testPhoto.bytes.length, 'type': 'image/png'});
    expect(find.text('تم تحديث الصورة'), findsOneWidget);
  });

  testWidgets('saving services from the setup goes back to the waiting screen', (tester) async {
    final repo = await openSetup(tester);
    await tester.tap(find.text('الخدمات والأسعار'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-haircut')));
    await tester.pump();
    await tester.enterText(
      find.descendant(of: find.byKey(const ValueKey('price-haircut')), matching: find.byType(TextField)),
      '25',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();

    expect(repo.savedServices, hasLength(1));
    expect(find.text('حسابك بانتظار التفعيل'), findsOneWidget);
  });

  testWidgets('a pending barber can prepare their services while waiting', (tester) async {
    await openSetup(tester);
    await tester.tap(find.text('الخدمات والأسعار'));
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
    expect(find.text('جهّز حسابك أثناء الانتظار'), findsNothing);
  });

  testWidgets('a suspended barber is told the account is paused, without review steps', (tester) async {
    await pumpFor(tester, barber(BarberStatus.suspended));

    expect(find.text('تم إيقاف حسابك مؤقتاً'), findsOneWidget);
    expect(find.text('جهّز حسابك أثناء الانتظار'), findsNothing);
    expect(find.text('مراجعة الإدارة'), findsNothing);
    expect(find.text('جارٍ الآن'), findsNothing);
    expect(find.text('تواصل مع الإدارة'), findsOneWidget);
  });

  testWidgets('a rejected barber is told the request was not approved', (tester) async {
    await pumpFor(tester, barber(BarberStatus.rejected));

    expect(find.text('لم تتم الموافقة على حسابك'), findsOneWidget);
    expect(find.text('جهّز حسابك أثناء الانتظار'), findsNothing);
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
