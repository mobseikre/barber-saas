import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/phone.dart';
import '../constants.dart';

Uri supportWhatsAppUri({String? message}) =>
    Uri.https('wa.me', '/${AppConstants.supportWhatsAppNumber}', message == null ? null : {'text': message});

Uri directionsUri(double latitude, double longitude) =>
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$latitude,$longitude'});

Uri telUri(String normalizedPhone) => Uri(scheme: 'tel', path: '+$normalizedPhone');

final supportFallbackMessage = 'تواصل مع الدعم على واتساب: ${formatLibyanPhone(AppConstants.supportWhatsAppNumber)}';

/// Opens [uri], or shows [fallback] in a snackbar when no app can handle it.
Future<void> launchOrExplain(BuildContext context, Uri uri, {required String fallback}) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(fallback)));
}

/// Opens the route to the salon in the maps app.
Future<void> openDirections(BuildContext context, double latitude, double longitude) =>
    launchOrExplain(context, directionsUri(latitude, longitude), fallback: 'تعذّر فتح الخرائط');

/// Opens the support chat, or shows the support number when WhatsApp is missing.
Future<void> contactSupport(BuildContext context, {String? message}) =>
    launchOrExplain(context, supportWhatsAppUri(message: message), fallback: supportFallbackMessage);
