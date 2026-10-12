import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../../services/location_service.dart';

const tripoli = LatLng(32.8872, 13.1913);
const _minZoom = 4.0;
const _startZoom = 12.0;
const _pointZoom = 16.0;

/// Map with a fixed pin at its centre: the barber moves the map under the pin, or uses the device location.
class LocationMap extends ConsumerStatefulWidget {
  const LocationMap({super.key, this.point, this.onChanged, this.readOnly = false, this.topInset = 0});

  final LatLng? point;
  final ValueChanged<LatLng>? onChanged;
  final bool readOnly;

  /// Space kept free at the top for a title floating over the map.
  final double topInset;

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap> {
  final _controller = MapController();
  var _ready = false;
  var _locating = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationMap old) {
    super.didUpdateWidget(old);
    final p = widget.point;
    if (!_ready || p == null) return;
    final center = _controller.camera.center;
    if ((center.latitude - p.latitude).abs() > 1e-6 || (center.longitude - p.longitude).abs() > 1e-6) {
      _controller.move(p, _pointZoom);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _message = result.failure == null ? null : locationFailureMessage(result.failure!);
    });
    final point = result.point;
    if (point == null) return;
    _controller.move(point, _pointZoom);
    widget.onChanged?.call(point);
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final showPin = point != null || !widget.readOnly;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: point ?? tripoli,
            initialZoom: point == null ? _startZoom : _pointZoom,
            minZoom: _minZoom,
            interactionOptions: InteractionOptions(
              flags: widget.readOnly ? InteractiveFlag.none : InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _ready = true,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && !widget.readOnly) widget.onChanged?.call(camera.center);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ly.hallaqi.barber_app',
              tileProvider: ref.watch(mapTileProviderProvider),
            ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              showFlutterMapAttribution: false,
              attributions: [TextSourceAttribution('مساهمو OpenStreetMap')],
            ),
          ],
        ),
        if (showPin) const IgnorePointer(child: Center(child: _Pin())),
        if (!widget.readOnly && point == null)
          PositionedDirectional(
            top: AppSpacing.md + widget.topInset,
            start: AppSpacing.md,
            end: AppSpacing.md,
            child: const _MapNote('حرّك الخريطة لتحديد مكان الصالون'),
          ),
        if (widget.readOnly && point == null) const Center(child: _MapNote('لم يحدد الصالون موقعه بعد')),
        if (_message != null)
          PositionedDirectional(
            top: AppSpacing.md + widget.topInset,
            start: AppSpacing.md,
            end: AppSpacing.md,
            child: _MapNote(_message!, error: true),
          ),
        if (!widget.readOnly)
          PositionedDirectional(
            bottom: AppSpacing.xl,
            start: 0,
            end: 0,
            child: Center(
              child: FilledButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.actionButton),
                  backgroundColor: AppColors.poleRed,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  shape: const StadiumBorder(),
                ),
                icon: _locating
                    ? const SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(strokeWidth: AppSizes.spinnerStroke, color: AppColors.surface),
                      )
                    : const Icon(Icons.my_location_rounded, size: AppSizes.iconMd),
                label: const Text('استخدم موقعي الحالي'),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -AppSizes.heroIcon / 2),
      child: SizedBox(
        width: AppSizes.heroIcon,
        height: AppSizes.heroIcon,
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.location_on, size: AppSizes.heroIcon, color: AppColors.blue900),
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Icon(Icons.content_cut_rounded, size: AppSizes.iconMd, color: AppColors.red400),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapNote extends StatelessWidget {
  const _MapNote(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(color: error ? AppColors.danger : AppColors.text2),
      ),
    );
  }
}
