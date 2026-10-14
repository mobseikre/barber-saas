import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

/// Lets the barber pick a new photo and saves it for their barber card and their profile.
Future<void> changeBarberPhoto(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final photo = await ref.read(photoServiceProvider).pick();
  if (photo == null) return;
  try {
    final barber = await ref.read(currentBarberProvider.future);
    await ref
        .read(barberRepositoryProvider)
        .uploadAvatar(
          userId: ref.read(authRepositoryProvider).currentUserId!,
          barberId: barber!.id,
          bytes: photo.bytes,
          contentType: photo.contentType,
        );
    ref.invalidate(currentBarberProvider);
    messenger.showSnackBar(const SnackBar(content: Text('تم تحديث الصورة')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(genericErrorMessage)));
  }
}
