import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// 50×30 pill switch from the design system.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const inset = (AppSizes.switchHeight - AppSizes.switchThumb) / 2;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: AppSizes.switchWidth,
          height: AppSizes.switchHeight,
          padding: const EdgeInsets.all(inset),
          alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: value ? AppColors.blue900 : AppColors.switchOff,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Container(
            width: AppSizes.switchThumb,
            height: AppSizes.switchThumb,
            decoration: BoxDecoration(color: value ? AppColors.poleRed : AppColors.surface, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
