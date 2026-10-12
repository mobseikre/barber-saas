import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/schedule/working_hours_screen.dart';

import 'support/fake_barber_repo.dart';
import 'support/fakes.dart';

void main() {
  late FakeBarberRepo repo;

  Future<void> pumpHours(WidgetTester tester) async {
    await pumpPhone(tester, testApp(home: const WorkingHoursScreen(), barbers: repo));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'حفظ أوقات العمل');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Break lunch({TimeOfDay? ends}) => Break(
    id: 'k1',
    barberId: 'b1',
    name: 'غداء وصلاة',
    startsAt: const TimeOfDay(hour: 13, minute: 30),
    endsAt: ends ?? const TimeOfDay(hour: 14, minute: 30),
  );

  setUp(() => repo = FakeBarberRepo());

  testWidgets('starts with Saturday to Thursday open and Friday off when nothing is saved', (tester) async {
    await pumpHours(tester);

    expect(find.text('أوقات العمل'), findsOneWidget);
    for (final day in ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('يوم عطلة'), findsOneWidget);
    expect(
      tester.widget<AppSwitch>(find.byKey(const ValueKey('open-5'))).value,
      isFalse,
      reason: 'Friday is weekday 5',
    );
    expect(find.text('10:00 ص'), findsNWidgets(6));
    expect(find.text('10:00 م'), findsNWidgets(6));
    expect(find.text('لا توجد استراحات'), findsOneWidget);
  });

  testWidgets('saving writes all seven days in Postgres weekday numbers, with the day off closed', (tester) async {
    await pumpHours(tester);

    await tester.tap(find.byKey(const ValueKey('open-2')));
    await tester.pump();
    await save(tester);

    final hours = repo.savedSchedules.single.hours;
    expect(hours.map((h) => h.weekday), [6, 0, 1, 2, 3, 4, 5]);
    expect(hours.where((h) => h.isClosed).map((h) => h.weekday), [2, 5]);
    expect(hours.every((h) => h.barberId == 'b1'), isTrue);
    expect(find.text('تم حفظ أوقات العمل'), findsOneWidget);
  });

  testWidgets('saved hours are shown and a day cannot close before it opens', (tester) async {
    repo.hours = [
      WorkingHours(
        barberId: 'b1',
        weekday: 0,
        opensAt: const TimeOfDay(hour: 18, minute: 0),
        closesAt: const TimeOfDay(hour: 9, minute: 0),
      ),
    ];
    await pumpHours(tester);
    expect(find.text('6:00 م'), findsOneWidget);

    await save(tester);

    expect(find.text('وقت الإغلاق يجب أن يكون بعد وقت الفتح'), findsOneWidget);
    expect(repo.savedSchedules, isEmpty);
  });

  testWidgets('a time is changed with the picker', (tester) async {
    await pumpHours(tester);

    await tester.tap(find.byKey(const ValueKey('closes-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), '11');
    await tester.enterText(inputs.at(1), '30');
    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const ValueKey('closes-6')), matching: find.text('11:30 م')), findsOneWidget);
  });

  testWidgets('a break is added from the sheet and saved with the schedule', (tester) async {
    await pumpHours(tester);

    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    expect(find.text('أدخل اسم الاستراحة'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'غداء وصلاة');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pumpAndSettle();

    expect(find.text('غداء وصلاة'), findsOneWidget);
    expect(find.text('1:30 م — 2:30 م'), findsOneWidget);
    await save(tester);

    final saved = repo.savedSchedules.single.breaks.single;
    expect((saved.name, saved.barberId, saved.id), ('غداء وصلاة', 'b1', null));
  });

  testWidgets('a break is edited and deleted from its row', (tester) async {
    repo.breaks = [lunch()];
    await pumpHours(tester);

    await tester.tap(find.text('غداء وصلاة'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل الاستراحة'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'صلاة');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('صلاة'), findsOneWidget);

    await tester.tap(find.text('صلاة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الاستراحة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد استراحات'), findsOneWidget);

    await save(tester);
    expect(repo.savedSchedules.single.breaks, isEmpty);
  });

  testWidgets('a break cannot end before it starts', (tester) async {
    repo.breaks = [lunch(ends: const TimeOfDay(hour: 13, minute: 0))];
    await pumpHours(tester);

    await tester.tap(find.text('غداء وصلاة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pump();

    expect(find.text('وقت نهاية الاستراحة يجب أن يكون بعد بدايتها'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry and a failed save shows the Arabic reason', (tester) async {
    repo.failLoads = 1;
    await pumpHours(tester);
    expect(find.text(genericErrorMessage), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('الجمعة'), findsOneWidget);

    repo.saveError = const PostgrestException(message: 'denied', code: '42501');
    await save(tester);
    expect(find.text('ليست لديك صلاحية لهذا الإجراء'), findsOneWidget);
  });
}
