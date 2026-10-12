import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/registration/complete_registration_screen.dart';
import 'package:barber_app/services/location_service.dart';
import 'package:barber_app/services/photo_service.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;
  late FakeAuthRepo auth;
  late FakeLocationService location;
  late FakePhotoService photos;

  final profile = Profile(
    id: 'u1',
    role: UserRole.barber,
    fullName: 'محمد السويحلي',
    phone: '218912345678',
    createdAt: DateTime(2026),
  );

  setUp(() {
    repo = FakeBarberRepo();
    auth = FakeAuthRepo();
    location = FakeLocationService();
    photos = FakePhotoService();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await pumpPhone(
      tester,
      testApp(
        home: CompleteRegistrationScreen(profile: profile),
        barbers: repo,
        auth: auth,
        location: location,
        photos: photos,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) => tapVisible(tester, find.widgetWithText(FilledButton, 'إكمال التسجيل'));

  Future<void> pickSalon(WidgetTester tester) async {
    repo.searchResults = [testSalon(lat: 32.8872, lng: 13.1913, address: 'شارع الجمهورية')];
    await tester.enterText(find.byType(TextField).at(1), 'الأناقة');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صالون الأناقة'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the missing salon and location, with the profile name filled in', (tester) async {
    await pumpScreen(tester);

    expect(find.text('أكمل تسجيلك'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'محمد السويحلي'), findsOneWidget);
    expect(find.text('الصالون الذي تعمل فيه', findRichText: true), findsOneWidget);
    expect(find.text('موقع صالونك', findRichText: true), findsOneWidget);
    expect(find.text('استخدم موقعي الحالي'), findsOneWidget);
    expect(find.text('صورتك أو صورة الصالون'), findsOneWidget);
  });

  testWidgets('a new salon is registered with the device location, address, city and area', (tester) async {
    await pumpScreen(tester);

    await tapVisible(tester, find.text('استخدم موقعي الحالي'));
    await tester.enterText(find.byType(TextField).at(2), 'شارع النصر');
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>).first);
    await tester.tap(find.text('طرابلس').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byType(DropdownButtonFormField<String>).last);
    await tester.tap(find.text('حي الأندلس').last);
    await tester.pumpAndSettle();
    await submit(tester);

    expect(repo.registrations.single, {
      'name': 'محمد السويحلي',
      'salon': null,
      'area': 'area-1',
      'address': 'شارع النصر',
      'lat': 32.9,
      'lng': 13.2,
    });
  });

  testWidgets('a new salon can be registered without a location', (tester) async {
    await pumpScreen(tester);

    await submit(tester);

    final sent = repo.registrations.single;
    expect((sent['salon'], sent['lat'], sent['lng'], sent['area'], sent['address']), (null, null, null, null, null));
  });

  testWidgets('a refused device location explains why and sends no location', (tester) async {
    location.result = const LocationResult.failed(LocationFailure.deniedForever);
    await pumpScreen(tester);

    await tapVisible(tester, find.text('استخدم موقعي الحالي'));
    expect(find.text(locationFailureMessage(LocationFailure.deniedForever)), findsOneWidget);
    await submit(tester);

    expect(repo.registrations.single['lat'], isNull);
  });

  testWidgets('joining an existing salon shows its location read-only and sends only the salon', (tester) async {
    await pumpScreen(tester);

    await pickSalon(tester);

    expect(find.text('موقع الصالون', findRichText: true), findsOneWidget);
    expect(find.text('شارع الجمهورية'), findsOneWidget);
    expect(find.text('يحدد مالك الصالون موقعه ولا يمكنك تعديله.'), findsOneWidget);
    expect(find.text('استخدم موقعي الحالي'), findsNothing);
    expect(find.text('موقع صالونك', findRichText: true), findsNothing);

    await submit(tester);
    expect(repo.registrations.single, {
      'name': 'محمد السويحلي',
      'salon': 'salon-1',
      'area': null,
      'address': null,
      'lat': null,
      'lng': null,
    });
  });

  testWidgets('the chosen photo is uploaded for the signed-in barber after registering', (tester) async {
    photos.photo = testPhoto;
    await pumpScreen(tester);

    await tester.tap(find.text('صورتك أو صورة الصالون'));
    await tester.pumpAndSettle();
    expect(find.text('اضغط لتغيير الصورة'), findsOneWidget);
    await submit(tester);

    expect(repo.uploads.single, {'user': 'u1', 'barber': 'b1', 'bytes': testPhoto.bytes.length, 'type': 'image/png'});
  });

  testWidgets('a failed photo upload does not undo the registration', (tester) async {
    photos.photo = testPhoto;
    repo.uploadError = Exception('storage down');
    await pumpScreen(tester);

    await tester.tap(find.text('صورتك أو صورة الصالون'));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(repo.registrations, hasLength(1));
    expect(find.text('تم إكمال التسجيل، لكن تعذّر رفع الصورة'), findsOneWidget);
  });

  testWidgets('a registration error is shown in Arabic and the form stays', (tester) async {
    repo.registerError = const PostgrestException(message: 'salon_not_found', code: 'P0001');
    await pumpScreen(tester);

    await submit(tester);

    expect(find.text('الصالون المختار غير موجود'), findsOneWidget);
    expect(find.text('salon_not_found'), findsNothing);
    expect(find.text('أكمل تسجيلك'), findsOneWidget);
  });

  testWidgets('the name is required', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'محمد السويحلي'), ' ');
    await submit(tester);

    expect(find.text('أدخل اسمك الكامل'), findsOneWidget);
    expect(repo.registrations, isEmpty);
  });

  testWidgets('the barber can sign out instead of completing', (tester) async {
    await pumpScreen(tester);

    final logout = find.widgetWithText(TextButton, 'تسجيل الخروج');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pump();

    expect(auth.calls, ['signOut']);
  });

  testWidgets('the photo circle sits at the start of its row with the design size', (tester) async {
    await pumpScreen(tester);

    final circle = find.byKey(const ValueKey('photo-circle'));
    expect(tester.getSize(circle), const Size(AppSizes.photoPicker, AppSizes.photoPicker));
    expect(
      tester.getCenter(circle).dx,
      greaterThan(tester.getCenter(find.text('صورتك أو صورة الصالون')).dx),
      reason: 'start is the right side in RTL',
    );
  });

  testWidgets('a photo picked after the screen closed is dropped without errors', (tester) async {
    final gate = Completer<PickedPhoto?>();
    photos.pending = gate;
    await pumpScreen(tester);

    await tester.tap(find.text('صورتك أو صورة الصالون'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete(testPhoto);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
