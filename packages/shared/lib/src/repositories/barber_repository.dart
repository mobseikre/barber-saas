import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/barber.dart';
import '../models/lookups.dart';
import '../models/misc.dart';
import '../models/salon.dart';
import '../models/schedule.dart';
import '../models/stats.dart';

class BarberRepository {
  BarberRepository(this._client);

  final SupabaseClient _client;

  Future<Barber?> barberForProfile(String profileId) async {
    final row = await _client.from('barbers').select().eq('profile_id', profileId).maybeSingle();
    return row == null ? null : Barber.fromJson(row);
  }

  Future<List<Salon>> searchSalons(String query) async {
    final rows = await _client
        .from('salons')
        .select()
        .ilike('name', '%$query%')
        .order('name', ascending: true)
        .limit(20);
    return rows.map(Salon.fromJson).toList();
  }

  Future<Salon> salon(String id) async => Salon.fromJson(await _client.from('salons').select().eq('id', id).single());

  Future<Barber> registerBarber({
    required String displayName,
    String? salonId,
    String? salonName,
    String? areaId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final row = await _client.rpc(
      'register_barber',
      params: {
        'p_display_name': displayName,
        'p_salon_id': salonId,
        'p_salon_name': salonName,
        'p_area_id': areaId,
        'p_address': address,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    return Barber.fromJson(row as Map<String, dynamic>);
  }

  Future<void> updateSalon({
    required String salonId,
    String? areaId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final rows = await _client
        .from('salons')
        .update({
          'area_id': areaId,
          'address': address,
          if (latitude != null && longitude != null) 'location': 'SRID=4326;POINT($longitude $latitude)',
        })
        .eq('id', salonId)
        .select('id');
    if (rows.isEmpty) throw const PostgrestException(message: 'not_salon_owner', code: '42501');
  }

  Future<List<City>> cities() async {
    final rows = await _client.from('cities').select().order('sort_order', ascending: true);
    return rows.map(City.fromJson).toList();
  }

  Future<List<Area>> areas() async {
    final rows = await _client.from('areas').select().order('sort_order', ascending: true);
    return rows.map(Area.fromJson).toList();
  }

  Future<List<ServiceCatalogItem>> serviceCatalog() async {
    final rows = await _client.from('service_catalog').select().order('sort_order', ascending: true);
    return rows.map(ServiceCatalogItem.fromJson).toList();
  }

  Future<List<BarberService>> servicesOf(String barberId) async {
    final rows = await _client
        .from('barber_services')
        .select('*, service_catalog(name_ar, sort_order)')
        .eq('barber_id', barberId)
        .order('sort_order', referencedTable: 'service_catalog', ascending: true);
    return rows.map(BarberService.fromJson).toList();
  }

  Future<void> saveServices(List<BarberService> services) => _client.from('barber_services').upsert([
    for (final s in services) s.toJson(),
  ], onConflict: 'barber_id,service_id');

  Future<List<WorkingHours>> workingHoursOf(String barberId) async {
    final rows = await _client
        .from('working_hours')
        .select()
        .eq('barber_id', barberId)
        .order('weekday', ascending: true);
    return rows.map(WorkingHours.fromJson).toList();
  }

  Future<List<Break>> breaksOf(String barberId) async {
    final rows = await _client.from('breaks').select().eq('barber_id', barberId).order('starts_at', ascending: true);
    return rows.map(Break.fromJson).toList();
  }

  /// Saves the week's hours and the breaks.
  Future<void> saveSchedule({
    required String barberId,
    required List<WorkingHours> hours,
    required List<Break> breaks,
  }) async {
    await _client.from('working_hours').upsert([for (final h in hours) h.toJson()], onConflict: 'barber_id,weekday');
    final keep = [for (final b in breaks) ?b.id];
    final stale = _client.from('breaks').delete().eq('barber_id', barberId);
    await (keep.isEmpty ? stale : stale.not('id', 'in', '(${keep.join(',')})'));
    final existing = [
      for (final b in breaks)
        if (b.id != null) b.toJson(),
    ];
    final added = [
      for (final b in breaks)
        if (b.id == null) b.toJson(),
    ];
    if (existing.isNotEmpty) await _client.from('breaks').upsert(existing);
    if (added.isNotEmpty) await _client.from('breaks').insert(added);
  }

  Future<BarberStats> stats() async => BarberStats.fromJson(await _client.rpc('barber_stats') as Map<String, dynamic>);

  Future<SubscriptionPayment?> latestPayment(String barberId) async {
    final row = await _client
        .from('subscription_payments')
        .select()
        .eq('barber_id', barberId)
        .order('period_end', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : SubscriptionPayment.fromJson(row);
  }

  /// Uploads the photo to the user's folder in the `avatars` bucket and links it to the barber and profile.
  /// Returns the stored value, `avatars/<user>/avatar.<ext>?v=<time>`; see [publicStorageUrl].
  Future<String> uploadAvatar({
    required String userId,
    required String barberId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extension = contentType == 'image/png' ? 'png' : (contentType == 'image/webp' ? 'webp' : 'jpg');
    final path = '$userId/avatar.$extension';
    await _client.storage
        .from('avatars')
        .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
    final stored = 'avatars/$path?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('barbers').update({'photo_url': stored}).eq('id', barberId);
    await _client.from('profiles').update({'avatar_url': stored}).eq('id', userId);
    return stored;
  }
}
