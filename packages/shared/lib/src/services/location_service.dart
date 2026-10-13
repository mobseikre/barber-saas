import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

enum LocationFailure { denied, deniedForever, serviceDisabled, unavailable }

class LocationResult {
  const LocationResult.found(LatLng this.point) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : point = null;

  final LatLng? point;
  final LocationFailure? failure;
}

abstract interface class LocationService {
  Future<LocationResult> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) return const LocationResult.failed(LocationFailure.denied);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return LocationResult.found(LatLng(position.latitude, position.longitude));
    } catch (_) {
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }
}

/// Opens the system screen that can fix [failure]: location services, or the app's permission settings.
Future<bool> openLocationSettingsFor(LocationFailure failure) =>
    failure == LocationFailure.serviceDisabled ? Geolocator.openLocationSettings() : Geolocator.openAppSettings();
