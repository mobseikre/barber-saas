import '../format/app_time.dart';
import 'enums.dart';

/// Parses a Postgres tstzrange literal such as `["2026-10-10 09:00:00+00","2026-10-10 09:30:00+00")`.
({DateTime start, DateTime end}) parseTstzRange(String range) {
  final inner = range.substring(1, range.length - 1).replaceAll('"', '');
  final parts = inner.split(',');
  return (start: AppTime.from(DateTime.parse(parts[0])), end: AppTime.from(DateTime.parse(parts[1])));
}

class Booking {
  const Booking({
    required this.id,
    required this.barberId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.serviceId,
    this.serviceName,
    required this.price,
    required this.durationMin,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.source,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.cancelNote,
    required this.createdAt,
  });

  final String id;
  final String barberId;
  final String? customerId;

  final String? customerName;
  final String? customerPhone;
  final String serviceId;
  final String? serviceName;
  final double price;
  final int durationMin;
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;
  final BookingSource source;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final BarberCancelReason? cancelReason;
  final String? cancelNote;
  final DateTime createdAt;

  bool get isManual => source == BookingSource.manual;
  bool get isUpcoming => status == BookingStatus.confirmed && startsAt.isAfter(AppTime.now());
  bool get isOpen => status == BookingStatus.confirmed;
  bool get hasStarted => !startsAt.isAfter(AppTime.now());

  String get displayName => customerName ?? '';

  factory Booking.fromJson(Map<String, dynamic> json) {
    final range = parseTstzRange(json['time_range'] as String);
    final customer = json['customer'] as Map?;
    return Booking(
      id: json['id'] as String,
      barberId: json['barber_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ?? customer?['full_name'] as String?,
      customerPhone: customer?['phone'] as String?,
      serviceId: json['service_id'] as String,
      serviceName: (json['service'] as Map?)?['name_ar'] as String?,
      price: double.parse(json['price'].toString()),
      durationMin: json['duration_min'] as int,
      startsAt: range.start,
      endsAt: range.end,
      status: BookingStatus.fromDb(json['status'] as String),
      source: BookingSource.fromDb(json['source'] as String),
      cancelledAt: json['cancelled_at'] == null ? null : DateTime.parse(json['cancelled_at'] as String),
      cancelledBy: json['cancelled_by'] as String?,
      cancelReason: json['cancel_reason'] == null ? null : BarberCancelReason.fromDb(json['cancel_reason'] as String),
      cancelNote: json['cancel_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
