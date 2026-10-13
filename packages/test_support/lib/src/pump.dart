import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

/// The app theme, locale and a [ProviderScope] around [home], without retries.
Widget wrapApp(Widget home, {Iterable<Object> overrides = const []}) => ProviderScope(
  retry: (_, _) => null,
  overrides: overrides.cast<Override>().toList(),
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: AppTheme.locale,
    supportedLocales: AppTheme.supportedLocales,
    localizationsDelegates: AppTheme.localizationsDelegates,
    home: home,
  ),
);

/// Lays the widget out at the design's phone size (390 × 844).
Future<void> pumpPhone(WidgetTester tester, Widget app, {bool settle = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fixes [AppTime] at [now] for each test of the group.
void useTestClock(DateTime now) {
  setUp(() => AppTime.clock = () => now);
  tearDown(() => AppTime.clock = DateTime.now);
}
