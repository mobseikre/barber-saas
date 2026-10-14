import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

/// Customers and estimated income for today and this month, and the most requested services.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final now = AppTime.now();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(statsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomInset + AppSizes.bottomNav + AppSpacing.xxxl),
          children: [
            PageTitle(title: 'الإحصائيات', subtitle: ArabicFormat.monthYear(now)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: stats.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxxl * 3),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxxl * 2),
                  child: RetryMessage(message: bookingErrorMessage(e), onRetry: () => ref.invalidate(statsProvider)),
                ),
                data: (s) => _Content(stats: s, dayOfMonth: now.day),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats, required this.dayOfMonth});

  final BarberStats stats;
  final int dayOfMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.person_outline_rounded,
                  background: AppColors.blue900,
                  label: 'زبائن اليوم',
                  value: '${stats.todayCustomers}',
                  detail: '${stats.todayCompleted} مكتمل · ${stats.todayNoShow} لم يحضر',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  icon: Icons.groups_outlined,
                  background: AppColors.blue900,
                  label: 'زبائن الشهر',
                  value: '${stats.monthCustomers}',
                  detail: 'حتى اليوم $dayOfMonth',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _IncomeCard(label: 'دخل اليوم التقديري', amount: stats.todayIncome),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _IncomeCard(label: 'دخل الشهر التقديري', amount: stats.monthIncome),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _TopServices(services: stats.topServices),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'الدخل تقديري ومحسوب من أسعار الحجوزات المكتملة فقط.',
          style: AppText.caption.copyWith(color: AppColors.text3),
        ),
      ],
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: AppSizes.iconSm, color: AppColors.red700),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppText.caption.copyWith(color: AppColors.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(ArabicFormat.number(amount), style: AppText.incomeValue),
                const SizedBox(width: AppSpacing.xs),
                Text('د.ل', style: AppText.buttonCompact.copyWith(color: AppColors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopServices extends StatelessWidget {
  const _TopServices({required this.services});

  final List<ServiceCount> services;

  @override
  Widget build(BuildContext context) {
    final max = services.isEmpty || services.first.count < 1 ? 1 : services.first.count;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.iconTile,
                height: AppSizes.iconTile,
                decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(AppRadius.tile)),
                child: const Icon(Icons.workspace_premium_outlined, color: AppColors.vipText),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الخدمة الأكثر طلباً هذا الشهر', style: AppText.caption.copyWith(color: AppColors.text3)),
                    Text(
                      services.isEmpty ? 'لا توجد حجوزات هذا الشهر' : services.first.nameAr,
                      style: AppText.tileTitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (services.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < services.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _Bar(service: services[i], fraction: services[i].count / max, highlight: i == 0),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.service, required this.fraction, required this.highlight});

  final ServiceCount service;
  final double fraction;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(service.nameAr, style: AppText.caption.copyWith(color: AppColors.text)),
            ),
            Text(
              '${service.count}',
              style: AppText.weight(AppText.caption.copyWith(color: AppColors.text), FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            key: ValueKey('bar-track-${service.nameAr}'),
            height: AppSpacing.sm,
            color: AppColors.blue100,
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.02, 1.0),
              child: Container(
                key: ValueKey('bar-fill-${service.nameAr}'),
                height: AppSpacing.sm,
                color: highlight ? AppColors.red400 : AppColors.bluePressed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
