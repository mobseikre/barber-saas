import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

Widget _app(Widget body, {bool dismiss = true}) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppTheme.locale,
  supportedLocales: AppTheme.supportedLocales,
  localizationsDelegates: AppTheme.localizationsDelegates,
  builder: dismiss ? (context, child) => KeyboardDismiss(child: child!) : null,
  home: Scaffold(body: body),
);

void main() {
  final phone = TextEditingController();
  final name = TextEditingController();
  var saves = 0;

  Widget form() => ListView(
    padding: const EdgeInsets.all(AppSpacing.screen),
    children: [
      PhoneField(controller: phone),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(label: 'الاسم', controller: name),
      const SizedBox(height: AppSpacing.lg),
      AppButton(label: 'حفظ', onPressed: () => saves++),
      const SizedBox(height: 1200),
    ],
  );

  setUp(() => saves = 0);

  bool keyboardOpen(WidgetTester tester) => tester.testTextInput.isVisible;
  bool focused(WidgetTester tester) =>
      tester.widgetList<EditableText>(find.byType(EditableText)).any((e) => e.focusNode.hasFocus);

  testWidgets('without it a tap outside leaves the keyboard open on a phone', (tester) async {
    await pumpPhone(tester, _app(form(), dismiss: false));

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.tapAt(const Offset(195, 700));
    await tester.pump();

    expect(focused(tester), isTrue, reason: 'Flutter keeps focus on touch by default on Android and iOS');
  });

  testWidgets('a tap outside the field closes the keyboard', (tester) async {
    await pumpPhone(tester, _app(form()));

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    expect(keyboardOpen(tester), isTrue);

    await tester.tapAt(const Offset(195, 700));
    await tester.pump();

    expect(focused(tester), isFalse);
    expect(keyboardOpen(tester), isFalse);
  });

  testWidgets('a tap on a button closes the keyboard and still presses the button', (tester) async {
    await pumpPhone(tester, _app(form()));

    await tester.tap(find.byType(TextFormField).last);
    await tester.enterText(find.byType(TextFormField).last, 'سالم');
    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(saves, 1);
    expect(focused(tester), isFalse);
    expect(name.text, 'سالم');
  });

  testWidgets('a tap on another field moves the keyboard there', (tester) async {
    await pumpPhone(tester, _app(form()));

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();

    expect(focused(tester), isTrue);
    expect(keyboardOpen(tester), isTrue);
    expect(tester.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus, isTrue);
  });

  testWidgets('scrolling closes the keyboard', (tester) async {
    await pumpPhone(tester, _app(form()));

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();

    expect(focused(tester), isFalse);
  });

  testWidgets('it works inside a bottom sheet', (tester) async {
    await pumpPhone(
      tester,
      _app(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTextField(label: 'اسم الزبون', controller: name),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
              ),
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(focused(tester), isTrue);

    await tester.tapAt(tester.getBottomLeft(find.byType(TextFormField)) + const Offset(10, 100));
    await tester.pump();

    expect(focused(tester), isFalse);
    expect(find.text('اسم الزبون'), findsOneWidget, reason: 'the sheet stays open');
  });
}
