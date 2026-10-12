import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('Booking reads the joins, status, source and cancellation', () {
    final b = Booking.fromJson({
      'id': 'k1',
      'barber_id': 'b1',
      'customer_id': 'c1',
      'customer_name': null,
      'customer': {'full_name': 'سالم بن عامر', 'phone': '218911002030'},
      'service_id': 's1',
      'service': {'name_ar': 'قص شعر'},
      'price': '25.00',
      'duration_min': 30,
      'time_range': '["2026-10-11 08:00:00+00","2026-10-11 08:30:00+00")',
      'status': 'cancelled',
      'source': 'app',
      'cancelled_at': '2026-10-11T07:00:00+00:00',
      'cancelled_by': 'u2',
      'cancel_reason': 'emergency',
      'cancel_note': 'طارئ',
      'created_at': '2026-10-10T08:00:00+00:00',
    });

    expect(b.displayName, 'سالم بن عامر');
    expect(b.customerPhone, '218911002030');
    expect(b.serviceName, 'قص شعر');
    expect(b.price, 25.0);
    expect(b.startsAt.toUtc(), DateTime.utc(2026, 10, 11, 8));
    expect(b.endsAt.toUtc(), DateTime.utc(2026, 10, 11, 8, 30));
    expect(b.status, BookingStatus.cancelled);
    expect(b.cancelReason, BarberCancelReason.emergency);
    expect(b.cancelNote, 'طارئ');
    expect(b.isOpen, isFalse);
  });

  test('a manual Booking keeps the typed name and no-show status', () {
    final b = Booking.fromJson({
      'id': 'k2',
      'barber_id': 'b1',
      'customer_id': null,
      'customer_name': 'يوسف المصراتي',
      'service_id': 's1',
      'price': 15,
      'duration_min': 20,
      'time_range': '["2026-10-11 08:00:00+00","2026-10-11 08:20:00+00")',
      'status': 'no_show',
      'source': 'manual',
      'created_at': '2026-10-10T08:00:00+00:00',
    });

    expect(b.displayName, 'يوسف المصراتي');
    expect(b.isManual, isTrue);
    expect(b.status, BookingStatus.noShow);
    expect(b.customerPhone, isNull);
  });

  test('Barber parses status, VIP, rating and the subscription end', () {
    final b = Barber.fromJson({
      'id': 'b1',
      'profile_id': 'u1',
      'salon_id': 's1',
      'display_name': 'علي القماطي',
      'photo_url': null,
      'is_vip': true,
      'status': 'suspended',
      'subscription_ends_at': '2026-11-11T18:00:00+00:00',
      'rating_avg': 4.5,
      'rating_count': 12,
      'created_at': '2026-10-01T00:00:00+00:00',
    });

    expect(b.status, BarberStatus.suspended);
    expect(b.isVip, isTrue);
    expect(b.ratingAvg, 4.5);
    expect(b.ratingCount, 12);
    expect(b.subscriptionEndsAt!.toUtc(), DateTime.utc(2026, 11, 11, 18));
    expect(b.isBookable, isFalse, reason: 'suspended');
  });

  test('Barber without subscription or rating uses defaults', () {
    final b = Barber.fromJson({
      'id': 'b2',
      'profile_id': null,
      'salon_id': 's1',
      'display_name': 'مراد',
      'status': 'pending',
      'created_at': '2026-10-01T00:00:00+00:00',
    });

    expect(b.subscriptionEndsAt, isNull);
    expect(b.ratingAvg, 0);
    expect(b.isVip, isFalse);
    expect(b.isBookable, isFalse);
  });

  test('BarberService reads the catalog join and round-trips to JSON', () {
    final s = BarberService.fromJson({
      'barber_id': 'b1',
      'service_id': 's1',
      'price': '100.00',
      'duration_min': 75,
      'is_enabled': false,
      'service_catalog': {'name_ar': 'VIP', 'sort_order': 5},
    });

    expect(s.nameAr, 'VIP');
    expect(s.price, 100.0);
    expect(s.isEnabled, isFalse);
    expect(s.toJson(), {
      'barber_id': 'b1',
      'service_id': 's1',
      'price': 100.0,
      'duration_min': 75,
      'is_enabled': false,
    });
  });

  test('Salon reads GeoJSON coordinates as longitude, latitude', () {
    final s = Salon.fromJson({
      'id': 's1',
      'name': 'صالون الأناقة',
      'owner_id': 'u1',
      'area_id': null,
      'address': 'شارع الجمهورية',
      'location': {
        'type': 'Point',
        'coordinates': [13.1913, 32.8872],
      },
      'photos': ['a.jpg'],
      'created_at': '2026-10-01T00:00:00+00:00',
    });

    expect(s.longitude, 13.1913);
    expect(s.latitude, 32.8872);
    expect(s.areaId, isNull);
    expect(s.photos, ['a.jpg']);
  });

  test('Profile reads role, no-shows and block state', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'role': 'customer',
      'full_name': 'خالد',
      'phone': '218911002030',
      'avatar_url': null,
      'city_id': null,
      'no_show_count': 3,
      'blocked_at': '2026-10-10T08:00:00+00:00',
      'created_at': '2026-10-01T00:00:00+00:00',
    });

    expect(p.role, UserRole.customer);
    expect(p.noShowCount, 3);
    expect(p.isBlocked, isTrue);
  });

  test('WorkingHours, Break and DayClosure parse Postgres times', () {
    final h = WorkingHours.fromJson({
      'barber_id': 'b1',
      'weekday': 5,
      'opens_at': '10:00:00',
      'closes_at': '22:30:00',
      'is_closed': true,
    });
    expect(h.weekday, 5);
    expect(h.closesAt, const TimeOfDay(hour: 22, minute: 30));
    expect(h.isClosed, isTrue);
    expect(h.toJson()['closes_at'], '22:30');

    final br = Break.fromJson({
      'id': 'x1',
      'barber_id': 'b1',
      'weekday': null,
      'name': 'غداء وصلاة',
      'starts_at': '13:30:00',
      'ends_at': '14:30:00',
    });
    expect(br.weekday, isNull);
    expect(br.startsAt, const TimeOfDay(hour: 13, minute: 30));

    final partial = DayClosure.fromJson({
      'id': 'd1',
      'barber_id': 'b1',
      'date': '2026-10-11',
      'from_time': '20:15:42.123',
      'reason': 'closed_early',
    });
    expect(partial.fromTime, const TimeOfDay(hour: 20, minute: 15));
    expect(partial.isWholeDay, isFalse);
    expect((partial.date.year, partial.date.month, partial.date.day), (2026, 10, 11));

    final whole = DayClosure.fromJson({'id': 'd2', 'barber_id': 'b1', 'date': '2026-10-12', 'from_time': null});
    expect(whole.isWholeDay, isTrue);
  });

  test('Review, SubscriptionPayment and lookups', () {
    final r = Review.fromJson({
      'id': 'r1',
      'booking_id': 'k1',
      'barber_id': 'b1',
      'salon_id': 's1',
      'customer_id': 'c1',
      'rating': 5,
      'tags': ['نظيف', 'سريع'],
      'comment': null,
      'created_at': '2026-10-11T09:00:00+00:00',
    });
    expect(r.rating, 5);
    expect(r.tags, ['نظيف', 'سريع']);

    final pay = SubscriptionPayment.fromJson({
      'id': 'p1',
      'barber_id': 'b1',
      'amount': '50.00',
      'paid_at': '2026-10-11T09:00:00+00:00',
      'period_start': '2026-10-11T09:00:00+00:00',
      'period_end': '2026-11-11T09:00:00+00:00',
      'recorded_by': 'admin',
      'note': 'نقداً',
    });
    expect(pay.amount, 50.0);
    expect(pay.periodEnd.difference(pay.periodStart).inDays, 31);

    expect(City.fromJson({'id': 'c1', 'name': 'طرابلس'}).sortOrder, 0);
    expect(Area.fromJson({'id': 'a1', 'city_id': 'c1', 'name': 'حي الأندلس', 'sort_order': 2}).cityId, 'c1');
    final item = ServiceCatalogItem.fromJson({
      'id': 's1',
      'code': 'haircut',
      'name_ar': 'قص شعر',
      'description_ar': null,
      'default_duration_min': 30,
    });
    expect(item.code, 'haircut');
    expect(item.defaultDurationMin, 30);
  });

  test('payment dates are Tripoli wall time, so a late-evening UTC payment shows the next day', () {
    final pay = SubscriptionPayment.fromJson({
      'id': 'p1',
      'barber_id': 'b1',
      'amount': 50,
      'paid_at': '2026-10-10T22:30:00+00:00',
      'period_start': '2026-10-10T22:30:00+00:00',
      'period_end': '2026-11-10T22:30:00+00:00',
      'recorded_by': 'admin',
    });

    expect([pay.periodStart.day, pay.periodStart.hour], [11, 0]);
    expect(pay.paidAt.day, 11);
    expect(pay.periodEnd.isAtSameMomentAs(DateTime.utc(2026, 11, 10, 22, 30)), isTrue);
  });

  group('Barber.daysLeft', () {
    final now = DateTime.utc(2026, 10, 8, 10);
    setUp(() => AppTime.clock = () => now);
    tearDown(() => AppTime.clock = DateTime.now);

    Barber endingIn(Duration? left) => Barber(
      id: 'b1',
      salonId: 's1',
      displayName: 'علي',
      status: BarberStatus.active,
      subscriptionEndsAt: left == null ? null : now.add(left),
      createdAt: DateTime(2026),
    );

    test('a started day counts as a whole day', () {
      expect(endingIn(const Duration(days: 3, hours: 1)).daysLeft, 4);
      expect(endingIn(const Duration(hours: 2)).daysLeft, 1);
      expect(endingIn(const Duration(days: 30)).daysLeft, 30);
    });

    test('an ended or missing subscription has 0 days left', () {
      expect(endingIn(Duration.zero).daysLeft, 0);
      expect(endingIn(const Duration(days: -2)).daysLeft, 0);
      expect(endingIn(null).daysLeft, 0);
    });
  });

  test('isAfter compares times of day', () {
    expect(isAfter(const TimeOfDay(hour: 13, minute: 0), const TimeOfDay(hour: 12, minute: 59)), isTrue);
    expect(isAfter(const TimeOfDay(hour: 12, minute: 0), const TimeOfDay(hour: 12, minute: 0)), isFalse);
    expect(isAfter(const TimeOfDay(hour: 9, minute: 30), const TimeOfDay(hour: 10, minute: 0)), isFalse);
  });
}
