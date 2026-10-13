import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'services/photo_service.dart';

final currentBarberProvider = FutureProvider<Barber?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(barberRepositoryProvider).barberForProfile(userId);
});

final photoServiceProvider = Provider<PhotoService>((_) => const ImagePickerPhotoService());
final mapTileProviderProvider = Provider<TileProvider?>((_) => null);

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
