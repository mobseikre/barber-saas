import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

void main() {
  late FakePushMessaging push;
  late FakeDeviceTokenRepository repo;
  late PushTokens tokens;

  setUp(() {
    push = FakePushMessaging();
    repo = FakeDeviceTokenRepository();
    tokens = PushTokens(push, () => repo);
  });

  test('asks for permission and saves the token with the platform on sign-in', () async {
    await tokens.register('u1');

    expect(push.calls, ['requestPermission']);
    expect(repo.saved, {'device-token-1': DevicePlatform.android});
  });

  test('a second sign-in event for the same user asks nothing again', () async {
    await tokens.register('u1');
    await tokens.register('u1');

    expect(push.calls, ['requestPermission']);
    expect(repo.calls, ['register:device-token-1']);
  });

  test('saves the new token when Firebase rotates it', () async {
    await tokens.register('u1');
    push.rotate('device-token-2');
    await pumpEventQueue();

    expect(repo.calls, ['register:device-token-1', 'register:device-token-2']);

    await tokens.unregister();
    expect(repo.calls.last, 'unregister:device-token-2');
  });

  test('sign-out deletes the saved token, then resets it on the device', () async {
    await tokens.register('u1');
    await tokens.unregister();

    expect(repo.saved, isEmpty);
    expect(push.calls, ['requestPermission', 'deleteToken']);

    push.rotate('device-token-3');
    await pumpEventQueue();
    expect(repo.calls, ['register:device-token-1', 'unregister:device-token-1'], reason: 'no refresh after sign-out');
  });

  test('the next user on the device registers again', () async {
    await tokens.register('u1');
    await tokens.unregister();
    await tokens.register('u2');

    expect(push.calls, ['requestPermission', 'deleteToken', 'requestPermission']);
    expect(repo.saved.keys, ['device-token-1']);
  });

  test('saves nothing when permission is refused', () async {
    push.granted = false;
    await tokens.register('u1');
    await tokens.unregister();

    expect(repo.calls, isEmpty);
    expect(push.calls, ['requestPermission']);
  });

  test('does nothing where push is off', () async {
    tokens = PushTokens(const NoPushMessaging(), () => repo);
    await tokens.register('u1');
    await tokens.unregister();

    expect(repo.calls, isEmpty);
  });

  test('a failed save is tried again on the next sign-in event', () async {
    repo.registerError = Exception('offline');
    await tokens.register('u1');
    expect(repo.saved, isEmpty);

    repo.registerError = null;
    await tokens.register('u1');
    expect(repo.saved, {'device-token-1': DevicePlatform.android});
  });

  group('barber links', () {
    const id = '30000000-0000-0000-0000-000000000001';

    test('point at the barber page on the app link host', () {
      expect(barberLink(id).toString(), 'https://${AppConstants.appLinkHost}/b/$id');
      expect(barberIdFromLink(barberLink(id)), id);
    });

    test('anything else is not a barber link', () {
      for (final link in [
        'http://${AppConstants.appLinkHost}/b/$id',
        'https://evil.example/b/$id',
        'https://${AppConstants.appLinkHost}/s/$id',
        'https://${AppConstants.appLinkHost}/b/not-an-id',
        'https://${AppConstants.appLinkHost}/b/$id/extra',
      ]) {
        expect(barberIdFromLink(Uri.parse(link)), isNull, reason: link);
      }
    });
  });
}
