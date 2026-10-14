import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  locale: AppTheme.locale,
  supportedLocales: AppTheme.supportedLocales,
  localizationsDelegates: AppTheme.localizationsDelegates,
  home: Scaffold(
    body: Center(
      child: SizedBox(height: AppSizes.numberBox, child: child),
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('the label is today, tomorrow, then the weekday', () {
    final sunday = DateTime(2026, 10, 18);
    expect(DayTile.labelFor(0, sunday), 'اليوم');
    expect(DayTile.labelFor(1, sunday), 'غداً');
    expect(DayTile.labelFor(4, sunday), ArabicFormat.weekday(sunday));
  });

  testWidgets('a day that can be picked answers taps; one that cannot is struck through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(DayTile(label: 'غداً', day: 15, selected: false, onTap: () => taps++)));
    await tester.tap(find.text('15'));
    expect(taps, 1);
    expect(tester.widget<Text>(find.text('15')).style!.decoration, isNull);

    await tester.pumpWidget(_app(const DayTile(label: 'الجمعة', day: 16, selected: false, onTap: null)));
    expect(tester.widget<Text>(find.text('16')).style!.decoration, TextDecoration.lineThrough);
  });

  testWidgets('the selected day is dark blue with white digits', (tester) async {
    await tester.pumpWidget(_app(DayTile(label: 'اليوم', day: 14, selected: true, onTap: () {})));

    expect(tester.widget<Text>(find.text('14')).style!.color, AppColors.surface);
    expect(tester.widget<Material>(find.byType(Material).last).color, AppColors.blue900);
  });
}
