import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

enum AppButtonVariant { primary, accent, secondary, secondaryOnDark, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;

  /// The small 40px button (r10, 14/700) that fits its label instead of filling the width.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final onTap = loading ? null : onPressed;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.accent || AppButtonVariant.secondaryOnDark => AppColors.surface,
      AppButtonVariant.secondary => AppColors.blue900,
      AppButtonVariant.text => AppColors.red700,
    };
    final child = loading
        ? SizedBox(
            width: AppSizes.spinner,
            height: AppSizes.spinner,
            child: CircularProgressIndicator(strokeWidth: AppSizes.spinnerStroke, color: spinnerColor),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: AppSizes.iconMd), const SizedBox(width: AppSpacing.sm)],
              Text(label),
            ],
          );

    final size = compact
        ? ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.cardButton)),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.smallButton)),
            ),
            textStyle: WidgetStatePropertyAll(AppText.buttonCompact),
          )
        : null;
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: onTap, style: size, child: child),
      AppButtonVariant.accent => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.poleRed,
        ).copyWith(overlayColor: const WidgetStatePropertyAll(AppColors.red600)).merge(size),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(onPressed: onTap, style: size, child: child),
      AppButtonVariant.secondaryOnDark => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.surface,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.bluePressed, width: AppSizes.border),
        ).merge(size),
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: onTap, style: size, child: child),
    };
  }
}

/// The 44px tinted buttons used for booking actions (حضر / لم يحضر / إلغاء).
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.background,
    this.icon,
    this.border,
    this.height = AppSizes.actionButton,
  });

  const ActionButton.attended({super.key, required this.onPressed, this.height = AppSizes.actionButton})
    : label = 'حضر',
      icon = Icons.check_rounded,
      foreground = AppColors.success,
      background = AppColors.successBg,
      border = null;

  const ActionButton.noShow({super.key, required this.onPressed, this.height = AppSizes.actionButton})
    : label = 'لم يحضر',
      icon = Icons.close_rounded,
      foreground = AppColors.warning,
      background = AppColors.warningBg,
      border = null;

  const ActionButton.cancel({super.key, required this.onPressed, this.height = AppSizes.actionButton})
    : label = 'إلغاء الحجز',
      icon = null,
      foreground = AppColors.danger,
      background = AppColors.surface,
      border = AppColors.border;

  final String label;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color background;
  final Color? border;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final compact = height == AppSizes.cardButton;
    final radius = BorderRadius.circular(compact ? AppRadius.smallButton : AppRadius.control);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: SizedBox(
        height: height,
        child: Material(
          color: background,
          borderRadius: radius,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: border == null ? null : Border.all(color: border!, width: AppSizes.border),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: AppSizes.iconSm, color: foreground),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      label,
                      style: (compact ? AppText.buttonCompact : AppText.buttonSmall).copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44×44 square icon button: call (dark), add (red) or back (outlined).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background = AppColors.blue900,
    this.foreground = AppColors.red400,
    this.outlined = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color background;
  final Color foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: outlined ? AppColors.surface : background,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            width: AppSizes.actionButton,
            height: AppSizes.actionButton,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: outlined ? Border.all(color: AppColors.border) : null,
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: outlined ? AppColors.blue900 : foreground),
          ),
        ),
      ),
    );
  }
}
