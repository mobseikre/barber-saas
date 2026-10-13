import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  late List<String> calls;
  late Object? signInError;
  Completer<void>? gate;

  Future<void> pumpLogin(WidgetTester tester) async {
    calls = [];
    signInError = null;
    gate = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppTheme.locale,
        supportedLocales: AppTheme.supportedLocales,
        localizationsDelegates: AppTheme.localizationsDelegates,
        home: LoginScreen(
          onSignIn: ({required phone, required password}) async {
            calls.add('signIn:$phone');
            await gate?.future;
            if (signInError != null) throw signInError!;
          },
          signUpRoute: () => MaterialPageRoute<void>(builder: (_) => const Text('SIGN UP')),
        ),
      ),
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();
  }

  testWidgets('validates before calling the backend', (tester) async {
    await pumpLogin(tester);

    expect(find.text('تسجيل الدخول'), findsNWidgets(2), reason: 'title and button');
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    expect(find.text('+218'), findsOneWidget);

    await submit(tester);
    expect(find.text('أدخل رقم الهاتف'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('signs in with the normalised phone', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '091 234 5678');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await submit(tester);

    expect(calls, ['signIn:218912345678']);
  });

  testWidgets('shows one wrong-credentials error and clears it on the next submit', (tester) async {
    await pumpLogin(tester);
    signInError = const AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');

    await tester.enterText(find.byType(TextFormField).at(0), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await submit(tester);
    expect(find.text('رقم الهاتف أو كلمة المرور غير صحيحة'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '12345');
    await submit(tester);
    expect(find.textContaining('رقم الهاتف غير صحيح'), findsOneWidget);
    expect(find.text('رقم الهاتف أو كلمة المرور غير صحيحة'), findsNothing);
  });

  testWidgets('another 400 from auth is not reported as a wrong password', (tester) async {
    await pumpLogin(tester);
    signInError = const AuthException('Email not confirmed', statusCode: '400', code: 'email_not_confirmed');

    await tester.enterText(find.byType(TextFormField).at(0), '0912345678');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await submit(tester);

    expect(find.text('رقم الهاتف أو كلمة المرور غير صحيحة'), findsNothing);
    expect(find.text(genericErrorMessage), findsOneWidget);
  });

  testWidgets('opens the sign-up route the app passes in', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN UP'), findsOneWidget);
  });

  testWidgets('a second done key while signing in is ignored', (tester) async {
    await pumpLogin(tester);
    gate = Completer<void>();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '0912345678');
    await tester.enterText(fields.at(1), 'secret12');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.showKeyboard(fields.at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    gate!.complete();
    await tester.pumpAndSettle();

    expect(calls, ['signIn:218912345678']);
  });

  testWidgets('forgot password shows the support number when WhatsApp cannot open', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await pumpLogin(tester);

    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pumpAndSettle();

    expect(find.text(supportFallbackMessage), findsOneWidget);
  });

  testWidgets('the fields carry no required mark', (tester) async {
    await pumpLogin(tester);

    expect(find.textContaining('*', findRichText: true), findsNothing);
  });

  testWidgets('opened over another screen it shows the back button beside the logo', (tester) async {
    await pumpLogin(tester);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(AppBackButton), findsNothing, reason: 'the first screen has nothing to go back to');

    Navigator.of(tester.element(find.byType(LoginScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          onSignIn: ({required phone, required password}) async {},
          signUpRoute: () => MaterialPageRoute<void>(builder: (_) => const SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final back = tester.getRect(find.byType(AppBackButton));
    final logo = tester.getRect(find.byType(AppLogo).last);
    expect(back.overlaps(logo), isFalse);
    expect(back.center.dx, greaterThan(logo.center.dx), reason: 'back comes first on the right in RTL');
    expect((back.center.dy - logo.center.dy).abs(), lessThan(1), reason: 'they sit on one row');
  });
}
