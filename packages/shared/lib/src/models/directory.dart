import 'package:flutter/material.dart';

import 'schedule.dart';

/// A row of the `barber_directory` view: the barber with their salon, for the customer app.
class BarberListing {
  const BarberListing({
    required this.id,
    required this.salonId,
    required this.displayName,
    this.photoUrl,
    this.isVip = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isBookable = true,
    this.phone,
    required this.salonName,
    this.areaId,
    this.address,
    this.latitude,
    this.longitude,
    this.salonPhotos = const [],
  });

  final String id;
  final String salonId;
  final String displayName;
  final String? photoUrl;
  final bool isVip;
  final double ratingAvg;
  final int ratingCount;
  final bool isBookable;
  final String? phone;
  final String salonName;
  final String? areaId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> salonPhotos;

  bool get hasLocation => latitude != null && longitude != null;

  factory BarberListing.fromJson(Map<String, dynamic> json) => BarberListing(
    id: json['id'] as String,
    salonId: json['salon_id'] as String,
    displayName: json['display_name'] as String,
    photoUrl: json['photo_url'] as String?,
    isVip: json['is_vip'] as bool? ?? false,
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
    isBookable: json['is_bookable'] as bool? ?? false,
    phone: json['phone'] as String?,
    salonName: json['salon_name'] as String,
    areaId: json['area_id'] as String?,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    salonPhotos: (json['salon_photos'] as List?)?.cast<String>() ?? const [],
  );
}

/// A row of the `salon_barbers` view: every barber working in a salon, bookable or not.
class SalonBarber {
  const SalonBarber({
    required this.id,
    required this.salonId,
    required this.displayName,
    this.photoUrl,
    this.isVip = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isBookable = false,
  });

  final String id;
  final String salonId;
  final String displayName;
  final String? photoUrl;
  final bool isVip;
  final double ratingAvg;
  final int ratingCount;
  final bool isBookable;

  factory SalonBarber.fromJson(Map<String, dynamic> json) => SalonBarber(
    id: json['id'] as String,
    salonId: json['salon_id'] as String,
    displayName: json['display_name'] as String,
    photoUrl: json['photo_url'] as String?,
    isVip: json['is_vip'] as bool? ?? false,
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
    isBookable: json['is_bookable'] as bool? ?? false,
  );
}

/// A row of the `salon_hours` view. `weekday` uses the Postgres convention: 0 = Sunday.
class SalonDayHours {
  const SalonDayHours({required this.weekday, required this.opensAt, required this.closesAt});

  final int weekday;
  final TimeOfDay opensAt;
  final TimeOfDay closesAt;

  factory SalonDayHours.fromJson(Map<String, dynamic> json) => SalonDayHours(
    weekday: json['weekday'] as int,
    opensAt: parseDbTime(json['opens_at'] as String),
    closesAt: parseDbTime(json['closes_at'] as String),
  );
}

/// A start time returned by `get_available_slots`.
class TimeSlot {
  const TimeSlot({required this.startsAt, required this.endsAt});

  final DateTime startsAt;
  final DateTime endsAt;
}
