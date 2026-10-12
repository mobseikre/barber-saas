import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../../services/photo_service.dart';
import '../auth/salon_picker.dart';
import '../location/location_map.dart';
import '../location/salon_fields.dart';
import 'registration_draft.dart';

const _newSalonMapHeight = 260.0;
const _joinedSalonMapHeight = 160.0;
const _dashLength = 5.0;

/// Photo, salon and salon location, shared by sign-up and complete registration.
class RegistrationDetails extends ConsumerWidget {
  const RegistrationDetails({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final salon = draft.salon;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoTile(
              photo: draft.photo,
              onTap: () async {
                final picked = await ref.read(photoServiceProvider).pick();
                if (picked != null && context.mounted) draft.setPhoto(picked);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            SalonPicker(selected: salon, onChanged: draft.selectSalon),
            const SizedBox(height: AppSpacing.xl),
            if (salon != null) _JoinedSalon(salon: salon) else _NewSalon(draft: draft),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onTap});

  final PickedPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Row(
        children: [
          CustomPaint(
            foregroundPainter: photo == null ? const _DashedCirclePainter() : null,
            child: Container(
              key: const ValueKey('photo-circle'),
              width: AppSizes.photoPicker,
              height: AppSizes.photoPicker,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(color: AppColors.red50, shape: BoxShape.circle),
              child: photo == null
                  ? const Icon(Icons.photo_camera_outlined, color: AppColors.red700)
                  : Image.memory(photo!.bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صورتك أو صورة الصالون', style: AppText.cardTitle),
                Text(
                  photo == null ? 'تظهر للزبائن في صفحتك' : 'اضغط لتغيير الصورة',
                  style: AppText.caption.copyWith(color: AppColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addOval(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.border
      ..color = AppColors.red600;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dashLength * 2) {
        canvas.drawPath(metric.extractPath(d, d + _dashLength), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NewSalon extends StatelessWidget {
  const _NewSalon({required this.draft});

  final RegistrationDraft draft;

  @override
  Widget build(BuildContext context) {
    final location = draft.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('موقع صالونك'),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: _newSalonMapHeight,
            child: ListenableBuilder(
              listenable: location,
              builder: (context, _) => LocationMap(point: location.point, onChanged: location.setPoint),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SalonFields(controller: location),
        const SizedBox(height: AppSpacing.sm),
        Text('يمكنك تعديل الموقع لاحقاً من حسابي.', style: AppText.caption.copyWith(color: AppColors.text3)),
      ],
    );
  }
}

class _JoinedSalon extends StatelessWidget {
  const _JoinedSalon({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final lat = salon.latitude, lng = salon.longitude;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('موقع الصالون'),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: _joinedSalonMapHeight,
            child: LocationMap(point: lat == null || lng == null ? null : LatLng(lat, lng), readOnly: true),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (salon.address != null) Text(salon.address!, style: AppText.body.copyWith(color: AppColors.text2)),
        Text('يحدد مالك الصالون موقعه ولا يمكنك تعديله.', style: AppText.caption.copyWith(color: AppColors.text3)),
      ],
    );
  }
}
