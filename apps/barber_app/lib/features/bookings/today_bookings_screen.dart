import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'booking_card.dart';
import 'cancel_reason_sheet.dart';
import 'close_day_sheet.dart';
import 'manual_booking_sheet.dart';
import 'subscription_banner.dart';
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

  /// Marks attended or no-show, then offers to undo a wrong tap.
  Future<void> _mark(Booking booking, BookingStatus status) async {
    final notifier = ref.read(todayBookingsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    var done = false;
    await _run(booking.id, () async {
      await (status == BookingStatus.completed ? notifier.markAttended(booking.id) : notifier.markNoShow(booking.id));
      done = true;
    });
    if (!done || !mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == BookingStatus.completed
              ? 'سُجّل حضور ${booking.displayName}'
              : 'سُجّل عدم حضور ${booking.displayName}',
        ),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            if (mounted) _run(booking.id, () => notifier.undoStatus(booking.id));
          },
        ),
      ),
    );
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
    final day = ref.watch(bookingsDayProvider);
    ref.watch(minuteTickerProvider);
    final notifier = ref.read(todayBookingsProvider.notifier);
    final list = bookings.value ?? const <Booking>[];
    final now = AppTime.now();
    final today = AppTime.startOfDay(now);
    final days = [
      for (var i = 0; i < AppConstants.bookingDays; i++) AppTime.startOfDay(today.add(Duration(days: i, hours: 12))),
    ];
    final dayIndex = days.indexWhere((d) => dbDate(d) == dbDate(day));
    final isToday = dayIndex == 0;

    final active = list.where((b) => b.status != BookingStatus.cancelled).toList();
    final completed = active.where((b) => b.status == BookingStatus.completed).length;
    final remaining = active.where((b) => b.status == BookingStatus.confirmed).length;
    final next = isToday ? list.where((b) => b.isOpen && b.endsAt.isAfter(now)).firstOrNull : null;
    final bookable = barber?.isBookable ?? true;
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
                    title: isToday ? 'حجوزات اليوم' : 'حجوزات ${DayTile.labelFor(dayIndex, day)}',
                    subtitle: ArabicFormat.dayDate(day),
                    trailing: LetterAvatar(
                      name: barber?.displayName ?? '',
                      imageUrl: publicStorageUrl(barber?.photoUrl),
                      background: AppColors.bluePressed,
                    ),
                    bottom: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: isToday ? 'حجز اليوم' : 'الحجوزات',
                            value: '${active.length}',
                            compact: true,
                          ),
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
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppSizes.numberBox,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                        itemCount: days.length,
                        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, i) => DayTile(
                          label: DayTile.labelFor(i, days[i]),
                          day: days[i].day,
                          selected: i == dayIndex,
                          onTap: () => ref.read(bookingsDayProvider.notifier).select(days[i]),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isToday && closure == null && bookable)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
                    sliver: SliverToBoxAdapter(
                      child: ActionButton(
                        label: 'إغلاق بقية اليوم',
                        icon: Icons.door_front_door_outlined,
                        foreground: AppColors.danger,
                        background: AppColors.surface,
                        border: AppColors.border,
                        onPressed: () => closeRestOfTodayFlow(context, ref),
                      ),
                    ),
                  ),
                if (!bookable)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, 0),
                    sliver: SliverToBoxAdapter(child: SubscriptionBanner(barber: barber!)),
                  ),
                if (closure != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, 0),
                    sliver: SliverToBoxAdapter(
                      child: _DayClosedBanner(
                        closure: closure,
                        isToday: isToday,
                        reopening: _reopening,
                        onReopen: _reopen,
                      ),
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
                      child: Text(
                        isToday ? 'لا توجد حجوزات اليوم' : 'لا توجد حجوزات في هذا اليوم',
                        style: AppText.h3.copyWith(color: AppColors.text3),
                      ),
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
                          onAttended: () => _mark(b, BookingStatus.completed),
                          onNoShow: () => _mark(b, BookingStatus.noShow),
                          onCancel: () => _cancel(b),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (bookable)
            PositionedDirectional(
              start: AppSpacing.screen,
              end: AppSpacing.screen,
              bottom: bottomInset + AppSpacing.md,
              child: AppButton(
                label: 'إضافة حجز يدوي',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.accent,
                onPressed: () => showManualBookingSheet(context, day: day),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayClosedBanner extends StatelessWidget {
  const _DayClosedBanner({
    required this.closure,
    required this.isToday,
    required this.reopening,
    required this.onReopen,
  });

  final DayClosure closure;
  final bool isToday;
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
                Text(isToday ? 'اليوم مغلق' : 'هذا اليوم مغلق', style: AppText.cardTitle),
                Text(
                  from == null
                      ? 'لا يمكن للزبائن الحجز في هذا اليوم'
                      : 'لا يمكن للزبائن الحجز بعد ${ArabicFormat.clock(from.hour, from.minute)}',
                  style: AppText.caption.copyWith(color: AppColors.text3),
                ),
              ],
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: reopening ? null : onReopen, child: const Text('إعادة الفتح')),
          ],
        ],
      ),
    );
  }
}
