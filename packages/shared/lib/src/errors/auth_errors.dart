import 'package:supabase_flutter/supabase_flutter.dart';

import 'booking_errors.dart';

String authErrorMessage(Object error) {
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' => 'رقم الهاتف أو كلمة المرور غير صحيحة',
      'user_already_exists' || 'email_exists' => 'هذا الرقم مسجّل مسبقاً، سجّل الدخول بدلاً من ذلك',
      'weak_password' => 'كلمة المرور ضعيفة',
      'over_request_rate_limit' => 'محاولات كثيرة، حاول بعد قليل',
      _ => genericErrorMessage,
    };
  }
  if (error is PostgrestException) {
    return switch (error.message) {
      'not_a_barber' => 'هذا الرقم مسجّل كزبون، استخدم تطبيق الزبائن',
      'display_name_required' => 'أدخل اسمك الكامل',
      'salon_not_found' => 'الصالون المختار غير موجود',
      _ => bookingErrorMessage(error),
    };
  }
  return genericErrorMessage;
}
