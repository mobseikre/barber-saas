import 'package:supabase_flutter/supabase_flutter.dart';

import '../format/app_time.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../models/schedule.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, customer:profiles!bookings_customer_id_fkey(full_name, phone), service:service_catalog(name_ar)';

  Future<List<Booking>> bookingsForDay({required String barberId, required DateTime day}) async {
    final range = AppTime.dayRange(day);
    final rows = await _client
        .from('bookings')
        .select(_select)
        .eq('barber_id', barberId)
        .overlaps('time_range', '[${range.start.toUtc().toIso8601String()},${range.end.toUtc().toIso8601String()})');
    final bookings = rows.map(Booking.fromJson).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return bookings;
  }

  Future<Booking> createBooking({
    required String barberId,
    required String serviceId,
    required DateTime startsAt,
  }) async {
    final row = await _client.rpc(
      'create_booking',
      params: {'p_barber_id': barberId, 'p_service_id': serviceId, 'p_starts_at': startsAt.toUtc().toIso8601String()},
    );
    return Booking.fromJson(row as Map<String, dynamic>);
  }

  Future<Booking> createManualBooking({
    required String serviceId,
    required DateTime startsAt,
    required String customerName,
  }) async {
    final row = await _client.rpc(
      'create_manual_booking',
      params: {
        'p_service_id': serviceId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_customer_name': customerName,
      },
    );
    return Booking.fromJson(row as Map<String, dynamic>);
  }

  Future<Booking> setStatus(String bookingId, BookingStatus status) async {
    final row = await _client.rpc('set_booking_status', params: {'p_booking_id': bookingId, 'p_status': status.db});
    return Booking.fromJson(row as Map<String, dynamic>);
  }

  Future<Booking> cancel(String bookingId, {BarberCancelReason? reason, String? note}) async {
    final row = await _client.rpc(
      'cancel_booking',
      params: {'p_booking_id': bookingId, 'p_reason': reason?.db, 'p_note': note},
    );
    return Booking.fromJson(row as Map<String, dynamic>);
  }

  /// Closes the rest of today and returns the confirmed bookings left in it.
  Future<List<Booking>> closeRestOfToday() async {
    final rows = await _client.rpc('close_rest_of_today') as List;
    return rows.map((r) => Booking.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<DayClosure?> closureOn({required String barberId, required DateTime day}) async {
    final d = AppTime.from(day);
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final row = await _client.from('day_closures').select().eq('barber_id', barberId).eq('date', date).maybeSingle();
    return row == null ? null : DayClosure.fromJson(row);
  }

  Future<void> reopenToday() => _client.rpc('reopen_today');
}
