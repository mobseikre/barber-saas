import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../services/services_screen.dart';

typedef _StatusCopy = ({IconData icon, String title, String body, List<String>? steps, String whatsApp});

class PendingActivationScreen extends ConsumerWidget {
  const PendingActivationScreen({super.key, required this.barber});

  final Barber barber;

  _StatusCopy get _copy => switch (barber.status) {
    BarberStatus.pending => (
      icon: Icons.hourglass_empty_rounded,
      title: 'حسابك بانتظار التفعيل',
      body: 'استلمنا طلبك. ستراجع الإدارة بياناتك وتفعّل حسابك قريباً، وسيصلك إشعار عند التفعيل.',
      steps: const ['تم إنشاء الحساب', 'مراجعة الإدارة', 'تفعيل الحساب واستقبال الحجوزات'],
      whatsApp: 'مرحباً، أريد تفعيل حسابي كحلاق',
    ),
    BarberStatus.active => (
      icon: Icons.event_busy_rounded,
      title: 'انتهى اشتراكك',
      body: 'جدّد اشتراكك الشهري مع الإدارة ليعود حسابك للظهور للزبائن واستقبال الحجوزات.',
      steps: const ['تم إنشاء الحساب', 'تجديد الاشتراك', 'العودة لاستقبال الحجوزات'],
      whatsApp: 'مرحباً، أريد تجديد اشتراكي',
    ),
    BarberStatus.suspended => (
      icon: Icons.pause_circle_outline_rounded,
      title: 'تم إيقاف حسابك مؤقتاً',
      body: 'أوقفت الإدارة حسابك مؤقتاً ولن يظهر للزبائن. تواصل مع الإدارة لمعرفة السبب وإعادة التفعيل.',
      steps: null,
      whatsApp: 'مرحباً، تم إيقاف حسابي وأريد معرفة السبب',
    ),
    BarberStatus.rejected => (
      icon: Icons.block_rounded,
      title: 'لم تتم الموافقة على حسابك',
      body: 'راجعت الإدارة طلبك ولم تتم الموافقة عليه. تواصل مع الإدارة إذا كنت تعتقد أن هناك خطأ.',
      steps: null,
      whatsApp: 'مرحباً، تم رفض طلب حسابي وأريد الاستفسار',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _copy;
    return Scaffold(
      backgroundColor: AppColors.blue900,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(currentBarberProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  MediaQuery.paddingOf(context).top + AppSpacing.xxxl * 2,
                  AppSpacing.xxl,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: AppSizes.heroCircle,
                        height: AppSizes.heroCircle,
                        decoration: BoxDecoration(
                          color: AppColors.blue800,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.red400, width: AppSizes.ring),
                        ),
                        child: Icon(copy.icon, color: AppColors.red400, size: AppSizes.heroIcon),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      copy.title,
                      style: AppText.h1.copyWith(color: AppColors.surface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      copy.body,
                      style: AppText.body.copyWith(color: AppColors.onDarkMuted),
                      textAlign: TextAlign.center,
                    ),
                    if (copy.steps case final steps?) ...[
                      const SizedBox(height: AppSpacing.xxxl),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.blue800,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < steps.length; i++) _Step(label: steps[i], state: _StepState.values[i]),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (barber.status == BarberStatus.pending) ...[
                      AppButton(
                        label: 'جهّز خدماتك أثناء الانتظار',
                        variant: AppButtonVariant.accent,
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => const ServicesScreen(showBack: true))),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AppButton(
                      label: 'تواصل مع الإدارة',
                      icon: Icons.phone_outlined,
                      variant: AppButtonVariant.secondaryOnDark,
                      onPressed: () => contactSupport(context, message: copy.whatsApp),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => signOut(ref),
                      style: TextButton.styleFrom(foregroundColor: AppColors.red400),
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (circle, labelColor) = switch (state) {
      _StepState.done => (
        Container(
          width: AppSizes.stepMarker,
          height: AppSizes.stepMarker,
          decoration: const BoxDecoration(color: AppColors.poleRed, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: AppColors.surface, size: AppSpacing.lg),
        ),
        AppColors.surface,
      ),
      _StepState.current => (
        Container(
          width: AppSizes.stepMarker,
          height: AppSizes.stepMarker,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.red400, width: AppSizes.ring),
          ),
          alignment: Alignment.center,
          child: Container(
            width: AppSpacing.md,
            height: AppSpacing.md,
            decoration: const BoxDecoration(color: AppColors.red400, shape: BoxShape.circle),
          ),
        ),
        AppColors.red400,
      ),
      _StepState.upcoming => (
        Container(
          width: AppSizes.stepMarker,
          height: AppSizes.stepMarker,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bluePressed, width: AppSizes.ring),
          ),
        ),
        AppColors.onDarkInactive,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          circle,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: AppText.bodyStrong.copyWith(color: labelColor)),
          ),
          if (state == _StepState.current)
            Text('جارٍ الآن', style: AppText.caption.copyWith(color: AppColors.onDarkInactive)),
        ],
      ),
    );
  }
}
