import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/data/directory_repository.dart';
import 'package:customer_app/data/my_bookings_repository.dart';
import 'package:customer_app/providers.dart';

/// Monday 12 October 2026, 10:00 in Tripoli.
final testNow = DateTime.utc(2026, 10, 12, 8);

final tripoli = City(id: 'tripoli', name: 'طرابلس');
final benghazi = City(id: 'benghazi', name: 'بنغازي', sortOrder: 2);
final testAreas = [
  Area(id: 'andalus', cityId: 'tripoli', name: 'حي الأندلس', sortOrder: 1),
  Area(id: 'gargaresh', cityId: 'tripoli', name: 'قرقارش', sortOrder: 2),
  Area(id: 'fwayhat', cityId: 'benghazi', name: 'الفويهات', sortOrder: 1),
];

/// Close to the Andalus salons.
const customerSpot = LatLng(32.8720, 13.1100);

BarberListing listing({
  required String id,
  required String name,
  String salonId = 'salon-1',
  String salonName = 'صالون الأناقة',
  String? areaId = 'andalus',
  bool vip = false,
  double rating = 4.5,
  int ratingCount = 10,
  double? lat,
  double? lng,
  bool bookable = true,
  String? phone = '218912345678',
}) => BarberListing(
  id: id,
  salonId: salonId,
  displayName: name,
  isVip: vip,
  ratingAvg: rating,
  ratingCount: ratingCount,
  isBookable: bookable,
  phone: phone,
  salonName: salonName,
  areaId: areaId,
  latitude: lat,
  longitude: lng,
);

final ali = listing(
  id: 'ali',
  name: 'علي القماطي',
  vip: true,
  rating: 4.8,
  ratingCount: 212,
  lat: 32.8752,
  lng: 13.1146,
);
final mohamed = listing(id: 'mohamed', name: 'محمد السويحلي', rating: 4.9, ratingCount: 64, lat: 32.8752, lng: 13.1146);
final ayman = listing(
  id: 'ayman',
  name: 'أيمن الفيتوري',
  salonId: 'salon-3',
  salonName: 'ستايل مان',
  vip: true,
  rating: 4.6,
  lat: 32.8697,
  lng: 13.1022,
);
final salem = listing(
  id: 'salem',
  name: 'سالم الترهوني',
  salonId: 'salon-2',
  salonName: 'حلاق الملوك',
  areaId: 'gargaresh',
  rating: 4.7,
  lat: 32.8648,
  lng: 13.1366,
);
final omar = listing(
  id: 'omar',
  name: 'عمر البرعصي',
  salonId: 'salon-5',
  salonName: 'صالون النخبة',
  areaId: 'fwayhat',
  rating: 4.8,
  lat: 32.0921,
  lng: 20.0905,
);

final allListings = [ali, mohamed, ayman, salem, omar];

BarberService service(String id, String name, double price, int minutes, {String barberId = 'ali'}) =>
    BarberService(barberId: barberId, serviceId: id, price: price, durationMin: minutes, nameAr: name);

final haircut = service('haircut', 'قص شعر', 25, 30);
final beard = service('beard', 'لحية', 15, 20);

List<WorkingHours> weekHours(String barberId, {int dayOff = 5}) => [
  for (var d = 0; d < 7; d++)
    WorkingHours(
      barberId: barberId,
      weekday: d,
      opensAt: const TimeOfDay(hour: 10, minute: 0),
      closesAt: const TimeOfDay(hour: 22, minute: 0),
      isClosed: d == dayOff,
    ),
];

class FakeDirectoryRepo implements DirectoryRepository {
  FakeDirectoryRepo({List<BarberListing>? barbers}) : barbers = barbers ?? allListings;

  List<BarberListing> barbers;
  List<SalonBarber> team = [];
  List<SalonDayHours> hours = [];
  List<DayClosure> closureList = [];
  Map<String, BarberToday> todayValue = {};

  var barberLoads = 0;
  Object? barbersError;
  Object? teamError;

  @override
  Future<List<BarberListing>> bookableBarbers() async {
    barberLoads++;
    if (barbersError != null) throw barbersError!;
    return [
      for (final b in barbers)
        if (b.isBookable) b,
    ];
  }

