import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/my_bookings_repository.dart';
import '../../providers.dart';

/// Confirms, cancels and refreshes the list; inside the cancellation window it explains why instead.
Future<void> cancelBookingFlow(BuildContext context, WidgetRef ref, MyBooking item) async {
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
  try {
    await ref.read(bookingRepositoryProvider).cancel(item.booking.id);
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    ref.invalidate(myBookingsProvider);
    if (e.message == 'cancellation_window_passed') return _explainRefusal(context, item);
    messenger.showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    return;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    return;
  }
  messenger.showSnackBar(const SnackBar(content: Text('تم إلغاء الحجز')));
  if (context.mounted) ref.invalidate(myBookingsProvider);
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
