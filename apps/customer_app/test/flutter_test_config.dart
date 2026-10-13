import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFont();
  await testMain();
}
