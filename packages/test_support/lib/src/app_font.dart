import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Cairo so goldens and text sizes in widget tests match the apps.
Future<void> loadAppFont() async {
  final font = FontLoader('packages/shared/Cairo')
    ..addFont(Future.value(ByteData.sublistView(_cairoFont().readAsBytesSync())));
  await font.load();
}

File _cairoFont() {
  for (var dir = Directory.current.absolute; ; dir = dir.parent) {
    final file = File('${dir.path}/packages/shared/assets/fonts/Cairo-Variable.ttf');
    if (file.existsSync()) return file;
    if (dir.parent.path == dir.path) throw StateError('Cairo-Variable.ttf not found above ${Directory.current.path}');
  }
}
