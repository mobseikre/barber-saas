class Salon {
  const Salon({
    required this.id,
    required this.name,
    this.ownerId,
    this.areaId,
    this.address,
    this.latitude,
    this.longitude,
    this.photos = const [],
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? ownerId;
  final String? areaId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> photos;
  final DateTime createdAt;

  factory Salon.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    List<dynamic>? coords;
    if (location is Map && location['coordinates'] is List) {
      coords = location['coordinates'] as List;
    }
    return Salon(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String?,
      areaId: json['area_id'] as String?,
      address: json['address'] as String?,
      longitude: coords == null ? null : (coords[0] as num).toDouble(),
      latitude: coords == null ? null : (coords[1] as num).toDouble(),
      photos: (json['photos'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
