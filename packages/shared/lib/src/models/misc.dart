import '../format/app_time.dart';
import 'enums.dart';

class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.barberId,
    required this.salonId,
    required this.customerId,
    required this.rating,
    this.tags = const [],
    this.comment,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String barberId;
  final String salonId;
  final String customerId;
  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    bookingId: json['booking_id'] as String,
    barberId: json['barber_id'] as String,
    salonId: json['salon_id'] as String,
    customerId: json['customer_id'] as String,
    rating: json['rating'] as int,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.barberId,
    required this.amount,
    required this.paidAt,
    required this.periodStart,
    required this.periodEnd,
    required this.recordedBy,
    this.note,
  });

  final String id;
  final String barberId;
  final double amount;
  final DateTime paidAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String recordedBy;
  final String? note;

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) => SubscriptionPayment(
    id: json['id'] as String,
    barberId: json['barber_id'] as String,
    amount: double.parse(json['amount'].toString()),
    paidAt: AppTime.from(DateTime.parse(json['paid_at'] as String)),
    periodStart: AppTime.from(DateTime.parse(json['period_start'] as String)),
    periodEnd: AppTime.from(DateTime.parse(json['period_end'] as String)),
    recordedBy: json['recorded_by'] as String,
    note: json['note'] as String?,
  );
}

class DeviceToken {
  const DeviceToken({this.id, required this.profileId, required this.token, required this.platform});

  final String? id;
  final String profileId;
  final String token;
  final DevicePlatform platform;

  Map<String, dynamic> toJson() => {'profile_id': profileId, 'token': token, 'platform': platform.name};
}
