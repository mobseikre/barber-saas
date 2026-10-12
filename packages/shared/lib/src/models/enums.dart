enum UserRole {
  customer,
  barber,
  admin;

  static UserRole fromDb(String value) => values.byName(value);
}

enum BarberStatus {
  pending,
  active,
  suspended,
  rejected;

  static BarberStatus fromDb(String value) => values.byName(value);
}

enum BookingStatus {
  confirmed('confirmed', 'مؤكد'),
  completed('completed', 'مكتمل'),
  noShow('no_show', 'لم يحضر'),
  cancelled('cancelled', 'ملغي');

  const BookingStatus(this.db, this.labelAr);

  final String db;
  final String labelAr;

  static BookingStatus fromDb(String value) => values.firstWhere((s) => s.db == value);
}

enum BookingSource {
  app,
  manual;

  static BookingSource fromDb(String value) => values.byName(value);
}

enum BarberCancelReason {
  sick('sick', 'مريض'),
  emergency('emergency', 'ظرف طارئ'),
  other('other', 'سبب آخر');

  const BarberCancelReason(this.db, this.labelAr);

  final String db;
  final String labelAr;

  static BarberCancelReason fromDb(String value) => values.firstWhere((r) => r.db == value);
}

enum DevicePlatform {
  android,
  ios;

  static DevicePlatform fromDb(String value) => values.byName(value);
}
