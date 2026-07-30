import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web-owned Dart source stays outside device and local-data lanes', () {
    final roots = <FileSystemEntity>[
      File('lib/main_web.dart'),
      ...Directory('lib/app/web').listSync(recursive: true),
    ];
    final forbidden = [
      RegExp(r'dart:io', caseSensitive: false),
      RegExp(r'\bnative\b', caseSensitive: false),
      RegExp(r'\bble\b', caseSensitive: false),
      RegExp(
        r'''['"][^'"\r\n]*(carousel|dispense|simulator|local notification|mounted-phone|robot face)[^'"\r\n]*['"]''',
        caseSensitive: false,
      ),
      RegExp(
        r'package:dosey_app/(core/(database|hardware|notifications|persistence)|features/(today|medications|reminders))/',
        caseSensitive: false,
      ),
      RegExp(r'flutter_blue_plus', caseSensitive: false),
      RegExp(r'google_sign_in', caseSensitive: false),
      RegExp(r'flutter_local_notifications', caseSensitive: false),
      RegExp(r'permission_handler', caseSensitive: false),
    ];
    for (final entity in roots.whereType<File>()) {
      if (!entity.path.endsWith('.dart') ||
          entity.path.endsWith('web_boundary_test.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final fragment in forbidden) {
        expect(
          fragment.hasMatch(source),
          isFalse,
          reason: '${entity.path} contains $fragment',
        );
      }
    }
  });
}
