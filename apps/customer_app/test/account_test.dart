import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/account/account_tab.dart';

import 'support/fakes.dart';

void main() {
  late TestDeps deps;

  Future<void> openAccount(WidgetTester tester, {bool signedIn = true}) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: signedIn ? 'customer-1' : null));
    await pumpPhone(tester, deps.app(const Scaffold(body: AccountTab())));
  }

  Future<void> openChangePassword(WidgetTester tester) async {
    await openAccount(tester);
    await tapVisible(tester, find.text('تغيير كلمة المرور'));
  }

  Future<void> fill(
    WidgetTester tester, {
    String current = 'oldpassword',
    String next = 'newpassword',
    String? confirm,
  }) async {
    await tester.enterText(fieldLabelled('كلمة المرور الحالية'), current);
    await tester.enterText(fieldLabelled('كلمة المرور الجديدة'), next);
    await tester.enterText(fieldLabelled('تأكيد كلمة المرور الجديدة'), confirm ?? next);
  }

  Future<void> save(WidgetTester tester) => tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ كلمة المرور'));

  testWidgets('a signed-in customer sees their name, phone and the account actions', (tester) async {
    await openAccount(tester);

    expect(find.text('خالد المقريف'), findsOneWidget);
    expect(find.text(formatLibyanPhone('218911002030')), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('تواصل مع الدعم'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('تواصل مع الدعم opens WhatsApp to the support number', (tester) async {
    final launcher = FakeLauncher(tester);
    await openAccount(tester);

    await tapVisible(tester, find.text('تواصل مع الدعم'));

    expect(launcher.urls, [Uri.parse('https://wa.me/${AppConstants.supportWhatsAppNumber}')]);
  });

  testWidgets('without WhatsApp the support number is shown instead', (tester) async {
    FakeLauncher(tester, opens: false);
    await openAccount(tester);

    await tapVisible(tester, find.text('تواصل مع الدعم'));

    expect(find.text(supportFallbackMessage), findsOneWidget);
  });

  testWidgets('a visitor is offered to sign in instead', (tester) async {
    await openAccount(tester, signedIn: false);

    expect(find.text('تغيير كلمة المرور'), findsNothing);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });

  testWidgets('logging out signs the customer out', (tester) async {
    await openAccount(tester);

    await tapVisible(tester, find.text('تسجيل الخروج'));

    expect(deps.auth.calls, ['signOut']);
    expect(find.text('تسجيل الخروج'), findsNothing);
  });

  testWidgets('a new password is saved with the current one and the screen closes', (tester) async {
    await openChangePassword(tester);

    await fill(tester);
    await save(tester);

    expect(deps.auth.calls, ['changePassword:oldpassword:newpassword']);
    expect(find.text('تم تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('حفظ كلمة المرور'), findsNothing);
  });

  testWidgets('the fields are checked before anything is sent', (tester) async {
    await openChangePassword(tester);

    await save(tester);
    expect(find.text('أدخل كلمة المرور الحالية'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);

    await fill(tester, next: 'short', confirm: 'short');
    await save(tester);
    expect(find.text('كلمة المرور يجب أن تكون ${AppConstants.passwordMinLength} أحرف على الأقل'), findsOneWidget);

    await fill(tester, confirm: 'different1');
    await save(tester);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(deps.auth.calls, isEmpty);
  });

  testWidgets('a wrong current password is reported and the screen stays', (tester) async {
    await openChangePassword(tester);
    deps.auth.changePasswordError = const AuthException('bad', code: 'invalid_credentials');

    await fill(tester);
    await save(tester);

    expect(find.text('كلمة المرور الحالية غير صحيحة'), findsOneWidget);
    expect(find.text('حفظ كلمة المرور'), findsOneWidget);
  });

  testWidgets('reusing the current password is explained', (tester) async {
    await openChangePassword(tester);
    deps.auth.changePasswordError = const AuthException('same', code: 'same_password');

    await fill(tester, next: 'oldpassword');
    await save(tester);

    expect(find.text('كلمة المرور الجديدة يجب أن تختلف عن الحالية'), findsOneWidget);
  });
}
