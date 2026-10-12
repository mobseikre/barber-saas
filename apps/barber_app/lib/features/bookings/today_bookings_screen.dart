import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'booking_card.dart';
import 'cancel_reason_sheet.dart';
import 'close_day_sheet.dart';
import 'manual_booking_sheet.dart';
import 'today_bookings_provider.dart';

class TodayBookingsScreen extends ConsumerStatefulWidget {
  const TodayBookingsScreen({super.key});

  @override
  ConsumerState<TodayBookingsScreen> createState() => _TodayBookingsScreenState();
}

class _TodayBookingsScreenState extends ConsumerState<TodayBookingsScreen> {
  final _busy = <String>{};
  var _reopening = false;

  Future<void> _run(String bookingId, Future<void> Function() action) async {
    if (!_busy.add(bookingId)) return;
    setState(() {});
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _cancel(Booking booking) async {
    if (_busy.contains(booking.id)) return;
    final choice = await showCancelReasonSheet(context, booking: booking);
    if (choice == null || !mounted) return;
    await _run(
      booking.id,
      () => ref.read(todayBookingsProvider.notifier).cancel(booking.id, reason: choice.reason, note: choice.note),
    );
  }

  Future<void> _reopen() async {
    setState(() => _reopening = true);
    try {
      await ref.read(todayBookingsProvider.notifier).reopenToday();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _reopening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(todayBookingsProvider);
    final closure = ref.watch(todayClosureProvider).value;
    final barber = ref.watch(currentBarberProvider).value;
    ref.watch(minuteTickerProvider);
    final notifier = ref.read(todayBookingsProvider.notifier);
    final list = bookings.value ?? const <Booking>[];
    final now = AppTime.now();

    final active = list.where((b) => b.status != BookingStatus.cancelled).toList();
    final completed = active.where((b) => b.status == BookingStatus.completed).length;
    final remaining = active.where((b) => b.status == BookingStatus.confirmed).length;
    final next = list.where((b) => b.isOpen && b.endsAt.isAfter(now)).firstOrNull;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: notifier.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: AppHeader(
                    title: 'حجوزات اليوم',
                    subtitle: ArabicFormat.dayDate(now),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'المزيد',
                      enabled: closure == null,
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                      onSelected: (v) => closeRestOfTodayFlow(context, ref),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'close',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.door_front_door_outlined,
                                color: AppColors.danger,
                                size: AppSizes.iconMd,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'إغلاق بقية اليوم',
                                  style: AppText.bodyStrong.copyWith(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: LetterAvatar(
                        name: barber?.displayName ?? '',
                        imageUrl: publicStorageUrl(barber?.photoUrl),
                      ),
                    ),
                    bottom: Row(
                      children: [
                        Expanded(
                          child: StatCard(label: 'حجز اليوم', value: '${active.length}', compact: true),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatCard(
                            label: 'مكتمل',
                            value: '$completed',
                            valueColor: AppColors.red300,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatCard(label: 'متبقي', value: '$remaining', compact: true),
                        ),
                      ],
                    ),
                  ),
                ),
                if (closure != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, 0),
                    sliver: SliverToBoxAdapter(
                      child: _DayClosedBanner(closure: closure, reopening: _reopening, onReopen: _reopen),
                    ),
                  ),
                if (bookings.isLoading && list.isEmpty)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (bookings.hasError && list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screen),
                        child: RetryMessage(message: bookingErrorMessage(bookings.error!), onRetry: notifier.refresh),
                      ),
                    ),
                  )
                else if (list.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('لا توجد حجوزات اليوم', style: AppText.h3.copyWith(color: AppColors.text3)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.xl,
                      AppSpacing.screen,
                      bottomInset + AppSizes.button + AppSpacing.md * 2,
                    ),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
                      itemBuilder: (_, i) {
                        final b = list[i];
                        return BookingCard(
                          booking: b,
                          isNext: b.id == next?.id,
                          busy: _busy.contains(b.id),
                          onAttended: () => _run(b.id, () => notifier.markAttended(b.id)),
                          onNoShow: () => _run(b.id, () => notifier.markNoShow(b.id)),
                          onCancel: () => _cancel(b),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.screen,
            end: AppSpacing.screen,
            bottom: bottomInset + AppSpacing.md,
            child: AppButton(
              label: 'إضافة حجز يدوي',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.accent,
              onPressed: () => showManualBookingSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayClosedBanner extends StatelessWidget {
  const _DayClosedBanner({required this.closure, required this.reopening, required this.onReopen});

  final DayClosure closure;
  final bool reopening;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final from = closure.fromTime;
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.door_front_door_outlined, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اليوم مغلق', style: AppText.cardTitle),
                Text(
                  from == null
                      ? 'لا يمكن للزبائن الحجز اليوم'
                      : 'لا يمكن للزبائن الحجز بعد ${ArabicFormat.clock(from.hour, from.minute)}',
                  style: AppText.caption.copyWith(color: AppColors.text3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: reopening ? null : onReopen, child: const Text('إعادة الفتح')),
        ],
      ),
    );
  }
}
