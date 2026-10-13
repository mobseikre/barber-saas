import 'package:shared/shared.dart';

/// A booking of the signed-in customer with its barber, salon and rating.
class MyBooking {
  const MyBooking({
    required this.booking,
    this.barberName = '',
    this.salonName = '',
    this.latitude,
    this.longitude,
    this.rating,
  });

  final Booking booking;
  final String barberName;
  final String salonName;
  final double? latitude;
  final double? longitude;
  final int? rating;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isUpcoming => booking.isUpcoming;
  bool get canRate => booking.status == BookingStatus.completed && rating == null;
  bool get canCancel => booking.startsAt.difference(AppTime.now()) >= AppConstants.cancellationWindow;

  MyBooking withRating(int value) => MyBooking(
    booking: booking,
    barberName: barberName,
    salonName: salonName,
    latitude: latitude,
    longitude: longitude,
    rating: value,
  );
}

class MyBookingsRepository {
  MyBookingsRepository(this._client);

  final SupabaseClient _client;

  Future<List<MyBooking>> load(String customerId) async {
    final rows = await _client
        .from('bookings')
        .select('*, service:service_catalog(name_ar)')
        .eq('customer_id', customerId);
    final bookings = rows.map(Booking.fromJson).toList();
    if (bookings.isEmpty) return const [];
    final (barbers, reviews) = await (
      _client.from('my_booking_barbers').select(),
      _client.from('reviews').select('booking_id, rating').eq('customer_id', customerId),
    ).wait;
    final places = {for (final p in barbers) p['barber_id'] as String: p};
    final ratings = {for (final r in reviews) r['booking_id'] as String: r['rating'] as int};
    return [
      for (final b in bookings)
        MyBooking(
          booking: b,
          barberName: places[b.barberId]?['display_name'] as String? ?? '',
          salonName: places[b.barberId]?['salon_name'] as String? ?? '',
          latitude: (places[b.barberId]?['latitude'] as num?)?.toDouble(),
          longitude: (places[b.barberId]?['longitude'] as num?)?.toDouble(),
          rating: ratings[b.id],
        ),
    ];
  }

  Future<void> submitReview({
    required String customerId,
    required String bookingId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    final text = comment?.trim() ?? '';
    await _client.from('reviews').insert({
      'booking_id': bookingId,
      'customer_id': customerId,
      'rating': rating,
      'tags': tags,
      'comment': text.isEmpty ? null : text,
    });
  }
}
