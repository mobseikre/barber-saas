import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Pill chip: dark when selected, outlined otherwise, with an optional [detail] such as a price.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.detail, required this.selected, required this.onTap});

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppText.buttonCompact.copyWith(color: selected ? AppColors.surface : AppColors.text);
    return Material(
      color: selected ? AppColors.blue900 : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.blue900 : AppColors.border, width: AppSizes.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Semantics(
          selected: selected,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: style),
                  if (detail != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      detail!,
                      style: AppText.weight(
                        style.copyWith(color: selected ? AppColors.red300 : AppColors.text3),
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
