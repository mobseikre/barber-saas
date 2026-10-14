import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Tappable time of day that opens the time picker.
class TimeChip extends StatelessWidget {
  const TimeChip({super.key, required this.time, required this.onChanged});

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.smallButton),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: AppSizes.timeChip,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.smallButton),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(ArabicFormat.clock(time.hour, time.minute), style: AppText.buttonCompact),
      ),
    );
  }
}
