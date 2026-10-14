import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/auth/salon_picker.dart';

import 'support/fakes.dart';

void main() {
  late _FakeSearch search;

  Future<void> pumpPicker(WidgetTester tester) async {
    search = _FakeSearch();
    await pumpPhone(
      tester,
      testApp(
        home: Scaffold(body: SalonPicker(selected: null, onChanged: (_) {})),
        overrides: [barberRepositoryProvider.overrideWithValue(search)],
      ),
    );
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Salon salon(String name) => Salon(id: name, name: name, createdAt: DateTime(2026));

  testWidgets('the search icon sits at the start of the field, on the right in RTL', (tester) async {
    await pumpPicker(tester);

    final field = tester.getRect(find.byType(TextField));
    expect(tester.getCenter(find.byIcon(Icons.search_rounded)).dx, greaterThan(field.center.dx));
  });

  testWidgets('no match says a new salon will be created', (tester) async {
    await pumpPicker(tester);
    search.next = Completer()..complete(const []);

    await type(tester, 'صالون غير موجود');
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد صالون بهذا الاسم، سيُنشأ صالون جديد باسم «صالون غير موجود»'), findsOneWidget);
  });

  testWidgets('the typed name is reported for a new salon, and a picked salon reports its own name', (tester) async {
    search = _FakeSearch();
    final names = <String>[];
    await pumpPhone(
      tester,
      testApp(
        home: Scaffold(
          body: SalonPicker(selected: null, onChanged: (_) {}, onNameChanged: names.add),
        ),
        overrides: [barberRepositoryProvider.overrideWithValue(search)],
      ),
    );
    search.next = Completer()..complete([salon('صالون الأناقة')]);

    await type(tester, ' الأناقة ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('صالون الأناقة'));
    await tester.pumpAndSettle();

    expect(names, ['الأناقة', 'صالون الأناقة']);
  });

  testWidgets('a failed search shows an error line instead of looking empty', (tester) async {
    await pumpPicker(tester);
    final failing = Completer<List<Salon>>();
    search.next = failing;

    await type(tester, 'الأناقة');
    failing.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.text('تعذّر البحث، تأكد من الاتصال وحاول مرة أخرى'), findsOneWidget);
    expect(find.textContaining('لا يوجد صالون بهذا الاسم'), findsNothing, reason: 'only the general hint');
  });

  testWidgets('a slow older search cannot overwrite the latest results', (tester) async {
    await pumpPicker(tester);
    final slow = Completer<List<Salon>>();
    search.next = slow;
    await type(tester, 'الأن');

    search.next = Completer()..complete([salon('صالون الأناقة')]);
    await type(tester, 'الأناقة');
    await tester.pumpAndSettle();
    expect(find.text('صالون الأناقة'), findsOneWidget);

    slow.complete([salon('حلاق الأندلس')]);
    await tester.pumpAndSettle();
    expect(find.text('حلاق الأندلس'), findsNothing);
    expect(find.text('صالون الأناقة'), findsOneWidget);
    expect(search.queries, ['الأن', 'الأناقة']);
  });
}

class _FakeSearch implements BarberRepository {
  final queries = <String>[];
  late Completer<List<Salon>> next;

  @override
  Future<List<Salon>> searchSalons(String query) {
    queries.add(query);
    return next.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
