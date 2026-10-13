import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/app.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openApp(WidgetTester tester, FakeAuthRepo auth) async {
    deps = TestDeps(auth: auth);
    addTearDown(deps.connectivity.close);
    await pumpPhone(tester, ProviderScope(retry: (_, _) => null, overrides: deps.overrides, child: const CustomerApp()));
  }

  Future<void> saveNewPassword(WidgetTester tester, String password) async {
    await tester.enterText(fieldLabelled('كلمة المرور الجديدة'), password);
    await tester.enterText(fieldLabelled('تأكيد كلمة المرور الجديدة'), password);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ والمتابعة'));
  }

  testWidgets('a session that must change its password opens on the change screen', (tester) async {
    await openApp(tester, FakeAuthRepo(userId: 'customer-1')..mustChangePassword = true);

    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
    expect(find.text('علي القماطي'), findsNothing);

    await saveNewPassword(tester, 'NewPass-2026');

    expect(deps.auth.calls, ['completePasswordChange:NewPass-2026']);
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.text('علي القماطي'), findsOneWidget);
  });

  testWidgets('signing in with a temporary password asks for a new one, then returns to the account tab', (tester) async {
    await openApp(tester, FakeAuthRepo()..signInWithTemporaryPassword = true);
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.enterText(fieldLabelled('رقم الهاتف'), '0911002030');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'r999DtS7PB8q');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await saveNewPassword(tester, 'NewPass-2026');

    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('خالد المقريف'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
  });

  testWidgets('a normal sign-in never shows the change screen', (tester) async {
    await openApp(tester, FakeAuthRepo());
    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.enterText(fieldLabelled('رقم الهاتف'), '0911002030');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.text('خالد المقريف'), findsOneWidget);
  });
}
