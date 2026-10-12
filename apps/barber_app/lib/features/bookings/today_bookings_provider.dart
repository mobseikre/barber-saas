import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

final todayBookingsProvider = AsyncNotifierProvider.autoDispose<TodayBookings, List<Booking>>(TodayBookings.new);

class TodayBookings extends AsyncNotifier<List<Booking>> {
  BookingRepository get _repo => ref.read(bookingRepositoryProvider);

  @override
  Future<List<Booking>> build() async {
    final now = AppTime.now();
    final rollover = Timer(AppTime.dayRange(now).end.difference(now), ref.invalidateSelf);
    ref.onDispose(rollover.cancel);
    return _load(await ref.watch(currentBarberProvider.future));
  }

  Future<List<Booking>> _load(Barber? barber) async {
    if (barber == null) return const [];
    return _repo.bookingsForDay(barberId: barber.id, day: AppTime.now());
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async => _load(await ref.read(currentBarberProvider.future)));
  }

  Future<void> _apply(Future<Booking> action) async {
    await action;
    await refresh();
  }

  Future<void> markAttended(String id) => _apply(_repo.setStatus(id, BookingStatus.completed));

  Future<void> markNoShow(String id) => _apply(_repo.setStatus(id, BookingStatus.noShow));

  Future<void> cancel(String id, {required BarberCancelReason reason, String? note}) =>
      _apply(_repo.cancel(id, reason: reason, note: note));

  /// Returns the confirmed bookings still left today after blocking the rest of the day.
  Future<List<Booking>> closeRestOfToday() async {
    final rows = await _repo.closeRestOfToday();
    final loaded = {for (final b in state.value ?? const <Booking>[]) b.id: b};
    return [for (final r in rows) loaded[r.id] ?? r];
  }

  Future<void> addManual({required String serviceId, required DateTime startsAt, required String customerName}) async {
    await _repo.createManualBooking(serviceId: serviceId, startsAt: startsAt, customerName: customerName);
    await refresh();
  }

  Future<void> reopenToday() async {
    await _repo.reopenToday();
    await refresh();
  }
}

final barberServicesProvider = FutureProvider.autoDispose<List<BarberService>>((ref) async {
  final services = await ref.watch(allBarberServicesProvider.future);
  return services.where((s) => s.isEnabled).toList();
});

final todayClosureProvider = FutureProvider.autoDispose<DayClosure?>((ref) async {
  ref.watch(todayBookingsProvider);
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(bookingRepositoryProvider).closureOn(barberId: barber.id, day: AppTime.now());
});

final minuteTickerProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (_) => AppTime.now()),
);
