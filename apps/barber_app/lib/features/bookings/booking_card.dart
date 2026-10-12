import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.isNext = false,
    this.busy = false,
    this.onAttended,
    this.onNoShow,
    this.onCancel,
  });

  final Booking booking;
  final bool isNext;
  final bool busy;
  final VoidCallback? onAttended;
  final VoidCallback? onNoShow;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final open = booking.isOpen;
    final started = booking.hasStarted;
    final service = [?booking.serviceName, ArabicFormat.minutes(booking.durationMin)].join(' · ');
    final cancelButton = SquareIconButton(
      icon: Icons.close_rounded,
      tooltip: 'إلغاء الحجز',
      outlined: true,
      onPressed: busy ? null : onCancel,
    );

    return AppCard(
      highlighted: isNext,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.topStart,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ArabicFormat.time(booking.startsAt), style: AppText.time, maxLines: 1, softWrap: false),
                      if (isNext)
                        Text('التالي', style: AppText.label.copyWith(color: AppColors.red700))
                      else if (booking.isManual)
                        Text('يدوي', style: AppText.label.copyWith(color: AppColors.text3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.displayName, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      service,
                      style: AppText.caption.copyWith(color: AppColors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (open && booking.customerPhone != null)
                SquareIconButton(
                  icon: Icons.phone_outlined,
                  tooltip: 'اتصال',
                  onPressed: () => launchOrExplain(
                    context,
                    telUri(booking.customerPhone!),
                    fallback: 'رقم الزبون: ${formatLibyanPhone(booking.customerPhone!)}',
                  ),
                )
              else if (!open)
                StatusBadge(booking.status),
              if (open && !started) ...[const SizedBox(width: AppSpacing.sm), cancelButton],
            ],
          ),
          if (open && started) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ActionButton.attended(height: AppSizes.cardButton, onPressed: busy ? null : onAttended),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ActionButton.noShow(height: AppSizes.cardButton, onPressed: busy ? null : onNoShow),
                ),
                const SizedBox(width: AppSpacing.sm),
                cancelButton,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
