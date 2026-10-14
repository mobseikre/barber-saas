import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/enums.dart';

/// A notification that arrived while the app was open; [type] is the `type` of its data, e.g. `barber_activated`.
typedef PushNotice = ({String? title, String? body, String? type});

/// The device's push service. Tests replace it with a fake.
abstract interface class PushMessaging {
  /// Null where the app cannot receive push: web, desktop, or a build without the Firebase files.
  DevicePlatform? get platform;
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushNotice> get onMessage;
  Future<void> deleteToken();
}

class NoPushMessaging implements PushMessaging {
  const NoPushMessaging();

  @override
  DevicePlatform? get platform => null;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushNotice> get onMessage => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this.platform);

  @override
  final DevicePlatform platform;
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fcm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushNotice> get onMessage => FirebaseMessaging.onMessage.map(
    (m) => (title: m.notification?.title, body: m.notification?.body, type: m.data['type'] as String?),
  );

  @override
  Future<void> deleteToken() => _fcm.deleteToken();
}

/// Starts Firebase on Android and iOS. Push stays off when the Firebase files are missing.
Future<PushMessaging> initPush() async {
  final platform = kIsWeb
      ? null
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => DevicePlatform.android,
          TargetPlatform.iOS => DevicePlatform.ios,
          _ => null,
        };
  if (platform == null) return const NoPushMessaging();
  try {
    await Firebase.initializeApp();
    return FirebasePushMessaging(platform);
  } catch (e) {
    debugPrint('Push notifications are off: $e');
    return const NoPushMessaging();
  }
}
