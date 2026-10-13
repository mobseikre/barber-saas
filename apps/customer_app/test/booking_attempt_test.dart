import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/features/booking/booking_attempt.dart';

void main() {
  var counter = 0;
  BookingAttempt attempt() => BookingAttempt(newKey: () => 'key-${++counter}');
  final start = DateTime.utc(2026, 10, 13, 15, 30);
  final choice = (barberId: 'ali', serviceId: 'haircut', startsAt: start);

  setUp(() => counter = 0);

  test('retrying the same choice reuses the key', () {
    final a = attempt();

    expect(a.keyFor(choice), 'key-1');
    expect(a.keyFor((barberId: 'ali', serviceId: 'haircut', startsAt: start.toLocal())), 'key-1');
  });

  test('another slot, service or barber is a new attempt', () {
    final a = attempt();
    a.keyFor(choice);

    expect(
      a.keyFor((barberId: 'ali', serviceId: 'haircut', startsAt: start.add(const Duration(minutes: 15)))),
      'key-2',
    );
    expect(a.keyFor((barberId: 'ali', serviceId: 'beard', startsAt: start)), 'key-3');
    expect(a.keyFor(choice), 'key-4', reason: 'going back to the first choice is not a retry of it');
  });

  test('after a booking succeeds the next one gets a new key', () {
    final a = attempt();
    a.keyFor(choice);
    a.reset();

    expect(a.keyFor(choice), 'key-2');
  });

  test('the default keys are random v4 UUIDs', () {
    final a = BookingAttempt();
    final key = a.keyFor(choice);

    expect(key, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(BookingAttempt().keyFor(choice), isNot(key));
  });
}
