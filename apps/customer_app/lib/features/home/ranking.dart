import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared/shared.dart';

import '../../data/directory_repository.dart';

enum HomeSort { nearest, topRated }

class RankedBarber {
  const RankedBarber(this.barber, this.distance);

  final BarberListing barber;

  /// Metres from the customer, or null when either location is unknown.
  final double? distance;
}

const _distance = Distance();

double? distanceTo(LatLng? origin, BarberListing barber) =>
    origin == null || !barber.hasLocation ? null : _distance(origin, LatLng(barber.latitude!, barber.longitude!));

int _nullsLast(double? a, double? b) => a == null ? (b == null ? 0 : 1) : (b == null ? -1 : a.compareTo(b));

int _byRating(BarberListing a, BarberListing b) {
  final rating = b.ratingAvg.compareTo(a.ratingAvg);
  return rating != 0 ? rating : b.ratingCount.compareTo(a.ratingCount);
}

/// Orders the home list: by nearest area with VIPs first inside each area, or by rating.
List<RankedBarber> rankBarbers(
  List<BarberListing> barbers, {
  required List<Area> areas,
  LatLng? origin,
  HomeSort sort = HomeSort.nearest,
}) {
  final ranked = [for (final b in barbers) RankedBarber(b, distanceTo(origin, b))];
  if (sort == HomeSort.topRated) {
    return ranked..sort((a, b) {
      final rating = _byRating(a.barber, b.barber);
      if (rating != 0) return rating;
      if (a.barber.isVip != b.barber.isVip) return a.barber.isVip ? -1 : 1;
      return _nullsLast(a.distance, b.distance);
    });
  }

  final areaOrder = {for (final (i, a) in areas.indexed) a.id: i};
  final areaDistance = <String?, double?>{};
  for (final r in ranked) {
    final current = areaDistance[r.barber.areaId];
    if (!areaDistance.containsKey(r.barber.areaId) || _nullsLast(r.distance, current) < 0) {
      areaDistance[r.barber.areaId] = r.distance;
    }
  }
  int areaRank(String? id) => id == null ? areas.length : areaOrder[id] ?? areas.length;

  return ranked..sort((a, b) {
    final sameArea = a.barber.areaId == b.barber.areaId;
    if (!sameArea) {
      final byDistance = _nullsLast(areaDistance[a.barber.areaId], areaDistance[b.barber.areaId]);
      return byDistance != 0 ? byDistance : areaRank(a.barber.areaId).compareTo(areaRank(b.barber.areaId));
    }
    if (a.barber.isVip != b.barber.isVip) return a.barber.isVip ? -1 : 1;
    final byDistance = _nullsLast(a.distance, b.distance);
    return byDistance != 0 ? byDistance : _byRating(a.barber, b.barber);
  });
}

class HomeFilter {
  const HomeFilter({this.openNow = false, this.vipOnly = false});

  final bool openNow;
  final bool vipOnly;

  bool get isActive => openNow || vipOnly;

  HomeFilter copyWith({bool? openNow, bool? vipOnly}) =>
      HomeFilter(openNow: openNow ?? this.openNow, vipOnly: vipOnly ?? this.vipOnly);
}

/// Keeps the barbers of [cityId] (and of [areaId] when set) whose barber or salon name contains [query],
/// and that pass [filter]. Open-now needs [today] and [now]; a barber without hours loaded counts as not open.
List<RankedBarber> filterBarbers(
  List<RankedBarber> ranked, {
  required List<Area> areas,
  String? cityId,
  String? areaId,
  String query = '',
  HomeFilter filter = const HomeFilter(),
  Map<String, BarberToday>? today,
  DateTime? now,
}) {
  final cityOfArea = {for (final a in areas) a.id: a.cityId};
  final q = query.trim();
  return [
    for (final r in ranked)
      if ((cityId == null || cityOfArea[r.barber.areaId] == cityId) &&
          (areaId == null || r.barber.areaId == areaId) &&
          (q.isEmpty || r.barber.displayName.contains(q) || r.barber.salonName.contains(q)) &&
          (!filter.vipOnly || r.barber.isVip) &&
          (!filter.openNow || _isOpenNow(today?[r.barber.id], now)))
        r,
  ];
}

bool _isOpenNow(BarberToday? today, DateTime? now) =>
    today != null && now != null && openState(hours: today.hours, closure: today.closure, now: now) is OpenNow;

/// The city to show first: the one of the nearest barber, or else the first city.
String? defaultCityId({required List<RankedBarber> nearest, required List<Area> areas, required List<City> cities}) {
  final cityOfArea = {for (final a in areas) a.id: a.cityId};
  for (final r in nearest) {
    if (r.distance != null && cityOfArea[r.barber.areaId] != null) return cityOfArea[r.barber.areaId];
  }
  return cities.isEmpty ? null : cities.first.id;
}

sealed class OpenState {
  const OpenState();
}

class OpenNow extends OpenState {
  const OpenNow();
}

class OpensLater extends OpenState {
  const OpensLater(this.at);

  final TimeOfDay at;
}

class ClosedToday extends OpenState {
  const ClosedToday();
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

/// Whether the barber is working at [now] (Tripoli wall time), from today's hours and closure.
OpenState openState({WorkingHours? hours, DayClosure? closure, required DateTime now}) {
  if (hours == null || hours.isClosed || (closure != null && closure.isWholeDay)) return const ClosedToday();
  final current = now.hour * 60 + now.minute;
  final closes = closure?.fromTime == null
      ? _minutes(hours.closesAt)
      : _minutes(closure!.fromTime!).clamp(0, _minutes(hours.closesAt));
  if (current < _minutes(hours.opensAt) && _minutes(hours.opensAt) < closes) return OpensLater(hours.opensAt);
  if (current < closes && current >= _minutes(hours.opensAt)) return const OpenNow();
  return const ClosedToday();
}
