import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

/// The day the bookings tab shows, as the start of that day: today, or one of the days after it up to
/// [AppConstants.bookingDays]. Goes back to the new today at midnight.
final bookingsDayProvider = NotifierProvider<BookingsDay, DateTime>(BookingsDay.new);

class BookingsDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final today = AppTime.dayRange(AppTime.now());
    final midnight = Timer(today.end.difference(AppTime.now()), ref.invalidateSelf);
    ref.onDispose(midnight.cancel);
    return today.start;
  }

  void select(DateTime day) => state = AppTime.startOfDay(day);
}

/// The barber's bookings on the day in [bookingsDayProvider].
final todayBookingsProvider = AsyncNotifierProvider.autoDispose<TodayBookings, List<Booking>>(TodayBookings.new);

class TodayBookings extends AsyncNotifier<List<Booking>> {
  BookingRepository get _repo => ref.read(bookingRepositoryProvider);

  @override
  Future<List<Booking>> build() async {
    final day = ref.watch(bookingsDayProvider);
    return _load(await ref.watch(currentBarberProvider.future), day);
  }

  Future<List<Booking>> _load(Barber? barber, DateTime day) async {
    if (barber == null) return const [];
    return _repo.bookingsForDay(barberId: barber.id, day: day);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async => _load(await ref.read(currentBarberProvider.future), ref.read(bookingsDayProvider)),
    );
  }

  Future<void> _apply(Future<Booking> action) async {
    await action;
    ref.invalidate(statsProvider);
    await refresh();
  }

  Future<void> markAttended(String id) => _apply(_repo.setStatus(id, BookingStatus.completed));

  Future<void> markNoShow(String id) => _apply(_repo.setStatus(id, BookingStatus.noShow));

  /// Puts an attended or no-show booking back to confirmed, for a wrong tap.
  Future<void> undoStatus(String id) => _apply(_repo.setStatus(id, BookingStatus.confirmed));

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
    ref.invalidate(statsProvider);
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

/// The closure of the day in [bookingsDayProvider], if the barber closed it.
final todayClosureProvider = FutureProvider.autoDispose<DayClosure?>((ref) async {
  ref.watch(todayBookingsProvider);
  final day = ref.watch(bookingsDayProvider);
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(bookingRepositoryProvider).closureOn(barberId: barber.id, day: day);
});

final minuteTickerProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (_) => AppTime.now()),
);
