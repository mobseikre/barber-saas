import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  static final builds = <String>[];

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _taps = 0;

  @override
  void initState() {
    super.initState();
    _Counter.builds.add(widget.name);
  }

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => _taps++), child: Text('${widget.name} $_taps'));
}

void main() {
  const tabs = <AppTab>[
    (icon: Icons.home_outlined, label: 'الرئيسية', screen: _Counter('home')),
    (icon: Icons.calendar_today_outlined, label: 'حجوزاتي', screen: _Counter('bookings')),
  ];

  setUp(_Counter.builds.clear);

  Color? labelColor(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style?.color;
  double? iconSize(WidgetTester tester, IconData icon) => tester.widget<Icon>(find.byIcon(icon)).size;

  testWidgets('a tab is built the first time it opens and keeps its state', (tester) async {
    await pumpPhone(tester, wrapApp(const TabShell(tabs: tabs, variant: AppBottomNavVariant.light)));
    expect(_Counter.builds, ['home']);

    await tester.tap(find.text('home 0'));
    await tester.tap(find.text('حجوزاتي'));
    await tester.pumpAndSettle();
    expect(_Counter.builds, ['home', 'bookings']);

    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('home 1'), findsOneWidget, reason: 'the home tab kept its state');
    expect(_Counter.builds, ['home', 'bookings']);
  });

  testWidgets('the light bar marks the active tab in dark blue with a pale red pill', (tester) async {
    await pumpPhone(tester, wrapApp(const TabShell(tabs: tabs, variant: AppBottomNavVariant.light)));

    expect(labelColor(tester, 'الرئيسية'), AppColors.blue900);
    expect(labelColor(tester, 'حجوزاتي'), AppColors.text3);
    final pill = tester.widget<Container>(
      find.ancestor(of: find.byIcon(Icons.home_outlined), matching: find.byType(Container)).first,
    );
    expect((pill.decoration as BoxDecoration).color, AppColors.red100);
    expect(iconSize(tester, Icons.home_outlined), AppSizes.iconMd);
    expect(tester.getSize(find.byType(AppBottomNav)).height, AppSizes.bottomNav + AppSpacing.md);
  });

  testWidgets('the dark bar marks the active tab in red on dark blue', (tester) async {
    await pumpPhone(tester, wrapApp(const TabShell(tabs: tabs, variant: AppBottomNavVariant.dark)));

    expect(labelColor(tester, 'الرئيسية'), AppColors.red400);
    expect(labelColor(tester, 'حجوزاتي'), AppColors.onDarkInactive);
    expect(iconSize(tester, Icons.calendar_today_outlined), AppSizes.iconMd);
    final bar = tester.widget<Container>(
      find.descendant(of: find.byType(AppBottomNav), matching: find.byType(Container)).first,
    );
    expect((bar.decoration as BoxDecoration).color, AppColors.blue900);
  });
}
