import 'dart:typed_data';

import 'package:shared/shared.dart';

import 'fakes.dart' show testAreas, tripoliCity;

final testCatalog = [
  ServiceCatalogItem(
    id: 's1',
    code: 'haircut',
    nameAr: 'قص شعر',
    descriptionAr: 'قص وتصفيف كلاسيكي أو حديث',
    defaultDurationMin: 30,
  ),
  ServiceCatalogItem(id: 's2', code: 'beard', nameAr: 'لحية', defaultDurationMin: 20),
  ServiceCatalogItem(id: 's3', code: 'vip', nameAr: 'VIP', descriptionAr: 'شعر + لحية + تنظيف', defaultDurationMin: 75),
];

Salon testSalon({String id = 'salon-1', String? ownerId, double? lat, double? lng, String? areaId, String? address}) =>
    Salon(
      id: id,
      name: 'صالون الأناقة',
      ownerId: ownerId,
      areaId: areaId,
      address: address,
      latitude: lat,
      longitude: lng,
      createdAt: DateTime(2026),
    );

/// Serves canned data and records what the screens write.
class FakeBarberRepo implements BarberRepository {
  List<ServiceCatalogItem> catalog = testCatalog;
  List<BarberService> services = [];
  List<WorkingHours> hours = [];
  List<Break> breaks = [];
  Salon? salonValue;
  List<Salon> searchResults = [];
  BarberStats? statsValue;
  SubscriptionPayment? payment;
  Object? loadError;
  Object? saveError;
  var failLoads = 0;

  final registrations = <Map<String, Object?>>[];
  final uploads = <Map<String, Object?>>[];
  final updatedSalons = <Map<String, Object?>>[];
  final savedServices = <List<BarberService>>[];
  final savedSchedules = <({List<WorkingHours> hours, List<Break> breaks})>[];
  Object? registerError;
  Object? uploadError;

  void _maybeFail() {
    if (failLoads > 0) {
      failLoads--;
      throw loadError ?? Exception('offline');
    }
  }

  @override
  Future<List<ServiceCatalogItem>> serviceCatalog() async {
    _maybeFail();
    return catalog;
  }

  @override
  Future<List<BarberService>> servicesOf(String barberId) async => services;

  @override
  Future<void> saveServices(List<BarberService> payload) async {
    if (saveError != null) throw saveError!;
    savedServices.add(payload);
    services = payload;
  }

  @override
  Future<List<WorkingHours>> workingHoursOf(String barberId) async {
    _maybeFail();
    return hours;
  }

  @override
  Future<List<Break>> breaksOf(String barberId) async => breaks;

  @override
  Future<void> saveSchedule({
    required String barberId,
    required List<WorkingHours> hours,
    required List<Break> breaks,
  }) async {
    if (saveError != null) throw saveError!;
    savedSchedules.add((hours: hours, breaks: breaks));
    this.hours = hours;
    this.breaks = [
      for (var i = 0; i < breaks.length; i++) breaks[i].id != null ? breaks[i] : _withId(breaks[i], 'new-$i'),
    ];
  }

  Break _withId(Break b, String id) =>
      Break(id: id, barberId: b.barberId, weekday: b.weekday, name: b.name, startsAt: b.startsAt, endsAt: b.endsAt);

  @override
  Future<Salon> salon(String id) async {
    _maybeFail();
    return salonValue ?? testSalon(id: id);
  }

  @override
  Future<List<Salon>> searchSalons(String query) async => searchResults;

  @override
  Future<void> updateSalon({
    required String salonId,
    String? name,
    String? areaId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    if (saveError != null) throw saveError!;
    updatedSalons.add({
      'salon': salonId,
      'name': name,
      'area': areaId,
      'address': address,
      'lat': latitude,
      'lng': longitude,
    });
  }

  @override
  Future<Barber> registerBarber({
    required String displayName,
    String? salonId,
    String? salonName,
    String? areaId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    registrations.add({
      'name': displayName,
      'salon': salonId,
      'salonName': salonName,
      'area': areaId,
      'address': address,
      'lat': latitude,
      'lng': longitude,
    });
    if (registerError != null) throw registerError!;
    return Barber(
      id: 'b1',
      profileId: 'u1',
      salonId: salonId ?? 'salon-new',
      displayName: displayName,
      status: BarberStatus.pending,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required String barberId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads.add({'user': userId, 'barber': barberId, 'bytes': bytes.length, 'type': contentType});
    if (uploadError != null) throw uploadError!;
    return 'avatars/$userId/avatar.jpg?v=1';
  }

  @override
  Future<BarberStats> stats() async {
    _maybeFail();
    return statsValue!;
  }

  @override
  Future<SubscriptionPayment?> latestPayment(String barberId) async => payment;

  @override
  Future<List<City>> cities() async => [tripoliCity];

  @override
  Future<List<Area>> areas() async => testAreas;

  @override
  Future<Barber?> barberForProfile(String profileId) async => null;
}
