import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(onPressed: () => setState(() => _taps++), child: Text('APP $_taps')),
    ),
  );
}

void main() {
  late FakeAuthRepo auth;
  late FakePushMessaging push;

  Future<void> pumpGate(WidgetTester tester, {bool locked = true}) async {
    auth = FakeAuthRepo(userId: 'u1')..mustChangePassword = locked;
    push = FakePushMessaging();
    await pumpPhone(
      tester,
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          pushMessagingProvider.overrideWithValue(push),
          deviceTokenRepositoryProvider.overrideWithValue(FakeDeviceTokenRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: AppTheme.locale,
          supportedLocales: AppTheme.supportedLocales,
          localizationsDelegates: AppTheme.localizationsDelegates,
          builder: (context, child) => PasswordChangeGate(child: child!),
          home: const _Counter(),
        ),
      ),
    );
  }

  Finder field(String label) => fieldLabelled(label);

  Future<void> fillAndSave(WidgetTester tester, String password, [String? confirm]) async {
    await tester.enterText(field('كلمة المرور الجديدة'), password);
    await tester.enterText(field('تأكيد كلمة المرور الجديدة'), confirm ?? password);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ والمتابعة'));
  }

  testWidgets('without the flag the app shows as usual', (tester) async {
    await pumpGate(tester, locked: false);
    expect(find.text('APP 0'), findsOneWidget);
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
  });

  testWidgets('with the flag the change screen comes before anything else, in RTL', (tester) async {
    await pumpGate(tester);
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
    expect(find.text('اختر كلمة مرور جديدة'), findsOneWidget);
    expect(find.text('APP 0'), findsNothing);
    expect(find.text('APP 0', skipOffstage: false), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('اختر كلمة مرور جديدة'))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the new password is checked before anything is sent', (tester) async {
    await pumpGate(tester);
    await fillAndSave(tester, 'short');
    expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);

    await fillAndSave(tester, 'NewPass-2026', 'NewPass-2027');
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('saving calls change_password, refreshes the session and opens the app', (tester) async {
    await pumpGate(tester);
    await fillAndSave(tester, 'NewPass-2026');
    expect(auth.calls, ['completePasswordChange:NewPass-2026']);
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.text('APP 0'), findsOneWidget);
    expect(find.text('تم حفظ كلمة المرور الجديدة'), findsOneWidget);
  });

  testWidgets('the hidden app keeps its state while the screen is up', (tester) async {
    await pumpGate(tester, locked: false);
    await tester.tap(find.text('APP 0'));
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.text('APP 1')));
    auth.mustChangePassword = true;
    container.invalidate(mustChangePasswordProvider);
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);

    await fillAndSave(tester, 'NewPass-2026');
    expect(find.text('APP 1'), findsOneWidget);
  });

  testWidgets('a server refusal is shown in Arabic and the screen stays', (tester) async {
    await pumpGate(tester);
    auth.completePasswordChangeError = const PostgrestException(message: 'password_too_short', code: 'P0001');
    await fillAndSave(tester, 'NewPass-2026');
    expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
  });

  testWidgets('a failed refresh can be retried', (tester) async {
    await pumpGate(tester);
    auth.completePasswordChangeError = const AuthException('network', statusCode: '0');
    await fillAndSave(tester, 'NewPass-2026');
    expect(find.text(genericErrorMessage), findsOneWidget);

    auth.completePasswordChangeError = null;
    await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ والمتابعة'));
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
  });

  testWidgets('the button shows progress and ignores a second tap', (tester) async {
    await pumpGate(tester);
    final gate = Completer<void>();
    auth.completePasswordChangeGate = gate;
    await tester.enterText(field('كلمة المرور الجديدة'), 'NewPass-2026');
    await tester.enterText(field('تأكيد كلمة المرور الجديدة'), 'NewPass-2026');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ والمتابعة'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(auth.calls, ['completePasswordChange:NewPass-2026']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
  });

  testWidgets('signing out from the screen ends the session and closes it', (tester) async {
    await pumpGate(tester);
    await tapVisible(tester, find.widgetWithText(TextButton, 'تسجيل الخروج'));
    expect(auth.calls, ['signOut']);
    expect(auth.userId, isNull);
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
  });

  testWidgets('the system back button does not dismiss the screen', (tester) async {
    await pumpGate(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
  });

  testWidgets('the system back button does not close the app while the screen is up', (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpGate(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(exits, 0);
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);
  });

  testWidgets('the system back button leaves the hidden app on its current screen', (tester) async {
    await pumpGate(tester, locked: false);
    Navigator.of(
      tester.element(find.text('APP 0')),
    ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('PUSHED'))));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.text('PUSHED')));
    auth.mustChangePassword = true;
    container.invalidate(mustChangePasswordProvider);
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordRequiredScreen), findsOneWidget);

    await fillAndSave(tester, 'NewPass-2026');
    expect(find.byType(ChangePasswordRequiredScreen), findsNothing);
    expect(find.text('PUSHED'), findsOneWidget);
  });
}
