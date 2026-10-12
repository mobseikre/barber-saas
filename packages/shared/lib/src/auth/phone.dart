import '../constants.dart';

const _arabicIndicZero = 0x0660;
const _extendedArabicIndicZero = 0x06F0;

/// Converts Arabic-Indic digits (٠-٩, ۰-۹) to Latin digits.
String latinDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= _arabicIndicZero && rune <= _arabicIndicZero + 9) {
      buffer.writeCharCode(0x30 + rune - _arabicIndicZero);
    } else if (rune >= _extendedArabicIndicZero && rune <= _extendedArabicIndicZero + 9) {
      buffer.writeCharCode(0x30 + rune - _extendedArabicIndicZero);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Normalises a Libyan phone number to `218XXXXXXXXX`.
///
/// Accepts `0912345678`, `912345678`, `+218912345678`, `00218912345678`,
/// spaces, dashes and Arabic-Indic digits. Returns null when the result is
/// not a valid 9-digit Libyan mobile number starting with 9.
String? normalizeLibyanPhone(String raw) {
  var digits = latinDigits(raw).replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith(AppConstants.phoneCountryCode)) {
    digits = digits.substring(AppConstants.phoneCountryCode.length);
  }
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (!RegExp(r'^9\d{8}$').hasMatch(digits)) return null;
  return '${AppConstants.phoneCountryCode}$digits';
}

/// `218912345678` → `218912345678@app.local`, the email used for Supabase Auth.
String phoneToAuthEmail(String normalizedPhone) => '$normalizedPhone@${AppConstants.authEmailDomain}';

/// `218912345678` → `+218 91 234 5678`
String formatLibyanPhone(String normalizedPhone) {
  final local = normalizedPhone.substring(AppConstants.phoneCountryCode.length);
  return '+${AppConstants.phoneCountryCode} ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
}
