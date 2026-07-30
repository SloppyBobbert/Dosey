import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source and built package preserve every browser route artifact', () {
    const routes = [
      'sign-in',
      'household',
      'app/today',
      'app/medications',
      'app/schedules',
      'app/account',
    ];

    final roots = ['web', if (Directory('build/web').existsSync()) 'build/web'];

    for (final root in roots) {
      for (final route in routes) {
        final file = File('$root/$route/index.html');
        expect(
          file.existsSync(),
          isTrue,
          reason: '$root/$route must survive direct navigation and refresh',
        );
        final source = file.readAsStringSync();
        expect(source, contains('<base href="/">'));
        expect(source, contains('href="/manifest.json"'));
        expect(source, contains('src="/flutter_bootstrap.js"'));
      }
    }
  });
}
