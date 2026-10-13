import 'package:supabase_flutter/supabase_flutter.dart';

import '../format/app_time.dart';
import '../models/booking.dart';
import '../models/directory.dart';
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

  /// Free start times on [day] in the app time zone for a service of [durationMin] minutes.
  Future<List<TimeSlot>> availableSlots({
    required String barberId,
    required DateTime day,
    required int durationMin,
  }) async {
    final rows =
        await _client.rpc(
              'get_available_slots',
              params: {'p_barber_id': barberId, 'p_date': dbDate(day), 'p_duration_min': durationMin},
            )
            as List;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        TimeSlot(
          startsAt: AppTime.from(DateTime.parse(r['starts_at'] as String)),
          endsAt: AppTime.from(DateTime.parse(r['ends_at'] as String)),
        ),
    ];
  }

  /// Books for the signed-in customer. Retrying with the same [idempotencyKey] returns the booking
  /// the first call created instead of booking twice.
  Future<Booking> createBooking({
    required String barberId,
    required String serviceId,
    required DateTime startsAt,
    required String idempotencyKey,
  }) async {
    final row = await _client.rpc(
      'create_booking',
      params: {
        'p_barber_id': barberId,
        'p_service_id': serviceId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_idempotency_key': idempotencyKey,
      },
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
    final row = await _client
        .from('day_closures')
        .select()
        .eq('barber_id', barberId)
        .eq('date', dbDate(day))
        .maybeSingle();
    return row == null ? null : DayClosure.fromJson(row);
  }

  Future<void> reopenToday() => _client.rpc('reopen_today');
}
