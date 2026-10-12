import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'cancel_reason_sheet.dart';
import 'today_bookings_provider.dart';

/// Closes the rest of today after confirming, then lists the remaining bookings for the barber to cancel.
Future<void> closeRestOfTodayFlow(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إغلاق بقية اليوم؟'),
      content: const Text(
        'لن يتمكن الزبائن من الحجز لبقية اليوم. الحجوزات المؤكدة ستبقى حتى تلغيها بنفسك مع ذكر السبب.',
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('رجوع')),
        AppButton(
          label: 'إغلاق اليوم',
          variant: AppButtonVariant.accent,
          compact: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final List<Booking> remaining;
  try {
    remaining = await ref.read(todayBookingsProvider.notifier).closeRestOfToday();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    }
    return;
  }
  if (!context.mounted) return;

  await showAppBottomSheet<void>(
    context: context,
    isDismissible: remaining.isEmpty,
    enableDrag: remaining.isEmpty,
    showDragHandle: false,
    builder: (_) => _RemainingBookingsSheet(initial: remaining),
  );
  await ref.read(todayBookingsProvider.notifier).refresh();
}

String _remainingCount(int n) => switch (n) {
  1 => 'لديك حجز واحد متبقٍ.',
  2 => 'لديك حجزان متبقيان.',
  < 11 => 'لديك $n حجوزات متبقية.',
  _ => 'لديك $n حجزاً متبقياً.',
};

class _RemainingBookingsSheet extends ConsumerStatefulWidget {
  const _RemainingBookingsSheet({required this.initial});

  final List<Booking> initial;

  @override
  ConsumerState<_RemainingBookingsSheet> createState() => _RemainingBookingsSheetState();
}

class _RemainingBookingsSheetState extends ConsumerState<_RemainingBookingsSheet> {
  late var _remaining = List<Booking>.of(widget.initial);
  String? _busyId;
  String? _error;

  Future<void> _cancel(Booking booking) async {
    final choice = await showCancelReasonSheet(context, booking: booking);
    if (choice == null || !mounted) return;
    setState(() {
      _busyId = booking.id;
      _error = null;
    });
    try {
      await ref.read(todayBookingsProvider.notifier).cancel(booking.id, reason: choice.reason, note: choice.note);
      if (mounted) setState(() => _remaining = _remaining.where((b) => b.id != booking.id).toList());
    } catch (e) {
      if (mounted) setState(() => _error = bookingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تم إغلاق بقية اليوم', style: AppText.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            done
                ? 'لا توجد حجوزات متبقية اليوم.'
                : '${_remainingCount(_remaining.length)} ألغِ كل حجز مع ذكر السبب ليصل الإشعار للزبون.',
            style: AppText.body.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _remaining.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
              itemBuilder: (_, i) {
                final b = _remaining[i];
                return AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(ArabicFormat.time(b.startsAt), style: AppText.time, maxLines: 1, softWrap: false),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.displayName,
                                  style: AppText.cardTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (b.serviceName != null)
                                  Text(
                                    b.serviceName!,
                                    style: AppText.caption.copyWith(color: AppColors.text3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ActionButton.cancel(
                        height: AppSizes.cardButton,
                        onPressed: _busyId == null ? () => _cancel(b) : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: done ? 'تم' : 'إغلاق',
            variant: done ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
