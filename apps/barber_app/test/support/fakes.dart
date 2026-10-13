import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/providers.dart';
import 'package:barber_app/services/photo_service.dart';

Booking booking({
  required String id,
  required String name,
  required DateTime startsAt,
  BookingStatus status = BookingStatus.confirmed,
  BookingSource source = BookingSource.app,
  String? phone,
}) => Booking(
  id: id,
  barberId: 'b1',
  customerId: source == BookingSource.app ? 'c-$id' : null,
  customerName: name,
  customerPhone: phone,
  serviceId: 's1',
  serviceName: 'قص شعر',
  price: 25,
  durationMin: 30,
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(minutes: 30)),
  status: status,
  source: source,
  createdAt: startsAt,
);

final fakeBarber = Barber(
  id: 'b1',
  profileId: 'u1',
  salonId: 's1',
  displayName: 'علي القماطي',
  status: BarberStatus.active,
  subscriptionEndsAt: DateTime.now().add(const Duration(days: 10)),
  createdAt: DateTime(2026),
);

/// Records calls instead of hitting Supabase.
class FakeTodayBookings extends TodayBookings {
  FakeTodayBookings(this.initial, {this.remainingAfterClose = const [], this.manualError, this.gate});

  final List<Booking> initial;
  final List<Booking> remainingAfterClose;
  final Object? manualError;
  final Completer<void>? gate;
  final calls = <String>[];
  final manualStarts = <DateTime>[];

  @override
  Future<List<Booking>> build() async => initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> markAttended(String id) async {
    calls.add('attended:$id');
    await gate?.future;
  }

  @override
  Future<void> markNoShow(String id) async {
    calls.add('no_show:$id');
    await gate?.future;
  }

  @override
  Future<void> reopenToday() async => calls.add('reopen');

  @override
  Future<void> cancel(String id, {required BarberCancelReason reason, String? note}) async =>
      calls.add('cancel:$id:${reason.db}:${note ?? ''}');

  @override
  Future<List<Booking>> closeRestOfToday() async {
    calls.add('close');
    return remainingAfterClose;
  }

  @override
  Future<void> addManual({required String serviceId, required DateTime startsAt, required String customerName}) async {
    calls.add('manual:$customerName');
    manualStarts.add(startsAt);
    if (manualError != null) throw manualError!;
  }
}

final tripoliCity = City(id: 'city-1', name: 'طرابلس');
final testAreas = [
  Area(id: 'area-1', cityId: 'city-1', name: 'حي الأندلس'),
  Area(id: 'area-2', cityId: 'city-1', name: 'قرقارش'),
];

final transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class BlankTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(transparentPng);
}

class FakePhotoService implements PhotoService {
  FakePhotoService([this.photo]);

  PickedPhoto? photo;
  Completer<PickedPhoto?>? pending;

  @override
  Future<PickedPhoto?> pick() async => pending == null ? photo : pending!.future;
}

final testPhoto = PickedPhoto(bytes: transparentPng, contentType: 'image/png');

/// A Tripoli spot every fake location returns unless a test sets another.
const barberSpot = LocationResult.found(LatLng(32.9, 13.2));

Widget testApp({
  required Widget home,
  Iterable<Object> overrides = const [],
  DayClosure? closure,
  FakeLocationService? location,
  FakePhotoService? photos,
  BarberRepository? barbers,
  AuthRepository? auth,
  Barber? barber,
  Future<Barber?> Function()? barberLoader,
}) => wrapApp(
  home,
  overrides: [
    currentBarberProvider.overrideWith(
      (_) => barberLoader != null ? barberLoader() : Future.value(barber ?? fakeBarber),
    ),
    todayClosureProvider.overrideWith((_) async => closure),
    mapTileProviderProvider.overrideWithValue(BlankTileProvider()),
    locationServiceProvider.overrideWithValue(location ?? FakeLocationService(barberSpot)),
    photoServiceProvider.overrideWithValue(photos ?? FakePhotoService()),
    citiesProvider.overrideWith((_) async => [tripoliCity]),
    areasProvider.overrideWith((_) async => testAreas),
    if (barbers != null) barberRepositoryProvider.overrideWithValue(barbers),
    if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ...overrides,
  ],
);

const haircut = BarberService(barberId: 'b1', serviceId: 's1', price: 25, durationMin: 30, nameAr: 'قص شعر');
