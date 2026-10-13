import 'package:shared/shared.dart';

String locationFailureMessage(LocationFailure failure) => switch (failure) {
  LocationFailure.denied => 'لم يُسمح للتطبيق بالوصول إلى موقعك، فعّل الإذن أو حرّك الخريطة يدوياً',
  LocationFailure.deniedForever => 'إذن الموقع مغلق، فعّله من إعدادات الجهاز أو حرّك الخريطة يدوياً',
  LocationFailure.serviceDisabled => 'خدمة الموقع متوقفة في جهازك، فعّلها أو حرّك الخريطة يدوياً',
  LocationFailure.unavailable => 'تعذّر تحديد موقعك، حرّك الخريطة يدوياً',
};
