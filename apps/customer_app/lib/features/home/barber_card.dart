import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../data/directory_repository.dart';
import 'ranking.dart';

class BarberCard extends StatelessWidget {
  const BarberCard({super.key, required this.ranked, this.areaName, this.today, required this.onTap});

  final RankedBarber ranked;
  final String? areaName;
  final BarberToday? today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barber = ranked.barber;
    final place = [barber.salonName, ?areaName].join(' · ');
    final fromPrice = today?.fromPrice;
    final open = today == null ? null : openState(hours: today!.hours, closure: today!.closure, now: AppTime.now());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            barber.displayName,
                            style: AppText.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (barber.isVip) ...[const SizedBox(width: AppSpacing.sm), const VipBadge()],
                      ],
                    ),
                    if (barber.ratingCount > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      RatingLabel(avg: barber.ratingAvg, count: barber.ratingCount),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: AppSizes.badgeIcon, color: AppColors.text3),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            place,
                            style: AppText.caption.copyWith(color: AppColors.text3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ranked.distance != null)
                          Text(
                            ' · ${ArabicFormat.distance(ranked.distance!)}',
                            style: AppText.caption.copyWith(color: AppColors.text3),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (fromPrice != null)
                          Text(
                            'من ${ArabicFormat.price(fromPrice)}',
                            style: AppText.buttonCompact.copyWith(color: AppColors.red700),
                          ),
                        const Spacer(),
                        if (open != null) OpenStateLabel(open),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ★ 4.8 (212)
class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.avg, required this.count});

  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final strong = AppText.weight(AppText.caption, FontWeight.w700);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: AppSizes.badgeIcon, color: AppColors.red400),
        const SizedBox(width: AppSpacing.xs),
        Text(avg.toStringAsFixed(1), style: strong),
        const SizedBox(width: AppSpacing.xs),
        Text('(${ArabicFormat.number(count)})', style: AppText.caption.copyWith(color: AppColors.text3)),
      ],
    );
  }
}

class OpenStateLabel extends StatelessWidget {
  const OpenStateLabel(this.state, {super.key});

  final OpenState state;

  @override
  Widget build(BuildContext context) {
    final style = AppText.weight(AppText.caption, FontWeight.w700);
    return switch (state) {
      OpenNow() => Text('مفتوح الآن', style: style.copyWith(color: AppColors.success)),
      OpensLater(:final at) => Text(
        'يفتح ${ArabicFormat.clock(at.hour, at.minute)}',
        style: style.copyWith(color: AppColors.text2),
      ),
      ClosedToday() => Text('مغلق الآن', style: style.copyWith(color: AppColors.text3)),
    };
  }
}
