import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'services/location_service.dart';
import 'services/photo_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) => supabase);

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final barberRepositoryProvider = Provider((ref) => BarberRepository(ref.watch(supabaseClientProvider)));
final bookingRepositoryProvider = Provider((ref) => BookingRepository(ref.watch(supabaseClientProvider)));

final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authRepositoryProvider).onAuthStateChange);

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUserId;
});

final currentProfileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(authRepositoryProvider).currentProfile();
});

final currentBarberProvider = FutureProvider<Barber?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(barberRepositoryProvider).barberForProfile(userId);
});

final locationServiceProvider = Provider<LocationService>((_) => const GeolocatorLocationService());
final photoServiceProvider = Provider<PhotoService>((_) => const ImagePickerPhotoService());
final mapTileProviderProvider = Provider<TileProvider?>((_) => null);

final citiesProvider = FutureProvider<List<City>>((ref) => ref.watch(barberRepositoryProvider).cities());
final areasProvider = FutureProvider<List<Area>>((ref) => ref.watch(barberRepositoryProvider).areas());

final serviceCatalogProvider = FutureProvider.autoDispose<List<ServiceCatalogItem>>(
  (ref) => ref.watch(barberRepositoryProvider).serviceCatalog(),
);

final allBarberServicesProvider = FutureProvider.autoDispose<List<BarberService>>((ref) async {
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberRepositoryProvider).servicesOf(barber.id);
});

final workingHoursProvider = FutureProvider.autoDispose<List<WorkingHours>>((ref) async {
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberRepositoryProvider).workingHoursOf(barber.id);
});

final breaksProvider = FutureProvider.autoDispose<List<Break>>((ref) async {
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return const [];
  return ref.watch(barberRepositoryProvider).breaksOf(barber.id);
});

final statsProvider = FutureProvider.autoDispose<BarberStats>((ref) => ref.watch(barberRepositoryProvider).stats());

final latestPaymentProvider = FutureProvider.autoDispose<SubscriptionPayment?>((ref) async {
  final barber = await ref.watch(currentBarberProvider.future);
  if (barber == null) return null;
  return ref.watch(barberRepositoryProvider).latestPayment(barber.id);
});
