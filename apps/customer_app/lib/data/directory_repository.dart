import 'package:shared/shared.dart';

/// What a barber card needs about today: the lowest price and whether the chair is open.
class BarberToday {
  const BarberToday({this.fromPrice, this.hours, this.closure});

  final double? fromPrice;
  final WorkingHours? hours;
  final DayClosure? closure;
}

/// Read-only queries for browsing; all of them work without a session.
class DirectoryRepository {
  DirectoryRepository(this._client);

  final SupabaseClient _client;

  static const _closureColumns = 'id, barber_id, date, from_time';

  Future<List<BarberListing>> bookableBarbers() async {
    final rows = await _client.from('barber_directory').select().eq('is_bookable', true);
    return rows.map(BarberListing.fromJson).toList();
  }

  Future<List<BarberListing>> salonListings(String salonId) async {
    final rows = await _client.from('barber_directory').select().eq('salon_id', salonId);
    return rows.map(BarberListing.fromJson).toList();
  }

  Future<List<SalonBarber>> salonBarbers(String salonId) async {
    final rows = await _client.from('salon_barbers').select().eq('salon_id', salonId).order('display_name');
    return rows.map(SalonBarber.fromJson).toList();
  }

  Future<List<SalonDayHours>> salonHours(String salonId) async {
    final rows = await _client.from('salon_hours').select().eq('salon_id', salonId);
    return rows.map(SalonDayHours.fromJson).toList();
  }

  /// One query per table for the whole list, keyed by barber id.
  Future<Map<String, BarberToday>> today(List<String> barberIds, DateTime now) async {
    if (barberIds.isEmpty) return const {};
    final (prices, hours, closures) = await (
      _client
          .from('barber_services')
          .select('barber_id, price')
          .inFilter('barber_id', barberIds)
          .eq('is_enabled', true),
      _client.from('working_hours').select().inFilter('barber_id', barberIds).eq('weekday', dbWeekday(now)),
      _client.from('day_closures').select(_closureColumns).inFilter('barber_id', barberIds).eq('date', dbDate(now)),
    ).wait;
    final fromPrice = <String, double>{};
    for (final row in prices) {
      final id = row['barber_id'] as String;
      final price = double.parse(row['price'].toString());
      if (price < (fromPrice[id] ?? double.infinity)) fromPrice[id] = price;
    }
    final hoursById = {for (final h in hours.map(WorkingHours.fromJson)) h.barberId: h};
    final closureById = {for (final c in closures.map(DayClosure.fromJson)) c.barberId: c};
    return {
      for (final id in barberIds)
        id: BarberToday(fromPrice: fromPrice[id], hours: hoursById[id], closure: closureById[id]),
    };
  }

  Future<List<DayClosure>> closures(String barberId, {required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from('day_closures')
        .select(_closureColumns)
        .eq('barber_id', barberId)
        .gte('date', dbDate(from))
        .lte('date', dbDate(to));
    return rows.map(DayClosure.fromJson).toList();
  }
}
