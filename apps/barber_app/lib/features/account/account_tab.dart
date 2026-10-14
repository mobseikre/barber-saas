import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../location/location_screen.dart';
import 'change_photo.dart';
import '../qr/qr_screen.dart';
import '../schedule/working_hours_screen.dart';

/// Who the barber is and where they work, the subscription and how to renew it, and the links to their settings.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(latestPaymentProvider);
    ref.invalidate(currentProfileProvider);
    return ref.refresh(currentBarberProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barber = ref.watch(currentBarberProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomInset + AppSizes.bottomNav + AppSpacing.xxxl),
          children: [
            const PageTitle(title: 'الاشتراك'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: barber.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxxl * 3),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    _Retry(message: authErrorMessage(e), onRetry: () => ref.invalidate(currentBarberProvider)),
                data: (b) => b == null
                    ? _Retry(message: genericErrorMessage, onRetry: () => ref.invalidate(currentBarberProvider))
                    : _Content(barber: b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl * 2),
      child: RetryMessage(message: message, onRetry: onRetry),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = AppTime.now();
    final ends = barber.subscriptionEndsAt;
    final active = ends != null && ends.isAfter(now);
    final daysLeft = barber.daysLeft;
    final payment = ref.watch(latestPaymentProvider).value;

    return Column(
      children: [
        _ProfileCard(barber: barber),
        const SizedBox(height: AppSpacing.lg),
        _PlanCard(
          planName: payment == null ? 'لا توجد باقة بعد' : ArabicFormat.planName(payment.months),
          ends: ends,
          active: active,
          daysLeft: daysLeft,
          payment: active ? payment : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _RenewalCard(),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuRow(
                icon: Icons.schedule_rounded,
                label: 'أوقات العمل',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkingHoursScreen())),
              ),
              const Divider(),
              _MenuRow(
                icon: Icons.location_on_outlined,
                label: 'موقع الصالون',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LocationScreen())),
              ),
              const Divider(),
              _MenuRow(
                icon: Icons.qr_code_2_rounded,
                label: 'رمز QR',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QrScreen())),
              ),
              const Divider(),
              _MenuRow(
                icon: Icons.photo_camera_outlined,
                label: 'تغيير الصورة',
                onTap: () => changeBarberPhoto(context, ref),
              ),
              const Divider(),
              _MenuRow(
                icon: Icons.lock_outline_rounded,
                label: 'تغيير كلمة المرور',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
              ),
              const Divider(),
              _MenuRow(
                icon: Icons.logout_rounded,
                label: 'تسجيل الخروج',
                danger: true,
                onTap: () => confirmSignOut(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.barber});

  final Barber barber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(currentProfileProvider).value?.phone;
    final salon = ref.watch(currentSalonProvider).value;
    final areas = ref.watch(areasProvider).value ?? const <Area>[];
    final area = areas.where((a) => a.id == salon?.areaId).firstOrNull?.name;
    final place = [?salon?.name, ?area].join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LocationScreen())),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.card),
          child: Row(
            children: [
              LetterAvatar(
                name: barber.displayName,
                imageUrl: publicStorageUrl(barber.photoUrl),
                size: AppSizes.avatarTile,
                radius: AppRadius.control,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(barber.displayName, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (phone != null)
                      Text(
                        formatLibyanPhone(phone),
                        style: AppText.caption.copyWith(color: AppColors.text3),
                        textDirection: TextDirection.ltr,
                      ),
                    if (place.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: AppSizes.iconSm, color: AppColors.red700),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              place,
                              style: AppText.caption.copyWith(color: AppColors.text3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.planName,
    required this.ends,
    required this.active,
    required this.daysLeft,
    required this.payment,
  });

  final String planName;
  final DateTime? ends;
  final bool active;
  final int daysLeft;
  final SubscriptionPayment? payment;

  @override
  Widget build(BuildContext context) {
    final total = payment == null ? 0 : (payment!.periodEnd.difference(payment!.periodStart).inHours / 24).round();
    final remaining = daysLeft.clamp(0, total);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.blue900, borderRadius: BorderRadius.circular(AppRadius.panel)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('باقتك الحالية', style: AppText.caption.copyWith(color: AppColors.onDarkMuted)),
              ),
              _StatusPill(active: active),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(planName, style: AppText.weight(AppText.h1.copyWith(color: AppColors.surface), FontWeight.w800)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'تاريخ الانتهاء',
                  value: ends == null ? '—' : ArabicFormat.longDate(ends!),
                  valueColor: AppColors.surface,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Tile(
                  label: 'المتبقي',
                  value: active ? ArabicFormat.days(daysLeft) : 'منتهٍ',
                  valueColor: AppColors.red300,
                ),
              ),
            ],
          ),
          if (payment != null && total > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _Progress(remaining: remaining, total: total),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'بدأ في ${ArabicFormat.longDate(payment!.periodStart)} · باقي $remaining من $total يوماً',
              style: AppText.caption.copyWith(color: AppColors.onDarkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.danger;
    return Container(
      height: AppSizes.badge,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            active ? 'فعّال' : 'منتهٍ',
            style: AppText.weight(AppText.caption.copyWith(color: color), FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.valueColor});

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.blue800, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: AppColors.onDarkMuted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: AppText.weight(AppText.h3.copyWith(color: valueColor), FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.remaining, required this.total});

  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: AppSpacing.sm,
        child: Row(
          children: [
            if (remaining > 0)
              Expanded(
                flex: remaining,
                child: Container(
                  key: const ValueKey('progress-remaining'),
                  height: AppSpacing.sm,
                  color: AppColors.poleRed,
                ),
              ),
            if (total - remaining > 0)
              Expanded(
                flex: total - remaining,
                child: Container(
                  key: const ValueKey('progress-elapsed'),
                  height: AppSpacing.sm,
                  color: AppColors.bluePressed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('للتجديد أو تغيير الباقة', style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تواصل مع إدارة التطبيق مباشرة، وسيتم تفعيل التجديد من طرفهم.',
            style: AppText.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.red50, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رقم الإدارة', style: AppText.caption.copyWith(color: AppColors.vipText)),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          formatLibyanPhone(AppConstants.supportWhatsAppNumber),
                          style: AppText.weight(AppText.h2, FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                SquareIconButton(
                  icon: Icons.phone_outlined,
                  tooltip: 'اتصال بالإدارة',
                  onPressed: () => launchOrExplain(
                    context,
                    telUri(AppConstants.supportWhatsAppNumber),
                    fallback: 'اتصل بالإدارة على ${formatLibyanPhone(AppConstants.supportWhatsAppNumber)}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: danger ? AppColors.danger : AppColors.red700),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppText.bodyStrong.copyWith(color: color)),
            ),
            if (!danger) const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
          ],
        ),
      ),
    );
  }
}
