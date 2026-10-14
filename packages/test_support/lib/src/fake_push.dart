import 'dart:async';

import 'package:shared/shared.dart';

/// Grants permission and hands out [token] without Firebase.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.granted = true, this.token = 'device-token-1', this.platform = DevicePlatform.android});

  bool granted;
  String? token;
  @override
  final DevicePlatform? platform;
  final calls = <String>[];
  final _refresh = StreamController<String>.broadcast();
  final _messages = StreamController<PushNotice>.broadcast();

  /// Plays Firebase rotating the token.
  void rotate(String newToken) {
    token = newToken;
    _refresh.add(newToken);
  }

  /// Plays a notification arriving while the app is open.
  void deliver({String? title, String? body, String? type}) => _messages.add((title: title, body: body, type: type));

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return granted;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<PushNotice> get onMessage => _messages.stream;

  @override
  Future<void> deleteToken() async => calls.add('deleteToken');
}

/// Keeps the saved tokens in memory. Pass [log] to see the calls in order with other fakes.
class FakeDeviceTokenRepository implements DeviceTokenRepository {
  FakeDeviceTokenRepository({List<String>? log}) : calls = log ?? <String>[];

  final List<String> calls;
  final saved = <String, DevicePlatform>{};
  Object? registerError;

  @override
  Future<void> register(String token, DevicePlatform platform) async {
    calls.add('register:$token');
    if (registerError != null) throw registerError!;
    saved[token] = platform;
  }

  @override
  Future<void> unregister(String token) async {
    calls.add('unregister:$token');
    saved.remove(token);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