  @override
  Future<List<BarberListing>> salonListings(String salonId) async => [
    for (final b in barbers)
      if (b.salonId == salonId) b,
  ];

  @override
  Future<String?> salonOfBarber(String barberId) async {
    if (barbersError != null) throw barbersError!;
    return barbers.where((b) => b.id == barberId).firstOrNull?.salonId;
  }

  @override
  Future<List<SalonBarber>> salonBarbers(String salonId) async {
    if (teamError != null) throw teamError!;
    return team;
  }

  @override
  Future<List<SalonDayHours>> salonHours(String salonId) async => hours;

  @override
  Future<Map<String, BarberToday>> today(List<String> barberIds, DateTime now) async => todayValue;

  @override
  Future<List<DayClosure>> closures(String barberId, {required DateTime from, required DateTime to}) async =>
      closureList;
}

class FakeBarberRepo implements BarberRepository {
  Map<String, List<BarberService>> services = {
    'ali': [haircut, beard],
  };
  Map<String, List<WorkingHours>> hours = {'ali': weekHours('ali')};

  @override
  Future<List<City>> cities() async => [tripoli, benghazi];

  @override
  Future<List<Area>> areas() async => testAreas;

  Object? servicesError;

  @override
  Future<List<BarberService>> servicesOf(String barberId) async {
    if (servicesError != null) throw servicesError!;
    return services[barberId] ?? const [];
  }

