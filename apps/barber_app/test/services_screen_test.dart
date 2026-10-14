import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/services/services_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;

  BarberService saved(String serviceId, double price, int minutes, {bool enabled = true}) =>
      BarberService(barberId: 'b1', serviceId: serviceId, price: price, durationMin: minutes, isEnabled: enabled);

  Future<void> pumpServices(WidgetTester tester, {bool showBack = false}) async {
    await pumpPhone(
      tester,
      testApp(
        home: ServicesScreen(showBack: showBack),
        barbers: repo,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String kind, String code) =>
      find.descendant(of: find.byKey(ValueKey('$kind-$code')), matching: find.byType(TextField));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
  }

  setUp(() => repo = FakeBarberRepo());

  testWidgets('the number keyboard closes on save and on a tap outside the boxes', (tester) async {
    repo.services = [saved('s1', 25, 30)];
    await pumpServices(tester);

    await tester.tap(field('price', 'haircut'));
    await tester.enterText(field('price', 'haircut'), '30');
    expect(tester.testTextInput.isVisible, isTrue);
    await save(tester);

    expect(tester.testTextInput.isVisible, isFalse);
    expect(repo.savedServices.single.single.price, 30);
    expect(find.text('تم حفظ الخدمات'), findsOneWidget);

    await tester.tap(field('duration', 'haircut'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('قص وتصفيف كلاسيكي أو حديث'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('lists every service with the saved price and duration', (tester) async {
    repo.services = [saved('s1', 25, 30), saved('s2', 15, 20, enabled: false)];
    await pumpServices(tester);

    expect(find.text('قص شعر'), findsOneWidget);
    expect(find.text('قص وتصفيف كلاسيكي أو حديث'), findsOneWidget);
    expect(tester.widget<TextField>(field('price', 'haircut')).controller!.text, '25');
    expect(tester.widget<TextField>(field('duration', 'haircut')).controller!.text, '30');
    expect(tester.widget<AppSwitch>(find.byKey(const ValueKey('switch-haircut'))).value, isTrue);
    expect(tester.widget<AppSwitch>(find.byKey(const ValueKey('switch-beard'))).value, isFalse);
    expect(
      tester.widget<TextField>(field('price', 'beard')).enabled,
      isFalse,
      reason: 'a disabled service cannot be edited',
    );
    expect(find.byType(VipBadge), findsOneWidget, reason: 'only the VIP service carries the pill');
    expect(
      tester.widget<TextField>(field('duration', 'vip')).controller!.text,
      '75',
      reason: 'defaults to the catalog duration',
    );
  });

  testWidgets('lists the services in catalog order', (tester) async {
    await pumpServices(tester);

    final tops = [
      for (final name in ['قص شعر', 'لحية', 'VIP']) tester.getTopLeft(find.text(name).first).dy,
    ];
    expect(tops, [...tops]..sort(), reason: 'haircut, beard, VIP from top to bottom');
  });

  testWidgets('enabling a service and saving writes its price and duration', (tester) async {
    repo.services = [saved('s1', 25, 30)];
    await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('switch-vip')));
    await tester.pump();
    await tester.enterText(field('price', 'vip'), '100');
    await tester.enterText(field('duration', 'vip'), '80');
    await save(tester);

    final payload = repo.savedServices.single;
    expect(payload.map((s) => s.serviceId), ['s1', 's3'], reason: 'a service that was never enabled is not written');
    final vip = payload.last;
    expect((vip.price, vip.durationMin, vip.isEnabled, vip.barberId), (100.0, 80, true, 'b1'));
    expect(find.text('تم حفظ الخدمات'), findsOneWidget);
  });

  testWidgets('Arabic-Indic digits are read as numbers', (tester) async {
    await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('switch-beard')));
    await tester.pump();
    await tester.enterText(field('price', 'beard'), '٢٥');
    await save(tester);

    expect(repo.savedServices.single.single.price, 25.0);
  });

  testWidgets('an enabled service without a price blocks saving', (tester) async {
    await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('switch-beard')));
    await tester.pump();
    await save(tester);

    expect(find.text('أدخل السعر والمدة للخدمات المفعّلة'), findsOneWidget);
    expect(repo.savedServices, isEmpty);
  });

  testWidgets('turning a saved service off keeps its price and writes is_enabled false', (tester) async {
    repo.services = [saved('s1', 25, 30)];
    await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('switch-haircut')));
    await tester.pump();
    await save(tester);

    final written = repo.savedServices.single.single;
    expect((written.isEnabled, written.price, written.durationMin), (false, 25.0, 30));
  });

  testWidgets('a failed load offers a retry', (tester) async {
    repo.failLoads = 1;
    await pumpServices(tester);

    expect(find.text(genericErrorMessage), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('قص شعر'), findsOneWidget);
  });

  testWidgets('a failed save shows the Arabic reason and keeps the form', (tester) async {
    repo.saveError = const PostgrestException(message: 'denied', code: '42501');
    await pumpServices(tester);

    await tester.tap(find.byKey(const ValueKey('switch-beard')));
    await tester.pump();
    await tester.enterText(field('price', 'beard'), '15');
    await save(tester);

    expect(find.text('ليست لديك صلاحية لهذا الإجراء'), findsOneWidget);
    expect(find.text('denied'), findsNothing);
    expect(tester.widget<TextField>(field('price', 'beard')).controller!.text, '15');
  });

  testWidgets('a back button shows only when the screen is opened from the pending screen', (tester) async {
    await pumpServices(tester);
    expect(find.byType(AppBackButton), findsNothing);

    await pumpServices(tester, showBack: true);
    expect(find.byType(AppBackButton), findsOneWidget);
  });
}
