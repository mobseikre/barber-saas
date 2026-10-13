import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lookups.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/barber_repository.dart';
import '../repositories/booking_repository.dart';
import '../services/location_service.dart';
import '../supabase/supabase_service.dart';

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

final locationServiceProvider = Provider<LocationService>((_) => const GeolocatorLocationService());

final citiesProvider = FutureProvider<List<City>>((ref) => ref.watch(barberRepositoryProvider).cities());
final areasProvider = FutureProvider<List<Area>>((ref) => ref.watch(barberRepositoryProvider).areas());
