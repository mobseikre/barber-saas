import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (status) {
      BookingStatus.confirmed => (AppColors.info, AppColors.infoBg, Icons.schedule_rounded),
      BookingStatus.completed => (AppColors.success, AppColors.successBg, Icons.check_rounded),
      BookingStatus.noShow => (AppColors.warning, AppColors.warningBg, Icons.error_outline_rounded),
      BookingStatus.cancelled => (AppColors.danger, AppColors.dangerBg, Icons.close_rounded),
    };
    return Container(
      height: AppSizes.badge,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.badge)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.badgeIcon, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(status.labelAr, style: AppText.weight(AppText.caption.copyWith(color: fg), FontWeight.w700)),
        ],
      ),
    );
  }
}

class VipBadge extends StatelessWidget {
  const VipBadge({super.key, this.label = 'VIP'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.badge,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.blue900, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: AppSizes.badgeIcon, color: AppColors.red400),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppText.weight(AppText.caption.copyWith(color: AppColors.red400), FontWeight.w800)),
        ],
      ),
    );
  }
}
