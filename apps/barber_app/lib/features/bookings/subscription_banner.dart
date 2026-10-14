import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Tells a barber who cannot be booked why customers no longer see them, with a way to reach the admin.
class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key, required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context) {
    final (title, body, whatsApp) = switch (barber.status) {
      BarberStatus.suspended => (
        'تم إيقاف حسابك مؤقتاً',
        'لا يظهر حسابك للزبائن. تابع حجوزاتك الحالية، وتواصل مع الإدارة لإعادة التفعيل.',
        'مرحباً، تم إيقاف حسابي وأريد معرفة السبب',
      ),
      _ when barber.subscriptionEndsAt == null => (
        'اشتراكك غير مفعّل',
        'لا يظهر حسابك للزبائن ولا يمكنك إضافة حجوزات. فعّل اشتراكك مع الإدارة.',
        'مرحباً، أريد تفعيل اشتراكي',
      ),
      _ => (
        'انتهى اشتراكك',
        'لا يظهر حسابك للزبائن ولا يمكنك إضافة حجوزات جديدة. تابع حجوزاتك الحالية وجدّد اشتراكك مع الإدارة.',
        'مرحباً، أريد تجديد اشتراكي',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_rounded, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppText.cardTitle.copyWith(color: AppColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppText.caption.copyWith(color: AppColors.text2)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'تواصل مع الإدارة',
            icon: Icons.phone_outlined,
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: () => contactSupport(context, message: whatsApp),
          ),
        ],
      ),
    );
  }
}
