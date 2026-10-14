import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart' show fieldLabelled;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthClientOptions, AuthFlowType;
import 'package:uuid/uuid.dart';

import 'package:customer_app/app.dart';
import 'package:customer_app/data/offline_cache.dart';
import 'package:customer_app/providers.dart';

// Runs the real app against the local Supabase stack after `supabase db reset`:
//   flutter test integration_test -d <emulator> --dart-define-from-file=env/android.json
// Add --dart-define=WATCH=true to pause after every step and follow along on the device.
// Each test deletes the bookings it made, so the suite can run again without a reset.

const _watch = bool.fromEnvironment('WATCH');
const _aliId = '30000000-0000-0000-0000-000000000001';
const _walidId = '30000000-0000-0000-0000-000000000008';
const _slotPattern = r'^\d{1,2}:\d{2} [صم]$';

class _FixedLocation implements LocationService {
  const _FixedLocation(this.result);

  final LocationResult result;

  @override
  Future<LocationResult> current() async => result;
}

const _inTripoli = LocationResult.found(LatLng(32.8720, 13.1100));

/// The network as the app sees it; switched off to play a lost connection.
class _SwitchableClient extends http.BaseClient {
  _SwitchableClient(this._inner);

  final http.Client _inner;
  var online = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!online) throw http.ClientException('offline');
    return _inner.send(request);
  }
}

final _network = _SwitchableClient(http.Client());
final _cacheStore = PreferencesCacheStore();
final _cache = CachingHttpClient(_network, _cacheStore);

String _randomPhone() => '0917${Random().nextInt(900000) + 100000}';

/// The first day after today that علي works (he takes Friday off), as the label on its day tile.
({DateTime day, String label}) _bookingDay() {
  for (var i = 1; i < AppConstants.bookingDays; i++) {
    final day = AppTime.at(AppTime.now().add(Duration(days: i)), 12, 0);
    if (day.weekday != DateTime.friday) {
      return (day: day, label: i == 1 ? 'غداً' : ArabicFormat.weekday(day));
    }
  }
  throw StateError('no working day');
}

Future<void> _pause(WidgetTester tester) async {
  if (_watch) await tester.pump(const Duration(milliseconds: 900));
}

/// Pumps until [finder] matches; the app talks to a real server, so pumpAndSettle is not enough.
Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
      throw TestFailure('Timed out waiting for $finder; on screen: $texts');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await _pause(tester);
}

/// Scrolls [finder] to the middle of the screen; at the top edge it sits under the status bar,
/// where iOS takes the tap to scroll back to the top.
Future<void> _scrollIntoView(WidgetTester tester, Finder finder) =>
    Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await _scrollIntoView(tester, finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await _pause(tester);
}

/// Types [text] into [field] and fails the test when the field does not end up holding it.
Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await _waitFor(tester, field);
  final editable = find.descendant(of: field, matching: find.byType(EditableText));
  await _scrollIntoView(tester, field);
  await tester.pump(const Duration(milliseconds: 300));
  String? typed;
  for (var attempt = 0; attempt < 3 && typed != text; attempt++) {
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 600));
    await _scrollIntoView(tester, field);
    await tester.pump(const Duration(milliseconds: 300));
    typed = editable.evaluate().map((e) => (e.widget as EditableText).controller.text).firstOrNull;
  }
  if (typed != text) throw TestFailure('Typed "$text" into $field but it holds "$typed"');
  await _pause(tester);
}

Future<void> _type(WidgetTester tester, String label, String text) => _enter(tester, fieldLabelled(label), text);

Finder _slots() => find.byWidgetPredicate((w) => w is Text && RegExp(_slotPattern).hasMatch(w.data ?? ''));

Finder _button(String label) => find.ancestor(of: find.text(label), matching: find.byType(FilledButton));

Future<void> _launch(
  WidgetTester tester, {
  LocationResult location = _inTripoli,
  Stream<bool> connectivity = const Stream.empty(),
  Stream<Uri>? links,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        locationServiceProvider.overrideWithValue(_FixedLocation(location)),
        connectivityProvider.overrideWith((_) => connectivity),
        if (links != null) appLinksProvider.overrideWithValue(links),
      ],
      child: const CustomerApp(),
    ),
  );
  await _waitFor(tester, find.text('علي القماطي'));
}

