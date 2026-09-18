import 'dart:io';

import 'package:flutter/services.dart';

const robotFaceTestFont = 'RobotFaceOfflineRoboto';
bool _fontsLoaded = false;

// Use the SDK's already-cached Android default font, never fetch test assets.
Future<void> loadRobotFaceTestFont() async {
  if (_fontsLoaded) return;
  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    final font = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    );
    if (font.existsSync()) {
      final loader = FontLoader(robotFaceTestFont)
        ..addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
      final icons = File('${font.parent.path}/MaterialIcons-Regular.otf');
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then(ByteData.sublistView));
      await iconLoader.load();
      _fontsLoaded = true;
      return;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError(
        'Cached Flutter Roboto font not found; no download permitted.',
      );
    }
    directory = parent;
  }
}
