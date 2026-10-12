import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

typedef CancelChoice = ({BarberCancelReason reason, String? note});

/// Asks the barber why a booking is cancelled. Returns null when dismissed.
Future<CancelChoice?> showCancelReasonSheet(BuildContext context, {required Booking booking}) {
  return showAppBottomSheet<CancelChoice>(
    context: context,
    builder: (_) => _CancelReasonSheet(booking: booking),
  );
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({required this.booking});

  final Booking booking;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  BarberCancelReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إلغاء الحجز', style: AppText.h2),
          Text(
            '${booking.displayName} · ${ArabicFormat.time(booking.startsAt)}',
            style: AppText.caption.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('سبب الإلغاء', style: AppText.inputLabel),
          const SizedBox(height: AppSpacing.sm),
          RadioGroup<BarberCancelReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final reason in BarberCancelReason.values)
                  RadioListTile<BarberCancelReason>(
                    value: reason,
                    title: Text(reason.labelAr, style: AppText.body),
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.poleRed,
                    dense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'ملاحظة (اختياري)',
            controller: _note,
            hint: 'سيراها الزبون',
            maxLength: AppConstants.noteMaxLength,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'تأكيد الإلغاء',
            variant: AppButtonVariant.accent,
            onPressed: _reason == null
                ? null
                : () => Navigator.of(
                    context,
                  ).pop((reason: _reason!, note: _note.text.trim().isEmpty ? null : _note.text.trim())),
          ),
        ],
      ),
    );
  }
}
