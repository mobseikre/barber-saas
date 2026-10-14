import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

class BookingConfirmedScreen extends ConsumerWidget {
  const BookingConfirmedScreen({super.key, required this.booking, required this.barber, required this.serviceName});

  final Booking booking;
  final BarberListing barber;
  final String serviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = [
      ('الحلاق', barber.displayName),
      ('الصالون', barber.salonName),
      ('الخدمة', serviceName),
      ('اليوم', ArabicFormat.dayDate(booking.startsAt)),
      ('الوقت', ArabicFormat.time(booking.startsAt)),
      ('السعر', ArabicFormat.price(booking.price)),
    ];
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: Container(
                  width: AppSizes.avatarTile,
                  height: AppSizes.avatarTile,
                  decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: AppSizes.heroIcon, color: AppColors.success),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('تم تأكيد حجزك', style: AppText.h1, textAlign: TextAlign.center),
              Text(
                'الدفع نقداً في الصالون',
                style: AppText.caption.copyWith(color: AppColors.text3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                child: Column(
                  children: [
                    for (final (i, (label, value)) in rows.indexed) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            Text(label, style: AppText.caption.copyWith(color: AppColors.text3)),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Text(value, style: AppText.bodyStrong, textAlign: TextAlign.end),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'يمكنك إلغاء الحجز حتى ${ArabicFormat.hours(AppConstants.cancellationWindow.inHours)} قبل الموعد',
                style: AppText.caption.copyWith(color: AppColors.text3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(label: 'العودة للرئيسية', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'عرض حجوزاتي',
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  ref.read(homeTabProvider.notifier).select(HomeTab.bookings);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
