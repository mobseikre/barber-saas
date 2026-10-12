import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/phone.dart';
import '../constants.dart';

Uri supportWhatsAppUri({String? message}) =>
    Uri.https('wa.me', '/${AppConstants.supportWhatsAppNumber}', message == null ? null : {'text': message});

Uri telUri(String normalizedPhone) => Uri(scheme: 'tel', path: '+$normalizedPhone');

final supportFallbackMessage = 'تواصل مع الدعم على واتساب: ${formatLibyanPhone(AppConstants.supportWhatsAppNumber)}';

/// Opens [uri], or shows [fallback] in a snackbar when no app can handle it.
Future<void> launchOrExplain(BuildContext context, Uri uri, {required String fallback}) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(fallback)));
}

/// Opens the support chat, or shows the support number when WhatsApp is missing.
Future<void> contactSupport(BuildContext context, {String? message}) =>
    launchOrExplain(context, supportWhatsAppUri(message: message), fallback: supportFallbackMessage);
