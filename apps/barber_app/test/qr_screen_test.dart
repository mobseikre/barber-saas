import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/account/account_tab.dart';
import 'package:barber_app/features/qr/qr_screen.dart';
import 'package:barber_app/features/qr/qr_sticker.dart';
import 'package:barber_app/providers.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;
  late FakeStickerSharer sharer;

  setUpAll(() => initializeDateFormatting('ar'));
  setUp(() {
    repo = FakeBarberRepo()..salonValue = testSalon(id: 's1');
    sharer = FakeStickerSharer();
  });

  Future<void> pumpQr(WidgetTester tester, {Widget home = const QrScreen()}) => pumpPhone(
    tester,
    testApp(home: home, barbers: repo, overrides: [stickerSharerProvider.overrideWithValue(sharer)]),
  );

  testWidgets('shows the QR of the barber page with the name and salon', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpQr(tester);

    expect(find.text('رمز QR'), findsOneWidget);
    expect(find.byKey(ValueKey(barberLink(fakeBarber.id).toString())), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^رمز QR لصفحة علي القماطي')), findsOneWidget);
    expect(find.text('علي القماطي'), findsOneWidget);
    expect(find.text(testSalon().name), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shares the A5 sticker as a PDF', (tester) async {
    await pumpQr(tester);

    await tester.runAsync(() => tester.tap(find.text('مشاركة الملصق PDF')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();

    final (pdf, filename) = sharer.shared.single;
    expect(filename, 'hallaqi-qr.pdf');
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed share says so and lets the barber try again', (tester) async {
    sharer.error = Exception('no share sheet');
    await pumpQr(tester);

    await tester.runAsync(() => tester.tap(find.text('مشاركة الملصق PDF')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تجهيز الملصق، حاول مرة أخرى'), findsOneWidget);
    final button = tester.widget<AppButton>(find.widgetWithText(AppButton, 'مشاركة الملصق PDF'));
    expect(button.loading, isFalse);
  });

  testWidgets('a failed salon load offers a retry', (tester) async {
    repo.failLoads = 1;
    await pumpQr(tester);
    expect(find.byType(QrImageView), findsNothing);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('the account tab opens it', (tester) async {
    await pumpQr(tester, home: const AccountTab());

    await tapVisible(tester, find.text('رمز QR'));

    expect(find.byType(QrScreen), findsOneWidget);
  });

  test('the sticker is one A5 page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final pdf = await buildQrSticker(barberName: 'علي القماطي', salonName: 'صالون الأناقة', link: barberLink('b1'));
    final text = latin1.decode(pdf);

    expect(RegExp(r'/Type\s*/Page\b').allMatches(text), hasLength(1));
    expect(text, contains('/MediaBox[0 0 419.52756 595.27559]'));
  });
}
