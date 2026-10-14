import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/my_bookings_repository.dart';
import '../../providers.dart';

/// Confirms, cancels and waits for the refreshed list; inside the cancellation window it explains why instead.
/// [onBusy] is told when the request and the refresh start and end, so the card can show it is working.
Future<void> cancelBookingFlow(
  BuildContext context,
  WidgetRef ref,
  MyBooking item, {
  ValueChanged<bool>? onBusy,
}) async {
  if (!item.canCancel) return _explainRefusal(context, item);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إلغاء الحجز؟'),
      content: Text(
        'سيتم إلغاء حجزك في ${item.salonName} يوم ${ArabicFormat.dayDate(item.booking.startsAt)} '
        'الساعة ${ArabicFormat.time(item.booking.startsAt)}.',
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('رجوع')),
        AppButton(
          label: 'نعم، إلغاء الحجز',
          variant: AppButtonVariant.accent,
          compact: true,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  onBusy?.call(true);
  Object? failure;
  try {
    await ref.read(bookingRepositoryProvider).cancel(item.booking.id);
  } catch (e) {
    failure = e;
  }
  if ((failure == null || failure is PostgrestException) && context.mounted) {
    await ref.refresh(myBookingsProvider.future).catchError((_) => const <MyBooking>[]);
  }
  onBusy?.call(false);
  if (failure == null) {
    messenger.showSnackBar(const SnackBar(content: Text('تم إلغاء الحجز')));
  } else if (failure is PostgrestException && failure.message == 'cancellation_window_passed') {
    if (context.mounted) await _explainRefusal(context, item);
  } else {
    messenger.showSnackBar(SnackBar(content: Text(bookingErrorMessage(failure))));
  }
}

Future<void> _explainRefusal(BuildContext context, MyBooking item) {
  final window = ArabicFormat.hours(AppConstants.cancellationWindow.inHours);
  final started = item.booking.hasStarted;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('لا يمكن إلغاء هذا الحجز'),
      content: Text(
        started
            ? 'بدأ موعد هذا الحجز، ولا يمكن إلغاؤه الآن.'
            : 'يمكن إلغاء الحجز حتى $window قبل الموعد فقط، حتى يتمكن الصالون من إعطاء الوقت لزبون آخر. '
                  'موعدك بعد أقل من $window. إن كانت لديك ظروف طارئة تواصل مع الدعم.',
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            contactSupport(context);
          },
          child: const Text('تواصل مع الدعم'),
        ),
        AppButton(label: 'حسناً', compact: true, onPressed: () => Navigator.of(ctx).pop()),
      ],
    ),
  );
}
