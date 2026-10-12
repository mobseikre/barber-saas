import 'package:flutter/material.dart';

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Whether [later] is strictly after [earlier] on the same day.
bool isAfter(TimeOfDay later, TimeOfDay earlier) => later.hour * 60 + later.minute > earlier.hour * 60 + earlier.minute;

String _timeToDb(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// One row per weekday. `weekday` uses the Postgres convention: 0 = Sunday.
class WorkingHours {
  const WorkingHours({
    required this.barberId,
    required this.weekday,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
  });

  final String barberId;
  final int weekday;
  final TimeOfDay opensAt;
  final TimeOfDay closesAt;
  final bool isClosed;

  factory WorkingHours.fromJson(Map<String, dynamic> json) => WorkingHours(
    barberId: json['barber_id'] as String,
    weekday: json['weekday'] as int,
    opensAt: _parseTime(json['opens_at'] as String),
    closesAt: _parseTime(json['closes_at'] as String),
    isClosed: json['is_closed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'barber_id': barberId,
    'weekday': weekday,
    'opens_at': _timeToDb(opensAt),
    'closes_at': _timeToDb(closesAt),
    'is_closed': isClosed,
  };
}

class Break {
  const Break({
    this.id,
    required this.barberId,
    this.weekday,
    required this.name,
    required this.startsAt,
    required this.endsAt,
  });

  final String? id;
  final String barberId;
  final int? weekday;
  final String name;
  final TimeOfDay startsAt;
  final TimeOfDay endsAt;

  factory Break.fromJson(Map<String, dynamic> json) => Break(
    id: json['id'] as String,
    barberId: json['barber_id'] as String,
    weekday: json['weekday'] as int?,
    name: json['name'] as String,
    startsAt: _parseTime(json['starts_at'] as String),
    endsAt: _parseTime(json['ends_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'barber_id': barberId,
    'weekday': weekday,
    'name': name,
    'starts_at': _timeToDb(startsAt),
    'ends_at': _timeToDb(endsAt),
  };
}

class DayClosure {
  const DayClosure({this.id, required this.barberId, required this.date, this.fromTime, this.reason});

  final String? id;
  final String barberId;
  final DateTime date;
  final TimeOfDay? fromTime;
  final String? reason;

  bool get isWholeDay => fromTime == null;

  factory DayClosure.fromJson(Map<String, dynamic> json) => DayClosure(
    id: json['id'] as String,
    barberId: json['barber_id'] as String,
    date: DateTime.parse(json['date'] as String),
    fromTime: json['from_time'] == null ? null : _parseTime(json['from_time'] as String),
    reason: json['reason'] as String?,
  );
}
