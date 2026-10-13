import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';

import 'package:customer_app/features/home/ranking.dart';

import 'support/fakes.dart';

void main() {
  List<String> ids(List<RankedBarber> r) => [for (final b in r) b.barber.id];

  group('rankBarbers, nearest', () {
    test('areas come nearest first and VIP barbers lead their area', () {
      final ranked = rankBarbers([salem, mohamed, omar, ayman, ali], areas: testAreas, origin: customerSpot);

      expect(ids(ranked), ['ali', 'ayman', 'mohamed', 'salem', 'omar']);
      expect(ranked.first.distance, closeTo(560, 60));
    });

    test('a VIP further away still comes before a nearer barber of the same area', () {
      final nearPlain = listing(id: 'near', name: 'قريب', lat: 32.8721, lng: 13.1101);
      final farVip = listing(id: 'far', name: 'مميز', vip: true, lat: 32.8800, lng: 13.1300);

      expect(ids(rankBarbers([nearPlain, farVip], areas: testAreas, origin: customerSpot)), ['far', 'near']);
    });

    test('without a location, areas follow their order and VIP then rating decide inside an area', () {
      final ranked = rankBarbers([salem, mohamed, omar, ali], areas: testAreas);

      expect(ids(ranked), ['ali', 'mohamed', 'salem', 'omar']);
      expect(ranked.every((r) => r.distance == null), isTrue);
    });

    test('barbers without an area or location come last', () {
      final unplaced = listing(id: 'x', name: 'بلا موقع', areaId: null);

      expect(ids(rankBarbers([unplaced, salem], areas: testAreas, origin: customerSpot)), ['salem', 'x']);
    });
  });

  test('topRated orders by rating, then rating count, then VIP', () {
    final ranked = rankBarbers([ali, mohamed, ayman, salem], areas: testAreas, sort: HomeSort.topRated);

    expect(ids(ranked), ['mohamed', 'ali', 'salem', 'ayman']);
  });

  test('filterBarbers keeps the city, the area and the search text', () {
    final ranked = rankBarbers(allListings, areas: testAreas);

    expect(ids(filterBarbers(ranked, areas: testAreas, cityId: 'benghazi')), ['omar']);
    expect(ids(filterBarbers(ranked, areas: testAreas, cityId: 'tripoli', areaId: 'gargaresh')), ['salem']);
    expect(ids(filterBarbers(ranked, areas: testAreas, cityId: 'tripoli', query: 'ستايل')), ['ayman']);
    expect(ids(filterBarbers(ranked, areas: testAreas, cityId: 'tripoli', query: ' علي ')), ['ali']);
  });

  test('defaultCityId is the city of the nearest barber, else the first city', () {
    final cities = [tripoli, benghazi];
    final inBenghazi = rankBarbers(allListings, areas: testAreas, origin: const LatLng(32.10, 20.08));

    expect(defaultCityId(nearest: inBenghazi, areas: testAreas, cities: cities), 'benghazi');
    expect(
      defaultCityId(
        nearest: rankBarbers(allListings, areas: testAreas),
        areas: testAreas,
        cities: cities,
      ),
      'tripoli',
    );
  });

  group('openState', () {
    final hours = weekHours('ali').first;
    DateTime at(int h, int m) => DateTime(2026, 10, 11, h, m);

    test('before opening, during and after', () {
      expect(openState(hours: hours, now: at(9, 0)), isA<OpensLater>());
      expect((openState(hours: hours, now: at(9, 0)) as OpensLater).at, const TimeOfDay(hour: 10, minute: 0));
      expect(openState(hours: hours, now: at(10, 0)), isA<OpenNow>());
      expect(openState(hours: hours, now: at(21, 59)), isA<OpenNow>());
      expect(openState(hours: hours, now: at(22, 0)), isA<ClosedToday>());
    });

    test('a day off, no hours or a whole-day closure is closed', () {
      expect(openState(hours: weekHours('ali')[5], now: at(12, 0)), isA<ClosedToday>());
      expect(openState(now: at(12, 0)), isA<ClosedToday>());
      expect(
        openState(
          hours: hours,
          closure: DayClosure(barberId: 'ali', date: DateTime(2026, 10, 11)),
          now: at(12, 0),
        ),
        isA<ClosedToday>(),
      );
    });

    test('closing the rest of the day ends the opening early', () {
      final closure = DayClosure(
        barberId: 'ali',
        date: DateTime(2026, 10, 11),
        fromTime: const TimeOfDay(hour: 15, minute: 0),
      );

      expect(openState(hours: hours, closure: closure, now: at(14, 59)), isA<OpenNow>());
      expect(openState(hours: hours, closure: closure, now: at(15, 0)), isA<ClosedToday>());
    });
  });
}
