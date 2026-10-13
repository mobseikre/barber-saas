import '../constants.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// The barber's page in the customer app, as an App Link / Universal Link: `https://<host>/b/<barber id>`.
Uri barberLink(String barberId) => Uri.https(AppConstants.appLinkHost, '/b/$barberId');

/// The barber id in a link made by [barberLink], or null for any other link.
String? barberIdFromLink(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (uri.scheme != 'https' || uri.host != AppConstants.appLinkHost) return null;
  if (segments.length != 2 || segments.first != 'b') return null;
  final id = segments.last.toLowerCase();
  return _uuid.hasMatch(id) ? id : null;
}
