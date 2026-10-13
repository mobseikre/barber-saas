import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/device_token_repository.dart';
import 'push_messaging.dart';

/// Keeps the signed-in user's device token in `device_tokens`.
class PushTokens {
  PushTokens(this._messaging, this._repository);

  final PushMessaging _messaging;
  final DeviceTokenRepository Function() _repository;

  String? _userId;
  String? _token;
  StreamSubscription<String>? _refresh;

  /// Asks for permission and saves the token. Calling it again for the same user does nothing.
  Future<void> register(String userId) async {
    final platform = _messaging.platform;
    if (platform == null || _userId == userId) return;
    _userId = userId;
    try {
      if (!await _messaging.requestPermission()) return;
      final token = await _messaging.getToken();
      if (token == null || _userId != userId) return;
      await _repository().register(token, platform);
      _token = token;
      unawaited(_refresh?.cancel());
      _refresh = _messaging.onTokenRefresh.listen((t) {
        _token = t;
        _repository().register(t, platform).catchError((Object e) => debugPrint('Token refresh not saved: $e'));
      });
    } catch (e) {
      debugPrint('Push token not saved: $e');
      if (_userId == userId) _userId = null;
    }
  }

  /// Deletes the token while the session is still valid, then drops it from the device.
  Future<void> unregister() async {
    final token = _token;
    _userId = null;
    _token = null;
    unawaited(_refresh?.cancel());
    _refresh = null;
    if (token == null) return;
    try {
      await _repository().unregister(token);
    } catch (e) {
      debugPrint('Push token not deleted: $e');
    }
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Device token not reset: $e');
    }
  }
}
