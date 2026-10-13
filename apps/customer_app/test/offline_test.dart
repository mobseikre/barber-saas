import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/app.dart';
import 'package:customer_app/data/offline_cache.dart';
import 'package:customer_app/features/home/home_shell.dart';
import 'package:customer_app/features/salon/salon_screen.dart';

import 'support/fakes.dart';
import 'support/memory_cache_store.dart';

String jwt(String sub) => 'Bearer x.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub})))}.y';

void main() {
  group('CachingHttpClient', () {
    late MemoryCacheStore store;
    late ValueNotifier<DateTime?> status;
    late bool online;
    late int calls;
    late String body;
    late int statusCode;
    late Object failure;
    late CachingHttpClient client;

    setUp(() {
      store = MemoryCacheStore();
      status = ValueNotifier(null);
      online = true;
      calls = 0;
      body = '[{"name":"قرقارش"}]';
      statusCode = 200;
      failure = http.ClientException('no route to host');
      client = CachingHttpClient(
        MockClient((request) async {
          calls++;
          if (!online) throw failure;
          return http.Response.bytes(utf8.encode(body), statusCode, headers: {'content-type': 'application/json'});
        }),
        store,
        status: status,
        timeout: const Duration(milliseconds: 50),
        maxEntries: 3,
      );
    });

    Future<http.Response> get(String path, {String? auth}) async {
      final request = http.Request('GET', Uri.parse('http://x$path'));
      if (auth != null) request.headers['Authorization'] = auth;
      return http.Response.fromStream(await client.send(request));
    }

    test('answers from the network while it is reachable and remembers the answer', () async {
      final response = await get('/rest/v1/areas');

      expect(response.body, body);
      expect(status.value, isNull);
      expect(store.entries, hasLength(1));
    });

    test('serves the last answer when the network is unreachable and says so', () async {
      await get('/rest/v1/areas');
      online = false;

      final response = await get('/rest/v1/areas');

      expect(response.statusCode, 200);
      expect(response.body, '[{"name":"قرقارش"}]');
      expect(status.value, isNotNull);
    });

    test('goes back to the network and clears the flag as soon as it answers again', () async {
      await get('/rest/v1/areas');
      online = false;
      await get('/rest/v1/areas');
      online = true;
      body = '[{"name":"الفويهات"}]';

      final response = await get('/rest/v1/areas');

      expect(response.body, '[{"name":"الفويهات"}]');
      expect(status.value, isNull);
      online = false;
      expect((await get('/rest/v1/areas')).body, '[{"name":"الفويهات"}]', reason: 'the newest answer is the one kept');
    });

    test('a timeout falls back to the cache too', () async {
      await get('/rest/v1/areas');
      client = CachingHttpClient(
        MockClient((_) => Completer<http.Response>().future),
        store,
        status: status,
        timeout: const Duration(milliseconds: 20),
      );

      expect((await get('/rest/v1/areas')).body, body);
      expect(status.value, isNotNull);
    });

    test('an unreachable network with nothing cached keeps failing as before', () async {
      online = false;

      await expectLater(get('/rest/v1/areas'), throwsA(isA<http.ClientException>()));
      expect(status.value, isNull);
    });

    test('every query is cached on its own', () async {
      await get('/rest/v1/areas?select=*');
      online = false;

      await expectLater(get('/rest/v1/areas?select=name'), throwsA(isA<http.ClientException>()));
      expect((await get('/rest/v1/areas?select=*')).body, body);
    });

    test('a customer never reads what another account cached', () async {
      await get('/rest/v1/bookings', auth: jwt('customer-1'));
      online = false;

      await expectLater(get('/rest/v1/bookings', auth: jwt('customer-2')), throwsA(isA<http.ClientException>()));
      await expectLater(get('/rest/v1/bookings'), throwsA(isA<http.ClientException>()));
      expect((await get('/rest/v1/bookings', auth: jwt('customer-1'))).body, body);
    });

    test('errors from the server are passed on and never cached', () async {
      statusCode = 401;
      body = '{"message":"JWT expired"}';

      final response = await get('/rest/v1/bookings', auth: jwt('customer-1'));

      expect(response.statusCode, 401);
      expect(store.entries, isEmpty);
      expect(status.value, isNull);
    });

    test('only reads of the data API are cached', () async {
      final post = await client.send(http.Request('POST', Uri.parse('http://x/rest/v1/rpc/create_booking')));
      await post.stream.drain<void>();
      await get('/auth/v1/user');
      await get('/storage/v1/object/public/avatars/a.png');

      expect(calls, 3);
      expect(store.entries, isEmpty);
      online = false;
      await expectLater(get('/auth/v1/user'), throwsA(isA<http.ClientException>()));
    });

    test('the oldest entries go first when the cache is full', () async {
      for (final n in ['a', 'b', 'c', 'd']) {
        await get('/rest/v1/$n');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      online = false;

      expect(store.entries, hasLength(3));
      await expectLater(get('/rest/v1/a'), throwsA(isA<http.ClientException>()));
      expect((await get('/rest/v1/d')).body, body);
    });

    test('remembers when each answer was saved, in UTC, and reports the oldest one on screen', () async {
      await get('/rest/v1/areas');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await get('/rest/v1/cities');
      final saved = {
        for (final k in store.entries.keys)
          k: DateTime.parse((jsonDecode(store.entries[k]!) as Map<String, dynamic>)['at'] as String),
      };
      expect(saved.values.every((t) => t.isUtc), isTrue);
      online = false;

      await get('/rest/v1/cities');
      final cities = saved.entries.firstWhere((e) => e.key.endsWith('cities')).value;
      expect(status.value, cities);
      await get('/rest/v1/areas');
      expect(status.value, saved.entries.firstWhere((e) => e.key.endsWith('areas')).value);
    });

    test('signing out also clears the offline flag', () async {
      await get('/rest/v1/areas');
      online = false;
      await get('/rest/v1/areas');
      expect(status.value, isNotNull);

      await client.clearUserEntries();

      expect(status.value, isNull);
    });

    test('signing out forgets signed-in data and keeps what visitors see', () async {
      await get('/rest/v1/areas');
      await get('/rest/v1/bookings', auth: jwt('customer-1'));

      await client.clearUserEntries();
      online = false;

      expect((await get('/rest/v1/areas')).body, body);
      await expectLater(get('/rest/v1/bookings', auth: jwt('customer-1')), throwsA(isA<http.ClientException>()));
    });
  });

  group('the offline notice', () {
    useTestClock(testNow);

    testWidgets('the home screen shows it while its data comes from the cache', (tester) async {
      final deps = TestDeps();
      await pumpPhone(tester, deps.app(const HomeShell()));
      expect(find.textContaining('غير متصل'), findsNothing);

      deps.offline.value = testNow;
      await tester.pumpAndSettle();

      expect(find.text('غير متصل · آخر تحديث 10:00 ص'), findsOneWidget);
      expect(find.text('علي القماطي'), findsOneWidget);
    });

    testWidgets('the salon page shows it too', (tester) async {
      final deps = TestDeps();
      deps.directory.team = [SalonBarber(id: 'ali', salonId: 'salon-1', displayName: 'علي القماطي', isBookable: true)];
      deps.offline.value = testNow;
      await pumpPhone(tester, deps.app(const SalonScreen(salonId: 'salon-1', barberId: 'ali')));

      expect(find.textContaining('غير متصل'), findsOneWidget);
      expect(find.text('اختر حلاقك'), findsOneWidget);
    });

    testWidgets('it is a small pill, not a banner', (tester) async {
      final deps = TestDeps();
      deps.offline.value = testNow;
      await pumpPhone(tester, deps.app(const HomeShell()));

      final size = tester.getSize(
        find.ancestor(of: find.textContaining('غير متصل'), matching: find.byType(Container)).first,
      );
      expect(size.height, AppSizes.badge);
      expect(size.width, lessThan(390 - 2 * AppSpacing.screen));
    });
  });

  group('coming back online', () {
    useTestClock(testNow);

    Future<TestDeps> openApp(WidgetTester tester) async {
      final deps = TestDeps();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(deps.connectivity.close);
      await tester.pumpWidget(
        ProviderScope(retry: (_, _) => null, overrides: deps.overrides, child: const CustomerApp()),
      );
      await tester.pumpAndSettle();
      return deps;
    }

    testWidgets('the data is loaded again when the connection returns while showing cached data', (tester) async {
      final deps = await openApp(tester);
      expect(deps.directory.barberLoads, 1);

      deps.offline.value = testNow;
      deps.connectivity.add(false);
      await tester.pumpAndSettle();
      expect(deps.directory.barberLoads, 1, reason: 'losing the connection reloads nothing');

      deps.connectivity.add(true);
      await tester.pumpAndSettle();

      expect(deps.directory.barberLoads, 2);
    });

    testWidgets('a screen that failed with nothing cached loads again when the connection returns', (tester) async {
      final deps = TestDeps();
      deps.directory.barbersError = Exception('offline');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(deps.connectivity.close);
      await tester.pumpWidget(
        ProviderScope(retry: (_, _) => null, overrides: deps.overrides, child: const CustomerApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text(genericErrorMessage), findsOneWidget);
      expect(deps.offline.value, isNull, reason: 'there was nothing cached to show');

      deps.connectivity.add(false);
      await tester.pumpAndSettle();
      deps.directory.barbersError = null;
      deps.connectivity.add(true);
      await tester.pumpAndSettle();

      expect(find.text('علي القماطي'), findsOneWidget);
    });

    testWidgets('a connection change while the data is fresh reloads nothing', (tester) async {
      final deps = await openApp(tester);

      deps.connectivity.add(true);
      await tester.pumpAndSettle();

      expect(deps.directory.barberLoads, 1);
    });
  });
}