/// From home to a chosen haircut slot with علي; returns the slot label.
Future<String> _chooseHaircut(WidgetTester tester) async {
  await _tap(tester, find.text('علي القماطي'));
  await _waitFor(tester, find.text('خدمات وأسعار علي'));
  await _tap(tester, find.text('احجز الآن'));
  await _tap(tester, find.textContaining('قص شعر'));
  await _tap(tester, find.text(_bookingDay().label));
  await _waitFor(tester, _slots());
  final label = (tester.widget<Text>(_slots().first)).data!;
  await _tap(tester, _slots().first);
  return label;
}

Future<void> _confirmSigningIn(WidgetTester tester, String phone) async {
  await _tap(tester, _button('تأكيد الحجز'));
  await _waitFor(tester, find.text('نسيت كلمة المرور؟'));
  await _type(tester, 'رقم الهاتف', phone);
  await _type(tester, 'كلمة المرور', 'password123');
  await _tap(tester, _button('تسجيل الدخول'));
}

Future<void> _waitUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) throw TestFailure('Timed out waiting for $finder to go');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _pause(tester);
}

Future<void> _openTab(WidgetTester tester, String label) =>
    _tap(tester, find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)));

Future<void> _signInFromAccount(WidgetTester tester, String phone) async {
  await _openTab(tester, 'حسابي');
  await _tap(tester, _button('تسجيل الدخول'));
  await _waitFor(tester, find.text('نسيت كلمة المرور؟'));
  await _type(tester, 'رقم الهاتف', phone);
  await _type(tester, 'كلمة المرور', 'password123');
  await _tap(tester, _button('تسجيل الدخول'));
  await _waitFor(tester, find.text('تسجيل الخروج'));
}

/// Signs up a new customer while booking علي's first free haircut slot, and returns to home.
Future<void> _signUpAndBook(WidgetTester tester) async {
  await _launch(tester);
  await _chooseHaircut(tester);
  await _tap(tester, _button('تأكيد الحجز'));
  await _tap(tester, find.text('إنشاء حساب'));
  await _type(tester, 'الاسم', 'زبون الاختبار');
  await _type(tester, 'رقم الهاتف', _randomPhone());
  await _type(tester, 'كلمة المرور', 'password123');
  await _tap(tester, _button('إنشاء الحساب'));
  await _waitFor(tester, find.text('تم تأكيد حجزك'));
  await _tap(tester, find.text('العودة للرئيسية'));
}

Finder _cancelButton() => find.widgetWithText(InkWell, 'إلغاء الحجز');

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
  await tester.pump(const Duration(milliseconds: 300));
}

