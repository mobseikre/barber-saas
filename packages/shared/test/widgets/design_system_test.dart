import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

Widget _app(Widget child, {MediaQueryData? media}) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppTheme.locale,
  supportedLocales: AppTheme.supportedLocales,
  localizationsDelegates: AppTheme.localizationsDelegates,
  builder: media == null ? null : (context, child) => MediaQuery(data: media, child: child!),
  home: Scaffold(body: Form(child: child)),
);

void main() {
  testWidgets('StatusBarScrim lets taps through to content under the status bar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatusBarScrim(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 20));

    expect(taps, 1);
  });

  group('inputs', () {
    testWidgets('a text field, the phone field and the password field are 52px tall', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              const AppTextField(label: 'الاسم', hint: 'مثال'),
              PhoneField(controller: TextEditingController()),
              PasswordField(controller: TextEditingController()),
            ],
          ),
        ),
      );

      final heights = [
        for (final f in find.byType(TextField).evaluate()) tester.getSize(find.byWidget(f.widget)).height,
      ];
      expect(heights, [AppSizes.input, AppSizes.input, AppSizes.input]);
    });

    test('the focused border draws the ring and the error border does not', () {
      final theme = AppTheme.light().inputDecorationTheme;
      expect(theme.focusedBorder, isA<FocusRingBorder>());
      expect(theme.focusedErrorBorder, isNot(isA<FocusRingBorder>()));
      expect(theme.enabledBorder, isNot(isA<FocusRingBorder>()));
    });

    testWidgets('the ring is painted in the light red around the focused field', (tester) async {
      final focus = FocusNode();
      await tester.pumpWidget(_app(AppTextField(label: 'الاسم', focusNode: focus)));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);

      focus.requestFocus();
      await tester.pumpAndSettle();

      final decorator = tester.renderObject(find.byType(InputDecorator));
      expect(decorator, paints..rrect(color: AppColors.red50));
    });

    testWidgets('the error border has no ring', (tester) async {
      await tester.pumpWidget(_app(AppTextField(label: 'الاسم', validator: (_) => 'خطأ')));
      final state = tester.state<FormFieldState<String>>(find.byType(TextFormField));
      state.validate();
      await tester.pumpAndSettle();

      expect(tester.renderObject(find.byType(InputDecorator)), isNot(paints..rrect(color: AppColors.red50)));
    });
  });

  group('buttons', () {
    testWidgets('card action buttons are 40px tall with r10 corners and 14/700 labels', (tester) async {
      await tester.pumpWidget(
        _app(
          Row(
            children: [
              Expanded(
                child: ActionButton.attended(height: AppSizes.cardButton, onPressed: () {}),
              ),
              Expanded(child: ActionButton.noShow(onPressed: () {})),
            ],
          ),
        ),
      );

      final compact = find.widgetWithText(ActionButton, 'حضر');
      final regular = find.widgetWithText(ActionButton, 'لم يحضر');
      expect(tester.getSize(compact).height, AppSizes.cardButton);
      expect(tester.getSize(regular).height, AppSizes.actionButton);
      expect(
        tester.widget<Material>(find.descendant(of: compact, matching: find.byType(Material))).borderRadius,
        BorderRadius.circular(AppRadius.smallButton),
      );
      expect(
        tester.widget<Material>(find.descendant(of: regular, matching: find.byType(Material))).borderRadius,
        BorderRadius.circular(AppRadius.control),
      );
      expect(tester.widget<Text>(find.descendant(of: compact, matching: find.text('حضر'))).style!.fontSize, 14);
      expect(tester.widget<Text>(find.descendant(of: regular, matching: find.text('لم يحضر'))).style!.fontSize, 15);
    });

    testWidgets('text links are 16/700 in the red link colour', (tester) async {
      await tester.pumpWidget(_app(TextButton(onPressed: () {}, child: const Text('إنشاء حساب'))));

      final style = tester.renderObject<RenderParagraph>(find.text('إنشاء حساب')).text.style!;
      expect((style.fontSize, style.fontWeight, style.color), (16.0, FontWeight.w700, AppColors.red700));
    });

    testWidgets('the loading spinner is visible on every variant', (tester) async {
      Color spinner() => tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).color!;
      const expected = {
        AppButtonVariant.primary: AppColors.surface,
        AppButtonVariant.accent: AppColors.surface,
        AppButtonVariant.secondary: AppColors.blue900,
        AppButtonVariant.secondaryOnDark: AppColors.surface,
        AppButtonVariant.text: AppColors.red700,
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(_app(AppButton(label: 'x', variant: entry.key, loading: true, onPressed: () {})));
        expect(spinner(), entry.value, reason: '${entry.key}');
      }
    });

    testWidgets('a compact button fits its label instead of filling the width', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: AppButton(label: 'حفظ', compact: true, onPressed: () {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, AppSizes.cardButton);
      expect(size.width, lessThan(120));
      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
      expect(
        (style.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.smallButton),
      );
      expect(style.textStyle!.resolve({})!.fontSize, AppText.buttonCompact.fontSize);
    });

    testWidgets('the VIP pill is 30px tall', (tester) async {
      await tester.pumpWidget(_app(const Center(child: VipBadge())));

      expect(tester.getSize(find.byType(VipBadge)).height, AppSizes.badge);
    });
  });

  group('AppSwitch', () {
    testWidgets('is a 50x30 pill that toggles and reports its state', (tester) async {
      var value = false;
      await tester.pumpWidget(
        _app(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) =>
                  AppSwitch(value: value, semanticLabel: 'تفعيل', onChanged: (v) => setState(() => value = v)),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppSwitch)), const Size(AppSizes.switchWidth, AppSizes.switchHeight));
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(AppSwitch)),
        matchesSemantics(
          label: 'تفعيل',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('does nothing when disabled', (tester) async {
      await tester.pumpWidget(_app(const Center(child: AppSwitch(value: true, onChanged: null))));
      await tester.tap(find.byType(AppSwitch));
      await tester.pump();
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);
    });
  });

  group('bottom sheets', () {
    testWidgets('keep their content above the home indicator', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(
                  height: 600,
                  child: Align(alignment: Alignment.bottomCenter, child: Text('آخر السطر')),
                ),
              ),
              child: const Text('فتح'),
            ),
          ),
          media: const MediaQueryData(size: Size(390, 844), padding: EdgeInsets.only(bottom: 34)),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(tester.getBottomLeft(find.text('آخر السطر')).dy, lessThanOrEqualTo(844 - 34));
    });
  });

  group('LetterAvatar', () {
    testWidgets('falls back to the letter when the photo cannot load', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: LetterAvatar(name: 'علي', imageUrl: 'https://example.invalid/a.png'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ع'), findsOneWidget);
    });

    testWidgets('shows the letter when there is no photo', (tester) async {
      await tester.pumpWidget(_app(const Center(child: LetterAvatar(name: 'مراد'))));

      expect(find.text('م'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  testWidgets('the app logo is a rounded dark tile with the barber pole', (tester) async {
    await tester.pumpWidget(_app(const Center(child: AppLogo(size: 100))));

    final box = tester.widget<Container>(find.byType(Container).first).decoration! as BoxDecoration;
    expect(box.color, AppColors.blue900);
    expect(tester.getSize(find.byType(AppLogo)), const Size(100, 100));
    expect(find.descendant(of: find.byType(AppLogo), matching: find.byType(CustomPaint)), findsWidgets);
  });

  group('direction', () {
    Finder mirrored(Finder of) => find.descendant(
      of: of,
      matching: find.byWidgetPredicate((w) => w is Transform && w.transform.storage[0] == -1),
    );

    testWidgets('the back arrow points right in the Arabic app', (tester) async {
      await tester.pumpWidget(_app(const Center(child: AppBackButton())));

      final icon = tester.widget<Icon>(find.descendant(of: find.byType(AppBackButton), matching: find.byType(Icon)));
      expect(icon.icon, Icons.arrow_back_rounded, reason: 'the glyph points left before mirroring');
      expect(Directionality.of(tester.element(find.byType(AppBackButton))), TextDirection.rtl);
      expect(mirrored(find.byType(AppBackButton)), findsOneWidget, reason: 'RTL mirrors it to point right');
    });

    testWidgets('in a left-to-right context the same arrow points left', (tester) async {
      await tester.pumpWidget(
        _app(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: AppBackButton()),
          ),
        ),
      );

      expect(mirrored(find.byType(AppBackButton)), findsNothing);
    });
  });

  group('RetryMessage', () {
    testWidgets('a block shows the message and a full retry button', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          Center(
            child: RetryMessage(message: 'تعذّر التحميل', onRetry: () => retries++),
          ),
        ),
      );

      expect(find.text('تعذّر التحميل'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, RetryMessage.retryLabel));
      expect(retries, 1);
    });

    testWidgets('a block with a title shows the title above a muted message', (tester) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: RetryMessage(title: 'تعذّر الاتصال بالخادم', message: 'x', onRetry: () {}),
          ),
        ),
      );

      expect(tester.getTopLeft(find.text('تعذّر الاتصال بالخادم')).dy, lessThan(tester.getTopLeft(find.text('x')).dy));
      expect(tester.widget<Text>(find.text('x')).style!.color, AppColors.text3);
    });

    testWidgets('inline it is one row with a text button', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_app(RetryMessage(inline: true, message: 'تعذّر التحميل', onRetry: () => retries++)));

      expect(find.byType(FilledButton), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, RetryMessage.retryLabel));
      expect(retries, 1);
      expect(
        tester.getCenter(find.text('تعذّر التحميل')).dy,
        moreOrLessEquals(tester.getCenter(find.text(RetryMessage.retryLabel)).dy, epsilon: 1),
      );
    });
  });

  group('AppHeader', () {
    double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

    testWidgets('the subtitle sits above the title by default', (tester) async {
      await tester.pumpWidget(_app(const AppHeader(title: 'حجوزات اليوم', subtitle: 'الأحد')));

      expect(top(tester, 'الأحد'), lessThan(top(tester, 'حجوزات اليوم')));
    });

    testWidgets('subtitleBelow puts it under the title', (tester) async {
      await tester.pumpWidget(_app(const AppHeader(title: 'تسجيل الدخول', subtitle: 'أهلاً', subtitleBelow: true)));

      expect(top(tester, 'أهلاً'), greaterThan(top(tester, 'تسجيل الدخول')));
    });
  });

  group('StatCard', () {
    testWidgets('the compact tile uses the small header style', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: StatCard(label: 'مكتمل', value: '5', compact: true),
          ),
        ),
      );

      expect(tester.widget<Text>(find.text('5')).style!.fontSize, AppText.h2.fontSize);
      expect(tester.widget<Text>(find.text('مكتمل')).style!.color, AppColors.onDarkInactive);
      final box = tester.widget<Container>(find.ancestor(of: find.text('5'), matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(AppRadius.control));
    });
  });

  testWidgets('a loading action button shows a spinner in its colour and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(ActionButton.cancel(loading: true, onPressed: () => taps++)));

    expect(find.text('إلغاء الحجز'), findsNothing);
    final spinner = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(spinner.color, AppColors.danger);
    await tester.tap(find.byType(ActionButton));
    expect(taps, 0);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1, reason: 'not greyed out like a disabled button');
  });
}
