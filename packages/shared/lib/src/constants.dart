/// Constants that mirror the SQL functions of the same name.
abstract final class AppConstants {
  static const noShowLimit = 3;
  static const upcomingBookingLimit = 2;
  static const cancellationWindow = Duration(hours: 2);
  static const reminderLeadTime = Duration(hours: 1);
  static const customerNameMaxLength = 60;
  static const noteMaxLength = 200;
  static const reviewCommentMaxLength = 300;
  static const reviewMaxTags = 5;
  static const reviewTags = ['جودة القص', 'النظافة', 'الالتزام بالموعد', 'حسن التعامل', 'السعر مناسب'];
  static const fullNameMaxLength = 60;
  static const salonNameMaxLength = 60;
  static const passwordMinLength = 8;
  static const slotStep = Duration(minutes: 15);

  /// Days ahead, today included, that customers can book and barbers can see in their bookings.
  static const bookingDays = 14;
  static const timezone = 'Africa/Tripoli';
  static const phoneCountryCode = '218';
  static const authEmailDomain = 'app.local';

  static const supportWhatsAppNumber = '218910000000';

  /// Placeholder until the real domain hosts assetlinks.json and apple-app-site-association.
  static const appLinkHost = 'hallaqi.example.com';
}
