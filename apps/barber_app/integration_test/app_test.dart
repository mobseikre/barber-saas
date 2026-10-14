import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart' show fieldLabelled;

import 'package:barber_app/app.dart';

// Runs the real app against the local Supabase stack after `supabase db reset`:
//   flutter test integration_test -d <emulator> --dart-define-from-file=env/android.json
// The keyboard checks watch the device's own on-screen keyboard. On an Android emulator with a
// hardware keyboard, turn on `adb shell settings put secure show_ime_with_hard_keyboard 1` first.

Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
      throw TestFailure('Timed out waiting for $finder; on screen: $texts');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Waits until the device keyboard is up or down, judged by the space it takes at the bottom of the screen.
Future<void> _waitForKeyboard(WidgetTester tester, {required bool open}) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while ((tester.view.viewInsets.bottom > 0) != open) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure(
        'The keyboard did not ${open ? 'open' : 'close'} (bottom inset ${tester.view.viewInsets.bottom})',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _button(String label) => find.ancestor(of: find.text(label), matching: find.byType(FilledButton));

Finder _priceField(String code) =>
    find.descendant(of: find.byKey(ValueKey('price-$code')), matching: find.byType(TextField));

Future<void> _openTab(WidgetTester tester, String label) =>
    _tap(tester, find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)));

Future<void> _savePrice(WidgetTester tester, String price) async {
  await _tap(tester, _priceField('haircut'));
  await _waitForKeyboard(tester, open: true);
  await tester.enterText(_priceField('haircut'), price);
  await tester.pump(const Duration(milliseconds: 300));
  await _tap(tester, _button('حفظ'));
  await _waitForKeyboard(tester, open: false);
  await _waitFor(tester, find.text('تم حفظ الخدمات'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initSupabase();
  });

  setUp(() => supabase.auth.signOut());

  testWidgets('the keyboard closes on a tap outside, on save and when leaving through the tab bar', (tester) async {
    await tester.pumpWidget(ProviderScope(key: UniqueKey(), child: const BarberApp()));
    await _waitFor(tester, find.text('نسيت كلمة المرور؟'));

    await _tap(tester, fieldLabelled('رقم الهاتف'));
    await _waitForKeyboard(tester, open: true);
    await _tap(tester, find.byType(AppHeader));
    await _waitForKeyboard(tester, open: false);

    await tester.enterText(fieldLabelled('رقم الهاتف'), '0912345678');
    await tester.enterText(fieldLabelled('كلمة المرور'), 'password123');
    await _tap(tester, find.byType(AppHeader));
    await _waitForKeyboard(tester, open: false);
    await _tap(tester, _button('تسجيل الدخول'));
    await _waitFor(tester, find.text('حجوزات اليوم'));

    await _openTab(tester, 'الخدمات');
    await _waitFor(tester, _priceField('haircut'));
    final original = tester.widget<TextField>(_priceField('haircut')).controller!.text;
    final changed = '${int.parse(original) + 1}';

    await _savePrice(tester, changed);
    expect(tester.widget<TextField>(_priceField('haircut')).controller!.text, changed);

    await _tap(tester, _priceField('haircut'));
    await _waitForKeyboard(tester, open: true);
    await _tap(tester, find.text('خدماتي'));
    await _waitForKeyboard(tester, open: false);
    await _openTab(tester, 'الحجوزات');
    await _waitFor(tester, find.text('حجوزات اليوم'));

    await _openTab(tester, 'الخدمات');
    await _savePrice(tester, original);
  });
}
