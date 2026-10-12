import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';

const genericErrorMessage = 'حدث خطأ، تأكد من الاتصال بالإنترنت وحاول مرة أخرى';

const _codes = {
  'booking_not_found': 'الحجز غير موجود',
  'booking_cancelled': 'لا يمكن تغيير حالة حجز ملغي',
  'booking_not_confirmed': 'هذا الحجز لم يعد مؤكداً',
  'booking_not_started': 'لم يبدأ موعد الحجز بعد',
  'booking_in_past': 'الوقت المختار قد مضى',
  'booking_not_completed': 'يمكن تقييم الحجوزات المكتملة فقط',
  'cancel_reason_required': 'اختر سبب الإلغاء',
  'customer_name_required': 'أدخل اسم الزبون',
  'customer_name_too_long': 'اسم الزبون طويل جداً، الحد ${AppConstants.customerNameMaxLength} حرفاً',
  'cancel_note_too_long': 'الملاحظة طويلة جداً، الحد ${AppConstants.noteMaxLength} حرف',
  'barber_not_active': 'حسابك بانتظار التفعيل من الإدارة',
  'service_not_offered': 'هذه الخدمة غير متاحة لدى الحلاق',
  'outside_working_hours': 'الوقت المختار خارج أوقات العمل',
  'inside_break': 'الوقت المختار داخل استراحة',
  'day_closed': 'هذا اليوم مغلق',
  'slot_not_available': 'هذا الموعد لم يعد متاحاً، اختر وقتاً آخر',
  'barber_not_bookable': 'هذا الحلاق غير متاح للحجز حالياً',
  'not_a_barber': 'هذا الإجراء للحلاقين فقط',
  'not_a_customer': 'هذا الإجراء للزبائن فقط',
  'admin_only': 'هذا الإجراء للإدارة فقط',
};

String bookingErrorMessage(Object error) {
  if (error is! PostgrestException) return genericErrorMessage;
  return switch (error.code) {
    '23P01' => 'يوجد حجز آخر في هذا الوقت',
    '42501' => 'ليست لديك صلاحية لهذا الإجراء',
    '23505' => 'هذا السجل موجود مسبقاً',
    _ => switch (error.message) {
      'customer_blocked' => 'تم إيقاف الحجز لحسابك بعد ${AppConstants.noShowLimit} مرات عدم حضور. تواصل مع الإدارة',
      'booking_limit_reached' => 'لديك ${AppConstants.upcomingBookingLimit} حجوزات قادمة، وهو الحد الأقصى',
      'cancellation_window_passed' =>
        'لا يمكن الإلغاء قبل أقل من ${AppConstants.cancellationWindow.inHours} ساعة من الموعد',
      final code => _codes[code] ?? genericErrorMessage,
    },
  };
}
