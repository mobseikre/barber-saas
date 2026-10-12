import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:barber_app/features/bookings/today_bookings_provider.dart';
import 'package:barber_app/providers.dart';

import 'support/fakes.dart';

void main() {
  late _RecordingRepo repo;
  late ProviderContainer container;

  setUp(() {
    AppTime.clock = () => DateTime.utc(2026, 10, 11, 9);
    repo = _RecordingRepo();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        currentBarberProvider.overrideWith((_) async => fakeBarber),
        bookingRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.listen(todayBookingsProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    AppTime.clock = DateTime.now;
  });

  TodayBookings notifier() => container.read(todayBookingsProvider.notifier);
  List<String> ids() => [for (final b in container.read(todayBookingsProvider).value!) b.id];

  Future<void> loaded() async {
    await container.read(todayBookingsProvider.future);
    expect(repo.loads, 1);
    expect(ids(), ['a']);
  }

  final actions = <String, Future<void> Function(TodayBookings)>{
    'attended': (n) => n.markAttended('a'),
    'no-show': (n) => n.markNoShow('a'),
    'cancel': (n) => n.cancel('a', reason: BarberCancelReason.sick, note: 'زكام'),
    'manual': (n) => n.addManual(serviceId: 's1', startsAt: AppTime.now(), customerName: 'يوسف'),
    'reopen': (n) => n.reopenToday(),
  };

  for (final entry in actions.entries) {
    test('the list reloads after ${entry.key}', () async {
      await loaded();
      repo.next = ['a', 'b'];

      await entry.value(notifier());

      expect(repo.calls, hasLength(1));
      expect(repo.loads, 2);
      expect(ids(), ['a', 'b']);
    });
  }

  test('a failed reload keeps the list that was on screen', () async {
    await loaded();
    repo.failLoads = true;

    await notifier().markAttended('a');

    final state = container.read(todayBookingsProvider);
    expect(repo.loads, 2);
    expect(state.hasError, isTrue);
    expect(ids(), ['a']);
  });

  test('a successful reload after a failed one clears the error', () async {
    await loaded();
    repo.failLoads = true;
    await notifier().markNoShow('a');
    repo
      ..failLoads = false
      ..next = ['a', 'c'];

    await notifier().refresh();

    final state = container.read(todayBookingsProvider);
    expect(state.hasError, isFalse);
    expect(ids(), ['a', 'c']);
  });

  testWidgets('after several reloads the new day still loads exactly once at Tripoli midnight', (tester) async {
    container.dispose();
    var elapsed = Duration.zero;
    final start = DateTime.utc(2026, 10, 11, 21, 59);
    AppTime.clock = () => start.add(elapsed);
    final repo = _RecordingRepo();
    final local = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        currentBarberProvider.overrideWith((_) async => fakeBarber),
        bookingRepositoryProvider.overrideWithValue(repo),
      ],
    );
    local.listen(todayBookingsProvider, (_, _) {});
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await local.read(todayBookingsProvider.notifier).markAttended('a');
    }
    expect(repo.loads, 4);

    elapsed = const Duration(minutes: 2);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(repo.loads, 5, reason: 'one reload at Tripoli midnight, not one per earlier action');
    local.dispose();
  });
}

class _RecordingRepo implements BookingRepository {
  var loads = 0;
  var next = ['a'];
  var failLoads = false;
  final calls = <String>[];

  @override
  Future<List<Booking>> bookingsForDay({required String barberId, required DateTime day}) async {
    loads++;
    if (failLoads) throw Exception('offline');
    return [for (final id in next) booking(id: id, name: id, startsAt: AppTime.now())];
  }

  Booking _done(String id) => booking(id: id, name: id, startsAt: AppTime.now());

  @override
  Future<Booking> setStatus(String bookingId, BookingStatus status) async {
    calls.add('status:$bookingId:${status.name}');
    return _done(bookingId);
  }

  @override
  Future<Booking> cancel(String bookingId, {BarberCancelReason? reason, String? note}) async {
    calls.add('cancel:$bookingId');
    return _done(bookingId);
  }

  @override
  Future<Booking> createManualBooking({
    required String serviceId,
    required DateTime startsAt,
    required String customerName,
  }) async {
    calls.add('manual:$customerName');
    return _done('m');
  }

  @override
  Future<void> reopenToday() async => calls.add('reopen');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
