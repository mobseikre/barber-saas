import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'data/directory_repository.dart';
import 'data/my_bookings_repository.dart';
import 'data/offline_cache.dart';
import 'features/home/ranking.dart';

final directoryRepositoryProvider = Provider((ref) => DirectoryRepository(ref.watch(supabaseClientProvider)));
final myBookingsRepositoryProvider = Provider((ref) => MyBookingsRepository(ref.watch(supabaseClientProvider)));

/// Asked once per session; invalidate it to ask again after the user changes the permission.
final userLocationProvider = FutureProvider<LocationResult>((ref) => ref.watch(locationServiceProvider).current());

final directoryProvider = FutureProvider<List<BarberListing>>(
  (ref) => ref.watch(directoryRepositoryProvider).bookableBarbers(),
);

/// The home list in both orders, ranked once per change of barbers, areas or location.
final homeRankingProvider = Provider<({List<RankedBarber> nearest, List<RankedBarber> topRated})>((ref) {
  final barbers = ref.watch(directoryProvider).value ?? const <BarberListing>[];
  final areas = ref.watch(areasProvider).value ?? const <Area>[];
  final origin = ref.watch(userLocationProvider).value?.point;
  return (
    nearest: rankBarbers(barbers, areas: areas, origin: origin),
    topRated: rankBarbers(barbers, areas: areas, origin: origin, sort: HomeSort.topRated),
  );
});

final barberTodayProvider = FutureProvider<Map<String, BarberToday>>((ref) async {
  final barbers = await ref.watch(directoryProvider.future);
  return ref.watch(directoryRepositoryProvider).today([for (final b in barbers) b.id], AppTime.now());
});

final salonListingsProvider = FutureProvider.autoDispose.family<List<BarberListing>, String>(
  (ref, salonId) => ref.watch(directoryRepositoryProvider).salonListings(salonId),
);

final salonBarbersProvider = FutureProvider.autoDispose.family<List<SalonBarber>, String>(
  (ref, salonId) => ref.watch(directoryRepositoryProvider).salonBarbers(salonId),
);

final salonHoursProvider = FutureProvider.autoDispose.family<List<SalonDayHours>, String>(
  (ref, salonId) => ref.watch(directoryRepositoryProvider).salonHours(salonId),
);

final barberServicesProvider = FutureProvider.autoDispose.family<List<BarberService>, String>((ref, barberId) async {
  final services = await ref.watch(barberRepositoryProvider).servicesOf(barberId);
  return [
    for (final s in services)
      if (s.isEnabled) s,
  ];
});

final workingHoursProvider = FutureProvider.autoDispose.family<List<WorkingHours>, String>(
  (ref, barberId) => ref.watch(barberRepositoryProvider).workingHoursOf(barberId),
);

/// Number of days a customer can book ahead, today included.
const bookingDays = 14;

final upcomingClosuresProvider = FutureProvider.autoDispose.family<List<DayClosure>, String>((ref, barberId) {
  final today = AppTime.now();
  return ref
      .watch(directoryRepositoryProvider)
      .closures(
        barberId,
        from: today,
        to: today.add(const Duration(days: bookingDays - 1)),
      );
});

typedef SlotQuery = ({String barberId, String date, int durationMin});

final availableSlotsProvider = FutureProvider.autoDispose.family<List<TimeSlot>, SlotQuery>(
  (ref, q) => ref
      .watch(bookingRepositoryProvider)
      .availableSlots(barberId: q.barberId, day: DateTime.parse('${q.date}T12:00:00Z'), durationMin: q.durationMin),
);

final myBookingsProvider = FutureProvider<List<MyBooking>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(myBookingsRepositoryProvider).load(userId);
});

final offlineStatusProvider = Provider<ValueNotifier<DateTime?>>((_) => offlineStatus);

/// When the data on screen was saved, while it comes from the local cache because the network is unreachable.
final offlineProvider = NotifierProvider<OfflineNotifier, DateTime?>(OfflineNotifier.new);

class OfflineNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final status = ref.watch(offlineStatusProvider);
    void sync() => state = status.value;
    status.addListener(sync);
    ref.onDispose(() => status.removeListener(sync));
    return status.value;
  }
}

final connectivityProvider = StreamProvider<bool>(
  (_) => Connectivity().onConnectivityChanged.map((results) => !results.contains(ConnectivityResult.none)),
);

/// Reloads everything the tabs and the salon page show.
void refreshAll(WidgetRef ref) {
  for (final provider in [
    citiesProvider,
    areasProvider,
    directoryProvider,
    barberTodayProvider,
    myBookingsProvider,
    currentProfileProvider,
  ]) {
    ref.invalidate(provider);
  }
  for (final family in [
    salonListingsProvider,
    salonBarbersProvider,
    salonHoursProvider,
    barberServicesProvider,
    workingHoursProvider,
    upcomingClosuresProvider,
  ]) {
    ref.invalidate(family);
  }
}
