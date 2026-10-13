import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/my_bookings_repository.dart';
import '../../providers.dart';
import '../../widgets/offline_notice.dart';
import '../account/account_tab.dart';
import 'cancel_booking.dart';
import 'rating_screen.dart';

class MyBookingsTab extends ConsumerStatefulWidget {
  const MyBookingsTab({super.key});

  @override
  ConsumerState<MyBookingsTab> createState() => _MyBookingsTabState();
}

class _MyBookingsTabState extends ConsumerState<MyBookingsTab> {
  var _showPast = false;

  Future<void> _refresh() async {
    ref.invalidate(myBookingsProvider);
    await ref.read(myBookingsProvider.future).catchError((_) => const <MyBooking>[]);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final bookings = ref.watch(myBookingsProvider);
    final all = bookings.value ?? const <MyBooking>[];
    final upcoming = all.where((b) => b.isUpcoming).toList()
      ..sort((a, b) => a.booking.startsAt.compareTo(b.booking.startsAt));
    final past = all.where((b) => !b.isUpcoming).toList()
      ..sort((a, b) => b.booking.startsAt.compareTo(a.booking.startsAt));
    final shown = _showPast ? past : upcoming;
    final navSpace = AppBottomNav.spaceBelow(context);

    return StatusBarScrim(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: navSpace),
          children: [
            const PageTitle(title: 'حجوزاتي'),
            if (signedIn) ...[
              const OfflineNotice(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Segments(
                      upcomingCount: upcoming.length,
                      showPast: _showPast,
                      onChanged: (past) => setState(() => _showPast = past),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (bookings.hasError && !bookings.hasValue)
                      RetryMessage(
                        message: bookingErrorMessage(bookings.error!),
                        onRetry: () => ref.invalidate(myBookingsProvider),
                      )
                    else if (bookings.isLoading && !bookings.hasValue)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.xxxl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxxl),
                        child: Text(
                          _showPast ? 'لا توجد حجوزات سابقة' : 'لا توجد حجوزات قادمة',
                          style: AppText.body.copyWith(color: AppColors.text3),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      for (final (i, item) in shown.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                          child: _showPast ? _PastCard(item: item) : _UpcomingCard(item: item, first: i == 0),
                        ),
                  ],
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: SignInPrompt(message: 'سجّل الدخول لترى حجوزاتك'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.upcomingCount, required this.showPast, required this.onChanged});

  final int upcomingCount;
  final bool showPast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool selected, VoidCallback onTap) => Expanded(
      child: Material(
        color: selected ? AppColors.blue900 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Semantics(
            selected: selected,
            button: true,
            child: Container(
              height: AppSizes.actionButton - AppSpacing.sm,
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppText.buttonCompact.copyWith(color: selected ? AppColors.surface : AppColors.text2),
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.blue100,
        borderRadius: BorderRadius.circular(AppRadius.control + AppSpacing.xs),
      ),
      child: Row(
        children: [
          segment('القادمة (${ArabicFormat.number(upcomingCount)})', !showPast, () => onChanged(false)),
          segment('السابقة', showPast, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.item, required this.first});

  final MyBooking item;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = item.booking;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateTile(date: booking.startsAt, dark: first),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.salonName, style: AppText.h3),
                    Text(
                      _details(item, ArabicFormat.time(booking.startsAt)),
                      style: AppText.caption.copyWith(color: AppColors.text3),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ArabicFormat.price(booking.price),
                      style: AppText.weight(AppText.bodyStrong.copyWith(color: AppColors.red700), FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: 'الاتجاهات',
                  icon: Icons.near_me_outlined,
                  foreground: AppColors.blue900,
                  background: AppColors.surface,
                  border: AppColors.blue900,
                  onPressed: item.hasLocation ? () => openDirections(context, item.latitude!, item.longitude!) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: ActionButton.cancel(onPressed: () => cancelBookingFlow(context, ref, item))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PastCard extends ConsumerWidget {
  const _PastCard({required this.item});

  final MyBooking item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = item.booking;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.salonName, style: AppText.cardTitle),
                Text(
                  _details(item, ArabicFormat.dayMonth(booking.startsAt)),
                  style: AppText.caption.copyWith(color: AppColors.text3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (item.canRate)
            TextButton.icon(
              onPressed: () => rateBooking(context, ref, item),
              icon: const Icon(Icons.star_rounded, size: AppSizes.badgeIcon, color: AppColors.red400),
              label: const Text('قيّم'),
              iconAlignment: IconAlignment.end,
            )
          else if (item.rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: AppSizes.badgeIcon, color: AppColors.red400),
                const SizedBox(width: AppSpacing.xs),
                Text(ArabicFormat.number(item.rating!), style: AppText.bodyStrong),
              ],
            ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(booking.status),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.dark});

  final DateTime date;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final weekday = dark ? AppColors.red400 : AppColors.red700;
    final primary = dark ? AppColors.surface : AppColors.blue900;
    final secondary = dark ? AppColors.onDarkMuted : AppColors.text2;
    return Container(
      width: AppSizes.dateTileWidth,
      height: AppSizes.dateTileHeight,
      decoration: BoxDecoration(
        color: dark ? AppColors.blue900 : AppColors.blue100,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ArabicFormat.weekday(date), style: AppText.label.copyWith(color: weekday)),
          Text('${date.day}', style: AppText.weight(AppText.h2.copyWith(color: primary, height: 1.1), FontWeight.w800)),
          Text(ArabicFormat.month(date), style: AppText.label.copyWith(color: secondary)),
        ],
      ),
    );
  }
}

String _details(MyBooking item, String when) => [
  if (item.barberName.isNotEmpty) 'مع ${item.barberName}',
  if (item.booking.serviceName != null) item.booking.serviceName!,
  when,
].join(' · ');
