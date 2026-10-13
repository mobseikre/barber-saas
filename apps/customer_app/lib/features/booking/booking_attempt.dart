import 'package:uuid/uuid.dart';

typedef BookingChoice = ({String barberId, String serviceId, DateTime startsAt});

/// The idempotency key of the booking being confirmed, kept while the choice stays the same.
class BookingAttempt {
  BookingAttempt({String Function()? newKey}) : _newKey = newKey ?? const Uuid().v4;

  final String Function() _newKey;
  BookingChoice? _choice;
  String? _key;

  String keyFor(BookingChoice choice) {
    final normalized = (barberId: choice.barberId, serviceId: choice.serviceId, startsAt: choice.startsAt.toUtc());
    if (_key == null || _choice != normalized) {
      _choice = normalized;
      _key = _newKey();
    }
    return _key!;
  }

  void reset() {
    _choice = null;
    _key = null;
  }
}
