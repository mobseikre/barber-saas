import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers url_launcher in widget tests and records every URL the app opens.
class FakeLauncher {
  FakeLauncher(WidgetTester tester, {this.opens = true}) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'launch') urls.add(Uri.parse((call.arguments as Map)['url'] as String));
      return opens;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  }

  static const _channel = MethodChannel('plugins.flutter.io/url_launcher');

  bool opens;
  final urls = <Uri>[];
}
