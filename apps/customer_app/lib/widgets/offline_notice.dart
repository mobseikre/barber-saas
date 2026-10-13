import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers.dart';

/// Small "غير متصل" pill with the time of the cached data on screen.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
  });

  final EdgeInsetsGeometry padding;

  static const label = 'غير متصل';

  /// غير متصل · آخر تحديث 9:30 ص, with the date when it was not today.
  static String text(DateTime savedAt) {
    final saved = AppTime.from(savedAt);
    final today = dbDate(saved) == dbDate(AppTime.now());
    final when = today ? ArabicFormat.time(saved) : '${ArabicFormat.dayMonth(saved)} ${ArabicFormat.time(saved)}';
    return '$label · آخر تحديث $when';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAt = ref.watch(offlineProvider);
    if (savedAt == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: AppSizes.badge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(AppRadius.badge)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: AppSizes.badgeIcon, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Text(
                text(savedAt),
                style: AppText.weight(AppText.caption.copyWith(color: AppColors.warning), FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
