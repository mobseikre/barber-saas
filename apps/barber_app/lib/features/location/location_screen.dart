import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'location_map.dart';
import 'salon_fields.dart';
import 'salon_location_controller.dart';

/// The salon's location. The owner can change it; a barber who joined the salon only sees it.
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final _location = SalonLocationController();
  Salon? _salon;
  var _isOwner = false;
  var _loading = true;
  var _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final barber = await ref.read(currentBarberProvider.future);
      if (barber == null) throw StateError('no barber');
      final repo = ref.read(barberRepositoryProvider);
      final salon = await repo.salon(barber.salonId);
      final areas = await ref.read(areasProvider.future);
      if (!mounted) return;
      _location.load(salon, areas);
      setState(() {
        _salon = salon;
        _isOwner = salon.ownerId != null && salon.ownerId == barber.profileId;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = bookingErrorMessage(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final point = _location.point;
    if (point == null) {
      setState(() => _error = 'حدد موقع الصالون على الخريطة أولاً');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final address = _location.address.text.trim();
      await ref
          .read(barberRepositoryProvider)
          .updateSalon(
            salonId: _salon!.id,
            areaId: _location.areaId,
            address: address.isEmpty ? null : address,
            latitude: point.latitude,
            longitude: point.longitude,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الموقع')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = bookingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RetryMessage(message: _loadError!, onRetry: _load),
                const SizedBox(height: AppSpacing.sm),
                AppButton(label: 'رجوع', variant: AppButtonVariant.text, onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: ListenableBuilder(
        listenable: _location,
        builder: (context, _) {
          final point = _location.point;
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LocationMap(
                        point: point,
                        readOnly: !_isOwner,
                        onChanged: _location.setPoint,
                        topInset: MediaQuery.paddingOf(context).top + AppSizes.actionButton + AppSpacing.md,
                      ),
                    ),
                    PositionedDirectional(
                      top: MediaQuery.paddingOf(context).top + AppSpacing.md,
                      start: AppSpacing.screen,
                      end: AppSpacing.screen,
                      child: Row(
                        children: [
                          const AppBackButton(),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            height: AppSizes.actionButton,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.control),
                              boxShadow: const [AppColors.cardShadow],
                            ),
                            child: Text('موقع الصالون', style: AppText.cardTitle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Panel(
                point: point,
                isOwner: _isOwner,
                controller: _location,
                error: _error,
                saving: _saving,
                onSave: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.point,
    required this.isOwner,
    required this.controller,
    required this.error,
    required this.saving,
    required this.onSave,
  });

  final LatLng? point;
  final bool isOwner;
  final SalonLocationController controller;
  final String? error;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final located = point != null;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSizes.actionButton,
                    height: AppSizes.actionButton,
                    decoration: BoxDecoration(
                      color: AppColors.red50,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: const Icon(Icons.location_on_outlined, color: AppColors.red700),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(located ? 'تم تحديد الموقع' : 'لم يُحدد الموقع بعد', style: AppText.cardTitle),
                        Text(
                          isOwner
                              ? 'حرّك الخريطة لضبط مكان الدبوس بدقة'
                              : 'موقع صالونك يحدده مالك الصالون ولا يمكنك تعديله',
                          style: AppText.caption.copyWith(color: AppColors.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SalonFields(controller: controller, readOnly: !isOwner),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(error!, style: AppText.caption.copyWith(color: AppColors.danger)),
              ],
              if (isOwner) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'حفظ الموقع', onPressed: onSave, loading: saving),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
