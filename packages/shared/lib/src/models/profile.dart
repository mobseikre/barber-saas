import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    this.cityId,
    this.noShowCount = 0,
    this.blockedAt,
    required this.createdAt,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String? cityId;
  final int noShowCount;
  final DateTime? blockedAt;
  final DateTime createdAt;

  bool get isBlocked => blockedAt != null;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    role: UserRole.fromDb(json['role'] as String),
    fullName: json['full_name'] as String,
    phone: json['phone'] as String,
    avatarUrl: json['avatar_url'] as String?,
    cityId: json['city_id'] as String?,
    noShowCount: json['no_show_count'] as int? ?? 0,
    blockedAt: _date(json['blocked_at']),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);
