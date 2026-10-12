class City {
  const City({required this.id, required this.name, this.sortOrder = 0});

  final String id;
  final String name;
  final int sortOrder;

  factory City.fromJson(Map<String, dynamic> json) =>
      City(id: json['id'] as String, name: json['name'] as String, sortOrder: json['sort_order'] as int? ?? 0);
}

class Area {
  const Area({required this.id, required this.cityId, required this.name, this.sortOrder = 0});

  final String id;
  final String cityId;
  final String name;
  final int sortOrder;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
    id: json['id'] as String,
    cityId: json['city_id'] as String,
    name: json['name'] as String,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
}

class ServiceCatalogItem {
  const ServiceCatalogItem({
    required this.id,
    required this.code,
    required this.nameAr,
    this.descriptionAr,
    required this.defaultDurationMin,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameAr;
  final String? descriptionAr;
  final int defaultDurationMin;
  final int sortOrder;

  factory ServiceCatalogItem.fromJson(Map<String, dynamic> json) => ServiceCatalogItem(
    id: json['id'] as String,
    code: json['code'] as String,
    nameAr: json['name_ar'] as String,
    descriptionAr: json['description_ar'] as String?,
    defaultDurationMin: json['default_duration_min'] as int,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
}
