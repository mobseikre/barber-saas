import 'package:flutter/material.dart';

import '../format/arabic_format.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

/// One day of a horizontal day picker: a short label over the day of the month. Without [onTap] the day is shown
/// struck through, as a day that cannot be picked.
class DayTile extends StatelessWidget {
  const DayTile({super.key, required this.label, required this.day, required this.selected, required this.onTap});

  /// اليوم، غداً or the weekday, for the day [offset] days after today.
  static String labelFor(int offset, DateTime day) => switch (offset) {
    0 => 'اليوم',
    1 => 'غداً',
    _ => ArabicFormat.weekday(day),
  };

  final String label;
  final int day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = selected ? AppColors.surface : (enabled ? AppColors.text : AppColors.text3);
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: selected ? AppColors.blue900 : (enabled ? AppColors.surface : AppColors.dividerSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: selected ? AppColors.blue900 : AppColors.border, width: AppSizes.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            width: AppSizes.numberBox,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppText.label.copyWith(color: selected ? AppColors.red300 : AppColors.text3)),
                Text(
                  '$day',
                  style: AppText.time.copyWith(
                    color: fg,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: AppColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
