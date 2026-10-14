import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  PostgrestException db(String message, {String? code}) => PostgrestException(message: message, code: code);

  group('authErrorMessage', () {
    test('only invalid_credentials is a wrong phone or password', () {
      expect(
        authErrorMessage(const AuthException('x', statusCode: '400', code: 'invalid_credentials')),
        'رقم الهاتف أو كلمة المرور غير صحيحة',
      );
      expect(
        authErrorMessage(const AuthException('x', statusCode: '400', code: 'validation_failed')),
        genericErrorMessage,
      );
      expect(authErrorMessage(const AuthException('x', statusCode: '400')), genericErrorMessage);
    });

    test('known auth codes have their own message', () {
      expect(authErrorMessage(const AuthException('x', code: 'user_already_exists')), contains('مسجّل مسبقاً'));
      expect(authErrorMessage(const AuthException('x', code: 'email_exists')), contains('مسجّل مسبقاً'));
      expect(authErrorMessage(const AuthException('x', code: 'weak_password')), 'كلمة المرور ضعيفة');
      expect(
        authErrorMessage(const AuthException('x', code: 'same_password')),
        'كلمة المرور الجديدة يجب أن تختلف عن الحالية',
      );
    });

    test('registration codes from register_barber', () {
      expect(authErrorMessage(db('not_a_barber')), contains('تطبيق الزبائن'));
      expect(authErrorMessage(db('salon_not_found')), 'الصالون المختار غير موجود');
    });

    test('a barber signing in to the customer app is told to use the barber app', () {
      expect(authErrorMessage(db('not_a_customer')), contains('تطبيق الحلاقين'));
    });

    test('other database errors use the booking map', () {
      expect(authErrorMessage(db('x', code: '42501')), 'ليست لديك صلاحية لهذا الإجراء');
    });
  });

  group('bookingErrorMessage', () {
    test('Postgres codes', () {
      expect(bookingErrorMessage(db('conflicting key value', code: '23P01')), 'يوجد حجز آخر في هذا الوقت');
      expect(
        bookingErrorMessage(db('new row violates row-level security policy', code: '42501')),
        'ليست لديك صلاحية لهذا الإجراء',
      );
      expect(
        bookingErrorMessage(db('duplicate key value violates unique constraint', code: '23505')),
        'هذا السجل موجود مسبقاً',
      );
    });

    test('RPC codes for the barber app', () {
      expect(bookingErrorMessage(db('booking_not_started', code: 'P0001')), 'لم يبدأ موعد الحجز بعد');
      expect(bookingErrorMessage(db('day_closed', code: 'P0001')), 'هذا اليوم مغلق');
      expect(bookingErrorMessage(db('inside_break', code: 'P0001')), 'الوقت المختار داخل استراحة');
      expect(bookingErrorMessage(db('outside_working_hours', code: 'P0001')), 'الوقت المختار خارج أوقات العمل');
      expect(bookingErrorMessage(db('barber_not_active', code: 'P0001')), 'حسابك غير مفعّل حالياً، تواصل مع الإدارة');
    });

    test('length limits use the shared constants', () {
      expect(
        bookingErrorMessage(db('customer_name_too_long', code: 'P0001')),
        contains('${AppConstants.customerNameMaxLength}'),
      );
      expect(bookingErrorMessage(db('cancel_note_too_long', code: 'P0001')), contains('${AppConstants.noteMaxLength}'));
    });

    test('RPC codes for the customer app use the shared constants', () {
      expect(bookingErrorMessage(db('customer_blocked', code: 'P0001')), contains('${AppConstants.noShowLimit}'));
      expect(
        bookingErrorMessage(db('booking_limit_reached', code: 'P0001')),
        contains('${AppConstants.upcomingBookingLimit}'),
      );
      expect(
        bookingErrorMessage(db('cancellation_window_passed', code: 'P0001')),
        contains(ArabicFormat.hours(AppConstants.cancellationWindow.inHours)),
      );
      expect(bookingErrorMessage(db('slot_not_available', code: 'P0001')), contains('لم يعد متاحاً'));
    });

    test('unknown errors never show raw text', () {
      expect(bookingErrorMessage(db('some new english message', code: 'P0001')), genericErrorMessage);
      expect(bookingErrorMessage(Exception('SocketException: Connection refused')), genericErrorMessage);
      expect(bookingErrorMessage(StateError('bad state')), genericErrorMessage);
    });
  });

  test('the idempotency codes of create_booking are mapped', () {
    expect(bookingErrorMessage(db('idempotency_key_required', code: 'P0001')), genericErrorMessage);
    expect(
      bookingErrorMessage(db('idempotency_key_reused', code: 'P0001')),
      'تغيّر اختيارك أثناء إرسال الحجز، أكّد الحجز مرة أخرى',
    );
  });

  group('reviewErrorMessage', () {
    test('a second review of the same booking, a comment over the limit and the booking rules', () {
      expect(reviewErrorMessage(db('x', code: '23505')), 'قيّمت هذا الحجز مسبقاً');
      String check(String constraint) => reviewErrorMessage(
        db('new row for relation "reviews" violates check constraint "$constraint"', code: '23514'),
      );
      expect(check('reviews_comment_length'), 'التعليق طويل جداً، الحد ${AppConstants.reviewCommentMaxLength} حرف');
      expect(check('reviews_tags_size'), 'اختر ${AppConstants.reviewMaxTags} وسوم على الأكثر');
      expect(check('reviews_tags_allowed'), 'أحد الوسوم المختارة غير متاح، حدّث الصفحة وحاول مرة أخرى');
      expect(check('reviews_rating_check'), 'اختر تقييماً من نجمة إلى 5 نجوم');
      expect(check('some_other_check'), genericErrorMessage);
      expect(reviewErrorMessage(db('booking_not_completed', code: 'P0001')), 'يمكن تقييم الحجوزات المكتملة فقط');
    });

    test('anything else is the generic message', () {
      expect(reviewErrorMessage(Exception('offline')), genericErrorMessage);
      expect(reviewErrorMessage(db('boom', code: 'P0001')), genericErrorMessage);
    });
  });
}
