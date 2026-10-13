import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'salon_location_controller.dart';

/// Address, city and area of a salon. With [readOnly] it shows them as plain text.
class SalonFields extends ConsumerWidget {
  const SalonFields({super.key, required this.controller, this.readOnly = false});

  final SalonLocationController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(citiesProvider);
    final areas = ref.watch(areasProvider);

    if (cities.hasError || areas.hasError) {
      return RetryMessage(
        inline: true,
        message: genericErrorMessage,
        onRetry: () {
          ref.invalidate(citiesProvider);
          ref.invalidate(areasProvider);
        },
      );
    }
    final cityList = cities.value ?? const <City>[];
    final areaList = areas.value ?? const <Area>[];

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cityAreas = [
          for (final a in areaList)
            if (a.cityId == controller.cityId) a,
        ];
        final cityName = cityList.where((c) => c.id == controller.cityId).firstOrNull?.name;
        final areaName = areaList.where((a) => a.id == controller.areaId).firstOrNull?.name;
        if (readOnly) {
          final parts = [
            if (controller.address.text.trim().isNotEmpty) controller.address.text.trim(),
            ?areaName,
            ?cityName,
          ];
          return Text(
            parts.isEmpty ? 'لم يحدد الصالون عنوانه بعد' : parts.join('، '),
            style: AppText.body.copyWith(color: AppColors.text2),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('العنوان'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller.address,
              minLines: 2,
              maxLines: 3,
              style: AppText.body,
              decoration: const InputDecoration(hintText: 'مثال: شارع النصر، بجانب مسجد الصحابة'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Dropdown(
                    label: 'المدينة',
                    value: cityList.any((c) => c.id == controller.cityId) ? controller.cityId : null,
                    items: [for (final c in cityList) (c.id, c.name)],
                    onChanged: controller.setCity,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Dropdown(
                    label: 'المنطقة',
                    value: cityAreas.any((a) => a.id == controller.areaId) ? controller.areaId : null,
                    items: [for (final a in cityAreas) (a.id, a.name)],
                    onChanged: controller.cityId == null ? null : controller.setArea,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: value,
          key: ValueKey('$label-$value-${items.length}'),
          isExpanded: true,
          hint: Text('اختر', style: AppText.body.copyWith(color: AppColors.text3)),
          items: [
            for (final (id, name) in items)
              DropdownMenuItem(
                value: id,
                child: Text(name, style: AppText.body),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
