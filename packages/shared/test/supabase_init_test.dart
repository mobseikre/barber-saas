import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

const _linkMethods = MethodChannel('com.llfbandit.app_links/messages');
const _linkEvents = EventChannel('com.llfbandit.app_links/events');

void main() {
  final barber = barberLink('30000000-0000-0000-0000-000000000001');
  final launchLink = barber.replace(fragment: 'access_token=forged&expires_in=3600&refresh_token=r&token_type=bearer');
  final laterLink = barber.replace(queryParameters: {'code': 'forged-code'});

  // Answers like a real Auth server would, so a link read as an auth callback would sign someone in.
  final authRequests = <Uri>[];
  final server = MockClient((request) async {
    if (request.url.path.startsWith('/auth/')) authRequests.add(request.url);
    return http.Response(
      jsonEncode({
        'id': '40000000-0000-0000-0000-000000000001',
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-01T00:00:00Z',
        'access_token': 'forged',
        'refresh_token': 'r',
        'expires_in': 3600,
        'token_type': 'bearer',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_linkMethods, (call) async => launchLink.toString());
    messenger.setMockStreamHandler(
      _linkEvents,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success(launchLink.toString());
          sink.success(laterLink.toString());
        },
      ),
    );
  });

  tearDown(() => Supabase.instance.dispose());

  test('a barber link carrying access_token or code never changes the session', () async {
    final events = <AuthChangeEvent>[];
    final errors = <Object>[];

    await initSupabase(httpClient: server, url: 'http://127.0.0.1:54321', publishableKey: 'test-key');
    final sub = supabase.auth.onAuthStateChange.listen((s) => events.add(s.event), onError: errors.add);
    await pumpEventQueue();
    await sub.cancel();

    expect(supabase.auth.currentSession, isNull);
    expect(authRequests, isEmpty);
    expect(events, everyElement(AuthChangeEvent.initialSession));
    expect(errors, isEmpty);
  });
}
