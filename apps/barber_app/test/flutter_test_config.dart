import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = FontLoader('packages/shared/Cairo')
    ..addFont(Future.value(ByteData.sublistView(_cairoFont().readAsBytesSync())));
  await font.load();
  await testMain();
}

File _cairoFont() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final file = File('${dir.path}/packages/shared/assets/fonts/Cairo-Variable.ttf');
    if (file.existsSync()) return file;
    if (dir.parent.path == dir.path) throw StateError('Cairo-Variable.ttf not found above ${Directory.current.path}');
  }
}