SupabaseClient _client() => SupabaseClient(
  SupabaseConfig.url,
  SupabaseConfig.publishableKey,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

/// The seeded admin, who may read and delete every booking.
Future<SupabaseClient> _admin() async {
  final admin = _client();
  await admin.auth.signInWithPassword(
    email: phoneToAuthEmail(normalizeLibyanPhone('0910000001')!),
    password: 'password123',
  );
  return admin;
}

/// Bookings made through create_booking carry an idempotency key; the seed's do not.
Future<Set<String>> _appBookingIds(SupabaseClient admin) async => {
  for (final r in await admin.from('bookings').select('id').not('idempotency_key', 'is', null)) r['id'] as String,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient admin;
  late Set<String> existingBookings;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    for (final key in await _cacheStore.keys()) {
      await _cacheStore.delete(key);
    }
    await initSupabase(httpClient: _cache);
    admin = await _admin();
  });

  tearDownAll(() => admin.dispose());

  setUp(() async {
    _network.online = true;
    offlineStatus.value = null;
    AppTime.clock = DateTime.now;
    await _cache.clearUserEntries();
    await supabase.auth.signOut();
    existingBookings = await _appBookingIds(admin);
  });

  tearDown(() async {
    AppTime.clock = DateTime.now;
    _network.online = true;
    final made = (await _appBookingIds(admin)).difference(existingBookings);
    if (made.isNotEmpty) await admin.from('bookings').delete().inFilter('id', made.toList());
  });

  testWidgets('a visitor browses home, opens a barber and sees the salon page', (tester) async {
    await _launch(tester);

    expect(find.text('حلاقون قريبون منك'), findsOneWidget);
    expect(find.textContaining('كم'), findsWidgets);

    await _tap(tester, find.text('علي القماطي'));
    await _waitFor(tester, find.text('خدمات وأسعار علي'));

    expect(find.text('صالون الأناقة'), findsOneWidget);
    expect(find.text('اختر حلاقك'), findsOneWidget);
    expect(find.text('محمد السويحلي'), findsOneWidget);
    expect(find.text('غير متاح للحجز'), findsOneWidget);
    expect(find.text('احجز الآن'), findsOneWidget);
  });

  testWidgets('a QR link to a barber who cannot be booked opens the salon without choosing someone else', (
    tester,
  ) async {
    final links = StreamController<Uri>();
    addTearDown(links.close);
    await _launch(tester, links: links.stream);

    links.add(barberLink(_walidId));
    await _waitFor(tester, find.text('وليد الشريف غير متاح للحجز حالياً'));

    expect(find.text('صالون الأناقة'), findsOneWidget);
    expect(find.text('اختر حلاقاً آخر من الصالون'), findsOneWidget);
    expect(find.text('اختر حلاقاً متاحاً'), findsOneWidget);
    expect(find.textContaining('خدمات وأسعار'), findsNothing);
    expect(tester.widget<FilledButton>(_button('احجز الآن')).onPressed, isNull);

    await _tap(tester, find.text('علي القماطي'));
    await _waitFor(tester, find.text('خدمات وأسعار علي'));
    expect(find.text('مع علي'), findsOneWidget);
    expect(tester.widget<FilledButton>(_button('احجز الآن')).onPressed, isNotNull);
  });

  testWidgets('a visitor signs up at confirm and the same booking is confirmed', (tester) async {
    await _launch(tester);
    final slot = await _chooseHaircut(tester);

    await _tap(tester, _button('تأكيد الحجز'));
    await _tap(tester, find.text('إنشاء حساب'));
    await _type(tester, 'الاسم', 'زائر الاختبار');
    await _type(tester, 'رقم الهاتف', _randomPhone());
    await _type(tester, 'كلمة المرور', 'password123');
    await _tap(tester, _button('إنشاء الحساب'));

    await _waitFor(tester, find.text('تم تأكيد حجزك'));
    expect(find.text('علي القماطي'), findsOneWidget);
    expect(find.text('قص شعر'), findsOneWidget);
    expect(find.text(slot), findsOneWidget);
    expect(find.text(ArabicFormat.dayDate(_bookingDay().day)), findsOneWidget);
  });

  testWidgets('0925554410 books once, then hits the upcoming booking limit', (tester) async {
    await _launch(tester);
    await _chooseHaircut(tester);
    await _confirmSigningIn(tester, '0925554410');
    await _waitFor(tester, find.text('تم تأكيد حجزك'));

    await _tap(tester, find.text('العودة للرئيسية'));
    await _chooseHaircut(tester);
    await _tap(tester, _button('تأكيد الحجز'));

    await _waitFor(tester, find.textContaining('وصلت إلى الحد الأقصى للحجوزات القادمة'));
    expect(find.text('تم تأكيد حجزك'), findsNothing);
  });

  testWidgets('the blocked customer 0941207788 is refused', (tester) async {
    await _launch(tester);
    await _chooseHaircut(tester);
    await _confirmSigningIn(tester, '0941207788');

    await _waitFor(tester, find.text('تم إيقاف الحجز لحسابك بعد 3 مرات عدم حضور. تواصل مع الدعم'));
    expect(find.text('تم تأكيد حجزك'), findsNothing);
  });

  testWidgets('a slot taken by someone else is explained and the times reload', (tester) async {
    await _launch(tester);
    final slot = await _chooseHaircut(tester);

    final other = _client();
    await other.auth.signUp(
      email: phoneToAuthEmail(normalizeLibyanPhone(_randomPhone())!),
      password: 'password123',
      data: {'full_name': 'زبون آخر', 'role': 'customer'},
    );
    final haircut = await other.from('service_catalog').select('id').eq('code', 'haircut').single();
    final taken = (await BookingRepository(
      other,
    ).availableSlots(barberId: _aliId, day: _bookingDay().day, durationMin: 30)).first;
    expect(ArabicFormat.time(taken.startsAt), slot, reason: 'the other customer takes the slot on screen');
    await BookingRepository(other).createBooking(
      barberId: _aliId,
      serviceId: haircut['id'] as String,
      startsAt: taken.startsAt,
      idempotencyKey: const Uuid().v4(),
    );
    await other.dispose();

    await _confirmSigningIn(tester, '0911002030');

    await _waitFor(tester, find.text('هذا الموعد لم يعد متاحاً، اختر وقتاً آخر'));
    await _waitFor(tester, _slots());
    expect(find.text(slot), findsNothing, reason: 'the reloaded times no longer offer it');
    expect(find.text('اختر الخدمة والوقت'), findsOneWidget);
  });

  testWidgets('without location permission the city and area fallback appears', (tester) async {
    await _launch(tester, location: const LocationResult.failed(LocationFailure.denied));

    expect(find.text('اسمح بالوصول لموقعك لعرض الأقرب إليك'), findsOneWidget);
    expect(find.text('حلاقون في طرابلس'), findsOneWidget);
    expect(find.text('كل المناطق'), findsOneWidget);
    expect(find.textContaining('كم'), findsNothing);

    await _tap(tester, find.text('قرقارش'));
    expect(find.text('سالم الترهوني'), findsOneWidget);
    expect(find.text('علي القماطي'), findsNothing);
  });

  testWidgets('a customer cancels a booking after confirming, and it moves to the past list', (tester) async {
    await _signUpAndBook(tester);

    await _openTab(tester, 'حجوزاتي');
    await _waitFor(tester, find.text('القادمة (1)'));
    expect(find.text('صالون الأناقة'), findsOneWidget);

    await _tap(tester, _cancelButton());
    await _waitFor(tester, find.text('إلغاء الحجز؟'));
    await _tap(tester, find.text('رجوع'));
    expect(await supabase.from('bookings').select('status'), [
      {'status': 'confirmed'},
    ], reason: 'going back cancels nothing');

    await _tap(tester, _cancelButton());
    await _tap(tester, find.text('نعم، إلغاء الحجز'));
    await _waitFor(tester, find.text('القادمة (0)'));
    expect(find.text('تم إلغاء الحجز'), findsOneWidget);
    expect(await supabase.from('bookings').select('status'), [
      {'status': 'cancelled'},
    ]);

    await _tap(tester, find.text('السابقة'));
    expect(find.text('ملغي'), findsOneWidget);
    expect(_cancelButton(), findsNothing);
  });

  testWidgets('inside the cancellation window the cancellation is refused with an explanation', (tester) async {
    await _signUpAndBook(tester);
    final row = await supabase.from('bookings').select('time_range').single();
    final start = parseTstzRange(row['time_range'] as String).start;
    AppTime.clock = () => start.subtract(const Duration(minutes: 90));

    await _openTab(tester, 'حجوزاتي');
    await _waitFor(tester, find.text('القادمة (1)'));
    await _tap(tester, _cancelButton());

    await _waitFor(tester, find.text('لا يمكن إلغاء هذا الحجز'));
    expect(find.textContaining('يمكن إلغاء الحجز حتى ساعتين قبل الموعد فقط'), findsOneWidget);
    expect(find.text('إلغاء الحجز؟'), findsNothing);

    await _tap(tester, find.text('حسناً'));
    expect(find.text('القادمة (1)'), findsOneWidget);
    expect(await supabase.from('bookings').select('status'), [
      {'status': 'confirmed'},
    ]);
  });

  testWidgets('0911002030 rates a completed booking once, with stars, tags and a comment', (tester) async {
    await _launch(tester);
    await _signInFromAccount(tester, '0911002030');
    final userId = supabase.auth.currentUser!.id;

    try {
      await _openTab(tester, 'حجوزاتي');
      await _tap(tester, find.text('السابقة'));
      await _tap(tester, find.text('قيّم'));
      await _waitFor(tester, find.text('كيف كانت زيارتك؟'));

      expect(tester.widget<FilledButton>(_button('إرسال التقييم')).onPressed, isNull);
      await _tap(tester, find.byTooltip('جيد جداً'));
      expect(find.text('جيد جداً'), findsOneWidget);
      await _tap(tester, find.text('النظافة'));
      await _tap(tester, find.text('جودة القص'));
      await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
      await _enter(tester, find.byType(TextField), 'قص ممتاز ومواعيد دقيقة');
      await _tap(tester, _button('إرسال التقييم'));

      await _waitFor(tester, find.text('شكراً لتقييمك'));
      expect(find.text('كيف كانت زيارتك؟'), findsNothing);
      final reviews = await supabase.from('reviews').select().eq('customer_id', userId);
      expect(reviews, hasLength(1));
      expect(reviews.single['rating'], 4);
      expect(reviews.single['tags'], ['جودة القص', 'النظافة']);
      expect(reviews.single['comment'], 'قص ممتاز ومواعيد دقيقة');
      await _waitFor(tester, find.text('4'));
      expect(find.text('قيّم'), findsNWidgets(4), reason: 'the other four completed bookings can still be rated');

      final bookingId = reviews.single['booking_id'] as String;
      await expectLater(
        supabase.from('reviews').insert({'booking_id': bookingId, 'customer_id': userId, 'rating': 5}),
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23505')),
        reason: 'a booking is rated once',
      );
    } finally {
      await admin.from('reviews').delete().eq('customer_id', userId);
    }
  });

  testWidgets('without a network the cached bookings and home show with the offline notice, then refresh', (
    tester,
  ) async {
    final connectivity = StreamController<bool>.broadcast();
    addTearDown(connectivity.close);
    await _launch(tester, connectivity: connectivity.stream);
    await _signInFromAccount(tester, '0911002030');
    await _openTab(tester, 'حجوزاتي');
    await _tap(tester, find.text('السابقة'));
    await _waitFor(tester, find.text('مكتمل'));
    expect(find.textContaining('غير متصل'), findsNothing);

    _network.online = false;
    connectivity.add(false);
    await _pullToRefresh(tester);
    await _waitFor(tester, find.textContaining('غير متصل'));
    expect(find.text('مكتمل'), findsWidgets, reason: 'the bookings stay on screen from the cache');

    await _openTab(tester, 'الرئيسية');
    await _pullToRefresh(tester);
    await _waitFor(tester, find.text('علي القماطي'));
    expect(find.textContaining('غير متصل'), findsOneWidget);

    _network.online = true;
    connectivity.add(true);
    await _waitUntilGone(tester, find.textContaining('غير متصل'));
    expect(find.text('علي القماطي'), findsOneWidget);
  });

  testWidgets('starting the app without a network shows the cached home with the offline notice', (tester) async {
    await _launch(tester);
    await _waitFor(tester, find.text('علي القماطي'));
    expect(find.textContaining('غير متصل'), findsNothing);

    _network.online = false;
    await _launch(tester);

    expect(find.textContaining('غير متصل'), findsOneWidget);
    expect(find.text('حلاقون قريبون منك'), findsOneWidget);
  });

  testWidgets('after an admin reset the customer picks a new password before anything else, then continues', (
    tester,
  ) async {
    final phone = normalizeLibyanPhone(_randomPhone())!;
    final newcomer = _client();
    await newcomer.auth.signUp(
      email: phoneToAuthEmail(phone),
      password: 'password123',
      data: {'full_name': 'زبون إعادة التعيين', 'phone': phone, 'role': 'customer'},
    );
    final id = newcomer.auth.currentUser!.id;
    await newcomer.dispose();
    final reset = await admin.functions.invoke('admin-reset-password', body: {'profile_id': id});
    final temporary = (reset.data as Map)['temporary_password'] as String;

    await _launch(tester);
    await _openTab(tester, 'حسابي');
    await _tap(tester, _button('تسجيل الدخول'));
    await _waitFor(tester, find.text('نسيت كلمة المرور؟'));
    await _type(tester, 'رقم الهاتف', '0${phone.substring(3)}');
    await _type(tester, 'كلمة المرور', temporary);
    await _tap(tester, _button('تسجيل الدخول'));

    await _waitFor(tester, find.text('اختر كلمة مرور جديدة'));
    expect(find.text('تسجيل الخروج'), findsOneWidget, reason: 'only the change screen is on top');
    await _type(tester, 'كلمة المرور الجديدة', 'NewPass-2026');
    await _type(tester, 'تأكيد كلمة المرور الجديدة', 'NewPass-2026');
    await _tap(tester, _button('حفظ والمتابعة'));

    await _waitUntilGone(tester, find.text('اختر كلمة مرور جديدة'));
    await _waitFor(tester, find.text('زبون إعادة التعيين'));
    expect(supabase.auth.currentUser!.appMetadata['must_change_password'], isNull);

    final again = _client();
    await again.auth.signInWithPassword(email: phoneToAuthEmail(phone), password: 'NewPass-2026');
    expect(again.auth.currentUser!.appMetadata['must_change_password'], isNull);
    await again.dispose();
  });
}
