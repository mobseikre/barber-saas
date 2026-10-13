import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/location/location_map.dart';
import 'package:barber_app/features/location/location_screen.dart';
import 'package:barber_app/services/location_service.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;
  late FakeLocationService location;

  Salon ownedSalon() =>
      testSalon(ownerId: 'u1', lat: 32.8872, lng: 13.1913, areaId: 'area-1', address: 'شارع الجمهورية');

  Future<void> pumpLocation(WidgetTester tester) async {
    await pumpPhone(tester, testApp(home: const LocationScreen(), barbers: repo, location: location));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'حفظ الموقع');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeBarberRepo();
    location = FakeLocationService(barberSpot);
  });

  testWidgets('the owner sees the saved location and can save a change', (tester) async {
    repo.salonValue = ownedSalon();
    await pumpLocation(tester);

    expect(find.text('موقع الصالون'), findsOneWidget);
    expect(find.text('تم تحديد الموقع'), findsOneWidget);
    expect(find.text('حرّك الخريطة لتحديد مكان الصالون'), findsNothing);
    expect(find.text('شارع الجمهورية'), findsOneWidget);
    expect(find.text('طرابلس'), findsOneWidget);
    expect(find.text('حي الأندلس'), findsOneWidget);
    expect(find.text('استخدم موقعي الحالي'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'شارع النصر');
    await save(tester);

    expect(repo.updatedSalons.single, {
      'salon': 'salon-1',
      'area': 'area-1',
      'address': 'شارع النصر',
      'lat': 32.8872,
      'lng': 13.1913,
    });
    expect(find.text('تم حفظ الموقع'), findsOneWidget);
  });

  testWidgets('a barber who joined the salon only sees its location', (tester) async {
    repo.salonValue = testSalon(
      ownerId: 'someone-else',
      lat: 32.8872,
      lng: 13.1913,
      areaId: 'area-1',
      address: 'شارع الجمهورية',
    );
    await pumpLocation(tester);

    expect(find.text('تم تحديد الموقع'), findsOneWidget);
    expect(find.text('موقع صالونك يحدده مالك الصالون ولا يمكنك تعديله'), findsOneWidget);
    expect(find.text('شارع الجمهورية، حي الأندلس، طرابلس'), findsOneWidget);
    expect(find.text('حفظ الموقع'), findsNothing);
    expect(find.text('استخدم موقعي الحالي'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('the location must be set before saving, and the device location sets it', (tester) async {
    repo.salonValue = testSalon(ownerId: 'u1');
    await pumpLocation(tester);
    expect(find.text('لم يُحدد الموقع بعد'), findsOneWidget);
    expect(find.text('حرّك الخريطة لتحديد مكان الصالون'), findsOneWidget);

    await save(tester);
    expect(find.text('حدد موقع الصالون على الخريطة أولاً'), findsOneWidget);
    expect(repo.updatedSalons, isEmpty);

    await tester.tap(find.text('استخدم موقعي الحالي'));
    await tester.pumpAndSettle();
    expect(location.calls, 1);
    expect(find.text('تم تحديد الموقع'), findsOneWidget);
    expect(find.text('حرّك الخريطة لتحديد مكان الصالون'), findsNothing);

    await save(tester);
    expect(repo.updatedSalons.single['lat'], 32.9);
    expect(repo.updatedSalons.single['lng'], 13.2);
    expect(repo.updatedSalons.single['address'], isNull, reason: 'an empty address is not written');
  });

  testWidgets('moving the map under the pin updates the location', (tester) async {
    repo.salonValue = ownedSalon();
    await pumpLocation(tester);

    await tester.drag(find.byType(LocationMap), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await save(tester);

    expect(repo.updatedSalons.single['lng'], isNot(13.1913), reason: 'the longitude follows the pin');
    expect(repo.updatedSalons.single['lat'], closeTo(32.8872, 0.001));
  });

  testWidgets('a refused device location explains why and leaves the location unset', (tester) async {
    repo.salonValue = testSalon(ownerId: 'u1');
    location.result = const LocationResult.failed(LocationFailure.denied);
    await pumpLocation(tester);

    await tester.tap(find.text('استخدم موقعي الحالي'));
    await tester.pumpAndSettle();

    expect(find.text(locationFailureMessage(LocationFailure.denied)), findsOneWidget);
    expect(find.text('لم يُحدد الموقع بعد'), findsOneWidget);
  });

  testWidgets('a salon load error offers a retry', (tester) async {
    repo.salonValue = ownedSalon();
    repo.failLoads = 1;
    await pumpLocation(tester);
    expect(find.text(genericErrorMessage), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();

    expect(find.text('تم تحديد الموقع'), findsOneWidget);
  });

  testWidgets('a refused save shows the Arabic reason', (tester) async {
    repo.salonValue = ownedSalon();
    repo.saveError = const PostgrestException(message: 'not_salon_owner', code: '42501');
    await pumpLocation(tester);

    await save(tester);

    expect(find.text('ليست لديك صلاحية لهذا الإجراء'), findsOneWidget);
  });
}
