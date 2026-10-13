import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/auth/sign_up_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeAuthRepo auth;
  late FakeBarberRepo barbers;
  late FakePhotoService photos;

  Future<void> pumpSignUp(WidgetTester tester) async {
    auth = FakeAuthRepo(newUserId: 'u1');
    barbers = FakeBarberRepo();
    photos = FakePhotoService();
    await pumpPhone(tester, testApp(home: const Text('HOME'), barbers: barbers, auth: auth, photos: photos));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester, {String confirm = 'secret12'}) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'محمد السويحلي');
    await tester.enterText(fields.at(1), '0912345678');
    await tester.enterText(fields.at(2), 'secret12');
    await tester.enterText(fields.at(3), confirm);
    await submit(tester);
  }

  testWidgets('sign up has password confirmation, photo, salon and location sections', (tester) async {
    await pumpSignUp(tester);

    expect(find.text('انضم كحلّاق'), findsOneWidget);
    expect(find.textContaining('تأكيد كلمة المرور', findRichText: true), findsOneWidget);
    expect(find.text('صورتك أو صورة الصالون'), findsOneWidget);
    expect(find.text('الصالون الذي تعمل فيه', findRichText: true), findsOneWidget);
    expect(find.text('استخدم موقعي الحالي'), findsOneWidget);

    await fillAndSubmit(tester, confirm: 'secret13');

    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('a successful sign-up creates the account, registers the barber and leaves the form', (tester) async {
    await pumpSignUp(tester);

    await fillAndSubmit(tester);

    expect(auth.calls, ['signUp:218912345678:محمد السويحلي:barber']);
    expect(barbers.registrations.single['name'], 'محمد السويحلي');
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the location and photo chosen while signing up are sent with the registration', (tester) async {
    await pumpSignUp(tester);
    photos.photo = testPhoto;

    await tester.tap(find.text('صورتك أو صورة الصالون'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('استخدم موقعي الحالي'));
    await fillAndSubmit(tester);

    expect(barbers.registrations.single['lat'], 32.9);
    expect(barbers.registrations.single['lng'], 13.2);
    expect(barbers.uploads.single['type'], 'image/png');
  });

  testWidgets('a phone that is already registered shows one Arabic error', (tester) async {
    await pumpSignUp(tester);
    auth.signUpError = const AuthException('User already registered', statusCode: '422', code: 'user_already_exists');

    await fillAndSubmit(tester);

    expect(find.text('هذا الرقم مسجّل مسبقاً، سجّل الدخول بدلاً من ذلك'), findsOneWidget);
    expect(barbers.registrations, isEmpty);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('if registering the barber fails, retrying registers again without signing up twice', (tester) async {
    await pumpSignUp(tester);
    barbers.registerError = Exception('connection reset');

    await fillAndSubmit(tester);

    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing, reason: 'raw errors never reach the screen');

    barbers.registerError = null;
    await submit(tester);

    expect(auth.calls, [
      'signUp:218912345678:محمد السويحلي:barber',
    ], reason: 'the account already exists, so no second sign-up');
    expect(barbers.registrations, hasLength(2));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('the keyboard done key cannot submit a second time while signing up', (tester) async {
    await pumpSignUp(tester);
    final gate = Completer<void>();
    auth.signUpGate = gate;
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'محمد السويحلي');
    await tester.enterText(fields.at(1), '0912345678');
    await tester.enterText(fields.at(2), 'secret12');
    await tester.enterText(fields.at(3), 'secret12');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.showKeyboard(fields.at(3));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(auth.calls.where((c) => c.startsWith('signUp')), hasLength(1));
    expect(find.text('هذا الرقم مسجّل مسبقاً، سجّل الدخول بدلاً من ذلك'), findsNothing);
  });
}

Future<void> submit(WidgetTester tester) => tapVisible(tester, find.widgetWithText(FilledButton, 'إنشاء الحساب'));
