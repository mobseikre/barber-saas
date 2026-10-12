import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppTheme.locale,
  supportedLocales: AppTheme.supportedLocales,
  localizationsDelegates: AppTheme.localizationsDelegates,
  home: Scaffold(body: Form(child: child)),
);

void main() {
  testWidgets('PhoneField shows the +218 prefix and keeps digits LTR', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(PhoneField(controller: controller)));

    expect(find.text('+218'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).textDirection, TextDirection.ltr);
    final field = tester.getRect(find.byType(TextFormField));
    expect(
      tester.getRect(find.text('+218')).center.dx,
      lessThan(field.center.dx),
      reason: 'prefix block sits on the left',
    );

    await tester.enterText(find.byType(TextFormField), '91x234');
    expect(controller.text, '91234', reason: 'letters are filtered out');
  });

  testWidgets('PhoneField error follows the RTL layout', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _wrap(
        Form(
          key: formKey,
          child: PhoneField(controller: TextEditingController()),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();
    final field = tester.getRect(find.byType(TextFormField));
    expect(
      tester.getRect(find.text('أدخل رقم الهاتف')).right,
      greaterThan(field.center.dx),
      reason: 'error starts on the right',
    );
  });

  testWidgets('PhoneField validation messages', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PhoneField(controller: controller),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('أدخل رقم الهاتف'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12345');
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.textContaining('رقم الهاتف غير صحيح'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '0912345678');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('PasswordField toggles visibility and validates length', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PasswordField(controller: controller),
          ),
        ),
      ),
    );

    EditableText editable() => tester.widget<EditableText>(find.byType(EditableText));
    expect(editable().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(editable().obscureText, isFalse);

    await tester.enterText(find.byType(TextFormField), '1234567');
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('كلمة المرور يجب أن تكون 8 أحرف على الأقل'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '12345678');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets('AppTextField stops typing at maxLength', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(AppTextField(label: 'ملاحظة', controller: controller, maxLength: 5)));

    await tester.enterText(find.byType(TextFormField), 'ابجدهوز');
    expect(controller.text, 'ابجده');
  });

  testWidgets('StatusBadge shows the Arabic label with an icon per status', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            StatusBadge(BookingStatus.confirmed),
            StatusBadge(BookingStatus.completed),
            StatusBadge(BookingStatus.noShow),
            StatusBadge(BookingStatus.cancelled),
          ],
        ),
      ),
    );
    expect(find.text('مؤكد'), findsOneWidget);
    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('لم يحضر'), findsOneWidget);
    expect(find.text('ملغي'), findsOneWidget);
    expect(find.byType(Icon), findsNWidgets(4));
  });

  testWidgets('AppButton shows a spinner and blocks taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton(label: 'تسجيل الدخول', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });
}
