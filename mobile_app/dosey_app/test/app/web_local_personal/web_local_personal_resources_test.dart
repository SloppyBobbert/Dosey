import 'dart:io';

import 'package:dosey_app/app/web/web_routes.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets(
    'paired landing exposes full-page local link without replacing sign-in',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WebLandingScreen(localPersonalEnabled: true)),
      );
      expect(find.text('Sign in'), findsOneWidget);
      final link = tester.widget<Link>(find.byType(Link));
      expect(link.uri, Uri(path: '/local/'));
      expect(link.target, LinkTarget.self);
      await tester.pumpWidget(
        const MaterialApp(home: WebLandingScreen(localPersonalEnabled: false)),
      );
      expect(find.byType(Link), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  test('local entry uses isolated namespace and phone-only composition', () {
    expect(WebLocalPersonalStartup.databaseName, 'dosey-personal-local');
    expect(WebLocalPersonalStartup.capability, RuntimeCapability.phoneOnly);
    final entry = File('lib/main_web_local.dart').readAsStringSync();
    expect(
      entry,
      contains('databaseName: WebLocalPersonalStartup.databaseName'),
    );
    for (final forbidden in [
      'DoseyAppScope',
      'createWebCloudGateways',
      'DoseyWebDependencies',
      'NotificationService',
    ]) {
      expect(entry, isNot(contains(forbidden)));
    }
  });

  test('local templates restrict remote resources before app scripts', () {
    final html = File('tool/local_personal/index.html').readAsStringSync();
    expect(
      html.indexOf('Content-Security-Policy'),
      lessThan(html.indexOf('<script')),
    );
    expect(html, contains("script-src 'self' 'wasm-unsafe-eval'"));
    expect(html, contains("font-src 'self'"));
    expect(html, contains('<base href="/local/">'));
    expect(html, isNot(contains('https:')));
    final loader = File(
      'tool/local_personal/flutter_loader.js',
    ).readAsStringSync();
    expect(
      loader.replaceAll('"', "'"),
      contains("fontFallbackBaseUrl: '/local/assets/local_fonts/'"),
    );
    expect(
      loader.replaceAll('"', "'"),
      contains("canvasKitBaseUrl: '/local/canvaskit/'"),
    );
    expect(loader, isNot(contains('serviceWorkerSettings')));
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto_LICENSE.txt',
    ]) {
      expect(
        File('tool/local_personal/assets/local_fonts/$name').lengthSync(),
        greaterThan(0),
      );
    }
  });
}
