import '../format/app_time.dart';
import 'enums.dart';

class Barber {
  const Barber({
    required this.id,
    this.profileId,
    required this.salonId,
    required this.displayName,
    this.photoUrl,
    this.isVip = false,
    required this.status,
    this.subscriptionEndsAt,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    required this.createdAt,
  });

  final String id;
  final String? profileId;
  final String salonId;
  final String displayName;
  final String? photoUrl;
  final bool isVip;
  final BarberStatus status;
  final DateTime? subscriptionEndsAt;
  final double ratingAvg;
  final int ratingCount;
  final DateTime createdAt;

  /// Mirrors `is_barber_bookable`.
  bool get isBookable =>
      status == BarberStatus.active &&
      profileId != null &&
      subscriptionEndsAt != null &&
      subscriptionEndsAt!.isAfter(AppTime.now());

  /// Whole days until the subscription ends, counting a started day as one; 0 once it has ended.
  int get daysLeft {
    final left = subscriptionEndsAt?.difference(AppTime.now());
    return left == null || left <= Duration.zero ? 0 : (left.inHours / 24).ceil();
  }

  factory Barber.fromJson(Map<String, dynamic> json) => Barber(
    id: json['id'] as String,
    profileId: json['profile_id'] as String?,
    salonId: json['salon_id'] as String,
    displayName: json['display_name'] as String,
    photoUrl: json['photo_url'] as String?,
    isVip: json['is_vip'] as bool? ?? false,
    status: BarberStatus.fromDb(json['status'] as String),
    subscriptionEndsAt: json['subscription_ends_at'] == null
        ? null
        : AppTime.from(DateTime.parse(json['subscription_ends_at'] as String)),
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class BarberService {
  const BarberService({
    required this.barberId,
    required this.serviceId,
    required this.price,
    required this.durationMin,
    this.isEnabled = true,
    this.nameAr,
  });

  final String barberId;
  final String serviceId;
  final double price;
  final int durationMin;
  final bool isEnabled;

  final String? nameAr;

  factory BarberService.fromJson(Map<String, dynamic> json) => BarberService(
    barberId: json['barber_id'] as String,
    serviceId: json['service_id'] as String,
    price: double.parse(json['price'].toString()),
    durationMin: json['duration_min'] as int,
    isEnabled: json['is_enabled'] as bool? ?? true,
    nameAr: (json['service_catalog'] as Map?)?['name_ar'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'barber_id': barberId,
    'service_id': serviceId,
    'price': price,
    'duration_min': durationMin,
    'is_enabled': isEnabled,
  };
}
