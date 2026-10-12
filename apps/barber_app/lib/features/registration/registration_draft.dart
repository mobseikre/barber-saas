import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../../services/photo_service.dart';
import '../location/salon_location_controller.dart';

/// What a barber chooses besides their account: photo, an existing salon or the location of a new one.
class RegistrationDraft extends ChangeNotifier {
  Salon? salon;
  PickedPhoto? photo;
  final location = SalonLocationController();

  void selectSalon(Salon? value) {
    salon = value;
    notifyListeners();
  }

  void setPhoto(PickedPhoto? value) {
    photo = value;
    notifyListeners();
  }

  @override
  void dispose() {
    location.dispose();
    super.dispose();
  }
}

/// Registers the barber through `register_barber`, then uploads the photo.
/// Returns false when only the photo failed; the registration itself has succeeded.
Future<bool> registerWithDraft(WidgetRef ref, {required String displayName, required RegistrationDraft draft}) async {
  final barbers = ref.read(barberRepositoryProvider);
  final joined = draft.salon;
  final location = draft.location;
  final address = location.address.text.trim();
  final barber = await barbers.registerBarber(
    displayName: displayName,
    salonId: joined?.id,
    areaId: joined == null ? location.areaId : null,
    address: joined == null && address.isNotEmpty ? address : null,
    latitude: joined == null ? location.point?.latitude : null,
    longitude: joined == null ? location.point?.longitude : null,
  );

  var photoSaved = true;
  final photo = draft.photo;
  if (photo != null) {
    try {
      await barbers.uploadAvatar(
        userId: ref.read(authRepositoryProvider).currentUserId!,
        barberId: barber.id,
        bytes: photo.bytes,
        contentType: photo.contentType,
      );
    } catch (_) {
      photoSaved = false;
    }
  }
  ref.invalidate(currentBarberProvider);
  return photoSaved;
}
