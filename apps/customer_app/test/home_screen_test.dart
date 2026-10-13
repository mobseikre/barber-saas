import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/data/directory_repository.dart';
import 'package:customer_app/features/home/barber_card.dart';
import 'package:customer_app/features/home/home_screen.dart';
import 'package:customer_app/features/home/home_shell.dart';
import 'package:customer_app/features/salon/salon_screen.dart';
import 'package:customer_app/providers.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  List<String> cardNames(WidgetTester tester) => [
    for (final card in tester.widgetList<BarberCard>(find.byType(BarberCard))) card.ranked.barber.displayName,
  ];

  testWidgets('with a location, Tripoli barbers are listed nearest area first, VIPs leading', (tester) async {
    final deps = TestDeps();
    deps.directory.todayValue = {'ali': BarberToday(fromPrice: 15, hours: weekHours('ali').first)};
    await pumpPhone(tester, deps.app(const HomeShell()));

    expect(find.text('حلاقون قريبون منك'), findsOneWidget);
    expect(find.text('طرابلس'), findsOneWidget);
    expect(cardNames(tester), ['علي القماطي', 'أيمن الفيتوري', 'محمد السويحلي', 'سالم الترهوني']);
    expect(find.byType(VipBadge), findsNWidgets(2));
    expect(
      find.text(' · 0.6 كم'),
      findsWidgets,
      reason: 'the distance follows the area in its own label and is never cut',
    );
    expect(find.text('صالون الأناقة · حي الأندلس'), findsWidgets);
    for (final name in ['علي القماطي', 'أيمن الفيتوري']) {
      final text = tester.renderObject<RenderParagraph>(find.text(name));
      expect(text.didExceedMaxLines, isFalse, reason: '$name fits beside the VIP badge and the rating');
    }
    expect(find.text('من 15 د.ل'), findsOneWidget);
    expect(find.text('مفتوح الآن'), findsOneWidget);
  });

  testWidgets('without location permission it falls back to the area order and offers to enable it', (tester) async {
    final deps = TestDeps(location: FakeLocationService(const LocationResult.failed(LocationFailure.denied)));
    await pumpPhone(tester, deps.app(const HomeShell()));

    expect(find.text('اسمح بالوصول لموقعك لعرض الأقرب إليك'), findsOneWidget);
    expect(find.text('حلاقون في طرابلس'), findsOneWidget);
    expect(find.textContaining('كم'), findsNothing);
    expect(find.text('الأعلى تقييماً'), findsOneWidget, reason: 'the sort toggle stays without a location');
    expect(cardNames(tester), ['علي القماطي', 'أيمن الفيتوري', 'محمد السويحلي', 'سالم الترهوني']);

    await tester.tap(find.text('الأعلى تقييماً'));
    await tester.pumpAndSettle();
    expect(cardNames(tester).first, 'محمد السويحلي', reason: 'top rated works without a location too');
    await tester.tap(find.text('الأقرب'));
    await tester.pumpAndSettle();

    deps.location.result = const LocationResult.found(customerSpot);
    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(deps.location.calls, 2);
    expect(find.text('حلاقون قريبون منك'), findsOneWidget);
  });

  testWidgets('the city, area chips and search narrow the list', (tester) async {
    final deps = TestDeps();
    await pumpPhone(tester, deps.app(const HomeShell()));

    await tester.tap(find.text('قرقارش'));
    await tester.pumpAndSettle();
    expect(cardNames(tester), ['سالم الترهوني']);

    await tester.tap(find.text('كل المناطق'));
    await tester.enterText(find.byType(TextField), 'ستايل');
    await tester.pumpAndSettle();
    expect(cardNames(tester), ['أيمن الفيتوري']);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('طرابلس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بنغازي'));
    await tester.pumpAndSettle();
    expect(cardNames(tester), ['عمر البرعصي']);
    expect(find.text('الفويهات'), findsWidgets);
  });

  testWidgets('top rated reorders the list', (tester) async {
    final deps = TestDeps();
    await pumpPhone(tester, deps.app(const HomeShell()));

    await tester.tap(find.text('الأعلى تقييماً'));
    await tester.pumpAndSettle();

    expect(cardNames(tester).first, 'محمد السويحلي');
  });

  testWidgets('typing in the search ranks nothing again', (tester) async {
    final deps = TestDeps();
    await pumpPhone(tester, deps.app(const HomeShell()));
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final ranking = container.read(homeRankingProvider);

    await tester.enterText(find.byType(TextField), 'علي');
    await tester.pumpAndSettle();

    expect(identical(container.read(homeRankingProvider), ranking), isTrue);
    expect(cardNames(tester), ['علي القماطي']);
  });

  testWidgets('pulling down reloads the barbers', (tester) async {
    final deps = TestDeps();
    await pumpPhone(tester, deps.app(const HomeShell()));
    expect(deps.directory.barberLoads, 1);

    deps.directory.barbers = [...allListings, listing(id: 'new', name: 'حلاق جديد', lat: 32.8752, lng: 13.1146)];
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(deps.directory.barberLoads, 2);
    expect(find.text('حلاق جديد'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that brings the list back', (tester) async {
    final deps = TestDeps();
    deps.directory.barbersError = Exception('offline');
    await pumpPhone(tester, deps.app(const HomeShell()));
    expect(find.text(genericErrorMessage), findsOneWidget);
    expect(find.byType(BarberCard), findsNothing);

    deps.directory.barbersError = null;
    await tapVisible(tester, find.text('إعادة المحاولة'));

    expect(cardNames(tester), contains('علي القماطي'));
  });

  testWidgets('a city without barbers and a search without results each say so', (tester) async {
    final deps = TestDeps();
    deps.directory.barbers = [ali];
    await pumpPhone(tester, deps.app(const HomeShell()));

    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج لبحثك'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('طرابلس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بنغازي'));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد حلاقون متاحون للحجز هنا بعد'), findsOneWidget);
  });

  testWidgets('tapping a barber opens their salon page with them selected', (tester) async {
    final deps = TestDeps();
    deps.directory.team = [SalonBarber(id: 'ali', salonId: 'salon-1', displayName: 'علي القماطي', isBookable: true)];
    await pumpPhone(tester, deps.app(const HomeShell()));

    await tapVisible(tester, find.text('علي القماطي'));

    final salon = tester.widget<SalonScreen>(find.byType(SalonScreen));
    expect((salon.salonId, salon.barberId), ('salon-1', 'ali'));
  });

  testWidgets('the bottom nav shows the sign-in prompt on the account tabs for visitors', (tester) async {
    final deps = TestDeps();
    await pumpPhone(tester, deps.app(const HomeShell()));

    await tester.tap(find.text('حجوزاتي'));
    await tester.pumpAndSettle();

    expect(find.text('سجّل الدخول لترى حجوزاتك'), findsOneWidget);
  });
}
