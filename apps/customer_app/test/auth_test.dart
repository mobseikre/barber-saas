import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/home/home_shell.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openAccount(WidgetTester tester, {String? userId}) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: userId));
    await pumpPhone(tester, deps.app(const HomeShell()));
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
  }

  Future<void> signUp(
    WidgetTester tester, {
    String name = 'خالد المقريف',
    String phone = '0911002030',
    String password = 'password123',
  }) async {
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'إنشاء حساب'));
    await tester.enterText(fieldLabelled('الاسم'), name);
    await tester.enterText(fieldLabelled('رقم الهاتف'), phone);
    await tester.enterText(fieldLabelled('كلمة المرور'), password);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'إنشاء الحساب'));
  }

  testWidgets('sign-up asks for name, phone and a password of at least 8 characters', (tester) async {
    await openAccount(tester);

    await signUp(tester, phone: '12345', password: 'short12');

    expect(find.text('أهلاً بك في حلّاقي'), findsOneWidget);
    expect(find.text('رقم الهاتف غير صحيح، مثال: 91 234 5678'), findsOneWidget);
    expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);
    expect(find.text('8 أحرف على الأقل'), findsOneWidget);
    expect(deps.auth.calls, isEmpty);
  });

  testWidgets('a new customer signs up and comes back to the account tab signed in', (tester) async {
    await openAccount(tester);

    await signUp(tester);

    expect(deps.auth.calls, ['signUp:218911002030:خالد المقريف:customer']);
    expect(find.text('خالد المقريف'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('a taken phone number is explained on the form', (tester) async {
    await openAccount(tester);
    deps.auth.signUpError = const AuthException('exists', code: 'user_already_exists');

    await signUp(tester);

    expect(find.text('هذا الرقم مسجّل مسبقاً، سجّل الدخول بدلاً من ذلك'), findsOneWidget);
  });

  testWidgets('wrong credentials show one message under the password', (tester) async {
    await openAccount(tester);
    deps.auth.signInError = const AuthException('x', statusCode: '400', code: 'invalid_credentials');

    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.enterText(fieldLabelled('رقم الهاتف'), '0911002030');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'wrongpass');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(find.text('رقم الهاتف أو كلمة المرور غير صحيحة'), findsOneWidget);
  });

  testWidgets('the login and sign-up screens opened from a tab have a back button beside the logo', (tester) async {
    await openAccount(tester);

    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(
      tester.getCenter(find.byType(AppBackButton)).dx,
      greaterThan(195),
      reason: 'back sits on the start side in RTL',
    );
    expect(find.byType(AppLogo), findsOneWidget, reason: 'the logo stays in the header');
    expect(tester.getRect(find.byType(AppBackButton)).overlaps(tester.getRect(find.byType(AppLogo))), isFalse);
    expect(find.textContaining('*', findRichText: true), findsNothing, reason: 'login fields carry no required mark');

    await tapVisible(tester, find.byType(AppBackButton));
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'إنشاء حساب'));
    expect(find.byType(AppBackButton), findsOneWidget);
    final back = tester.getRect(find.byType(AppBackButton));
    final logo = tester.getRect(find.byType(AppLogo));
    expect(back.overlaps(logo), isFalse, reason: 'the back button sits beside the logo, not on it');
  });

  testWidgets('signing out returns the account tab to the sign-in prompt', (tester) async {
    await openAccount(tester, userId: 'customer-1');

    await tapVisible(tester, find.text('تسجيل الخروج'));

    expect(deps.auth.calls, ['signOut']);
    expect(find.text('سجّل الدخول لتحجز موعدك وتتابع حجوزاتك'), findsOneWidget);
  });
}