  @override
  Future<List<WorkingHours>> workingHoursOf(String barberId) async => hours[barberId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves free slots and records every create_booking call with its idempotency key.
class FakeBookingRepo implements BookingRepository {
  List<TimeSlot> Function(String date, int durationMin) slots = (date, duration) => [
    for (final h in [11, 12, 17])
      TimeSlot(
        startsAt: AppTime.at(DateTime.parse('${date}T12:00:00Z'), h, 30),
        endsAt: AppTime.at(DateTime.parse('${date}T12:00:00Z'), h, 30).add(Duration(minutes: duration)),
      ),
  ];
  final slotRequests = <String>[];
  final created = <({String barberId, String serviceId, DateTime startsAt, String key})>[];

  /// Errors thrown by the next create_booking calls, in order.
  final errors = <Object>[];
  final cancelled = <String>[];
  Object? cancelError;
  Completer<void>? cancelGate;
  void Function(String bookingId)? onCancel;

  @override
  Future<List<TimeSlot>> availableSlots({
    required String barberId,
    required DateTime day,
    required int durationMin,
  }) async {
    slotRequests.add('${dbDate(day)}:$durationMin');
    return slots(dbDate(day), durationMin);
  }

  @override
  Future<Booking> createBooking({
    required String barberId,
    required String serviceId,
    required DateTime startsAt,
    required String idempotencyKey,
  }) async {
    created.add((barberId: barberId, serviceId: serviceId, startsAt: startsAt, key: idempotencyKey));
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return Booking(
      id: 'booking-${created.length}',
      barberId: barberId,
      customerId: 'customer-1',
      serviceId: serviceId,
      price: 25,
      durationMin: 30,
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(minutes: 30)),
      status: BookingStatus.confirmed,
      source: BookingSource.app,
      createdAt: startsAt,
    );
  }

  @override
  Future<Booking> cancel(String bookingId, {BarberCancelReason? reason, String? note}) async {
    await cancelGate?.future;
    if (cancelError != null) throw cancelError!;
    cancelled.add(bookingId);
    onCancel?.call(bookingId);
    return Booking(
      id: bookingId,
      barberId: 'ali',
      serviceId: 'haircut',
      price: 25,
      durationMin: 30,
      startsAt: testNow,
      endsAt: testNow,
      status: BookingStatus.cancelled,
      source: BookingSource.app,
      createdAt: testNow,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef SentReview = ({String bookingId, int rating, List<String> tags, String? comment});

class FakeMyBookingsRepo implements MyBookingsRepository {
  List<MyBooking> items = [];
  final reviews = <SentReview>[];
  var loads = 0;
  Object? loadError;
  Object? reviewError;

  void markCancelled(String bookingId) => items = [
    for (final i in items)
      if (i.booking.id == bookingId) _cancelled(i) else i,
  ];

  @override
  Future<List<MyBooking>> load(String customerId) async {
    loads++;
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<void> submitReview({
    required String customerId,
    required String bookingId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    if (reviewError != null) throw reviewError!;
    final text = comment?.trim() ?? '';
    reviews.add((bookingId: bookingId, rating: rating, tags: tags, comment: text.isEmpty ? null : text));
    items = [
      for (final i in items)
        if (i.booking.id == bookingId) i.withRating(rating) else i,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MyBooking _cancelled(MyBooking i) {
  final b = i.booking;
  return MyBooking(
    booking: Booking(
      id: b.id,
      barberId: b.barberId,
      customerId: b.customerId,
      serviceId: b.serviceId,
      serviceName: b.serviceName,
      price: b.price,
      durationMin: b.durationMin,
      startsAt: b.startsAt,
      endsAt: b.endsAt,
      status: BookingStatus.cancelled,
      source: b.source,
      createdAt: b.createdAt,
    ),
    barberName: i.barberName,
    salonName: i.salonName,
    latitude: i.latitude,
    longitude: i.longitude,
    rating: i.rating,
  );
}

/// A booking of the signed-in customer; [startsIn] counts from [testNow].
MyBooking myBooking({
  String id = 'booking-1',
  Duration startsIn = const Duration(days: 3),
  BookingStatus status = BookingStatus.confirmed,
  int? rating,
  String salon = 'صالون الأناقة',
  String barber = 'علي القماطي',
  String service = 'قص شعر',
  double price = 25,
  double? latitude = 32.8752,
  double? longitude = 13.1146,
}) {
  final start = AppTime.from(testNow.add(startsIn));
  return MyBooking(
    booking: Booking(
      id: id,
      barberId: 'ali',
      customerId: 'customer-1',
      serviceId: 'haircut',
      serviceName: service,
      price: price,
      durationMin: 30,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 30)),
      status: status,
      source: BookingSource.app,
      createdAt: testNow,
    ),
    barberName: barber,
    salonName: salon,
    latitude: latitude,
    longitude: longitude,
    rating: rating,
  );
}

PostgrestException rpcError(String code) => PostgrestException(message: code, code: 'P0001');

class TestDeps {
  TestDeps({FakeAuthRepo? auth, FakeLocationService? location})
    : auth = auth ?? FakeAuthRepo(),
      location = location ?? FakeLocationService(const LocationResult.found(customerSpot)) {
    bookings.onCancel = myBookings.markCancelled;
  }

  final FakeAuthRepo auth;
  final FakeLocationService location;
  final directory = FakeDirectoryRepo();
  final barbers = FakeBarberRepo();
  final bookings = FakeBookingRepo();
  final myBookings = FakeMyBookingsRepo();
  final offline = ValueNotifier<DateTime?>(null);
  final connectivity = StreamController<bool>.broadcast();
  final push = FakePushMessaging();
  final deviceTokens = FakeDeviceTokenRepository();
  final links = StreamController<Uri>.broadcast();
  Uri? launchLink;

  late final overrides = [
    authRepositoryProvider.overrideWithValue(auth),
    locationServiceProvider.overrideWithValue(location),
    directoryRepositoryProvider.overrideWithValue(directory),
    barberRepositoryProvider.overrideWithValue(barbers),
    bookingRepositoryProvider.overrideWithValue(bookings),
    myBookingsRepositoryProvider.overrideWithValue(myBookings),
    offlineStatusProvider.overrideWithValue(offline),
    connectivityProvider.overrideWith((_) => connectivity.stream),
    pushMessagingProvider.overrideWithValue(push),
    deviceTokenRepositoryProvider.overrideWithValue(deviceTokens),
    appLinksProvider.overrideWithValue(launchThenIncomingLinks(Future.value(launchLink), links.stream)),
  ];

  Widget app(Widget home) => wrapApp(home, overrides: overrides);
}
