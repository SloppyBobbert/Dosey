import 'dart:async';

import 'package:dosey_app/app/web/dosey_web_app.dart';
import 'package:dosey_app/app/web/dosey_web_dependencies.dart';
import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:dosey_app/app/web/web_routes.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public root does not wait for account restoration', (
    tester,
  ) async {
    final identity = _DeferredIdentity();
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://dosey.dev'),
        ),
      ),
    );

    expect(find.text('Medication care, shared clearly.'), findsOneWidget);
    expect(find.text('Restoring your account…'), findsNothing);
    expect(identity.watchCount, 0);
    await identity.close();
  });

  testWidgets('production sign-in offers Google only', (tester) async {
    final identity = _DeferredIdentity();
    await tester.pumpWidget(
      DoseyWebApp(
        initialRoute: WebRoutes.signIn,
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://dosey.dev'),
        ),
      ),
    );
    await tester.pump();
    identity.emit(const CloudIdentity.signedOut());
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email me a code'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await identity.close();
  });

  testWidgets('protected route restores the account before rendering', (
    tester,
  ) async {
    final identity = _DeferredIdentity();
    await tester.pumpWidget(
      DoseyWebApp(
        initialRoute: WebRoutes.account,
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://dosey.dev'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Restoring your account…'), findsOneWidget);

    identity.emit(
      const CloudIdentity.signedIn(
        accountId: 'account-1',
        email: 'caregiver@example.com',
      ),
    );
    await tester.pump();
    expect(find.text('caregiver@example.com'), findsOneWidget);
    await identity.close();
  });

  testWidgets('unknown route has a recovery link', (tester) async {
    final identity = _DeferredIdentity();
    await tester.pumpWidget(
      DoseyWebApp(
        initialRoute: '/not-a-dosey-route/',
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://dosey.dev'),
        ),
      ),
    );
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('Back to Dosey'), findsOneWidget);
    await identity.close();
  });
}

class _DeferredIdentity implements CloudIdentityGateway {
  final _controller = StreamController<CloudIdentity>.broadcast();
  int watchCount = 0;

  void emit(CloudIdentity identity) => _controller.add(identity);
  Future<void> close() => _controller.close();

  @override
  Stream<CloudIdentity> watchIdentity() {
    watchCount += 1;
    return _controller.stream;
  }

  @override
  Future<CloudIdentity> signInWithGoogle({
    List<String> scopes = const [],
    String? successUrl,
    String? failureUrl,
  }) async => const CloudIdentity.signedOut();

  @override
  Future<String> requestEmailOtp(String email) =>
      Future.error(const CloudNotConfiguredException());

  @override
  Future<CloudIdentity> completeEmailOtp({
    required String userId,
    required String secret,
  }) => Future.error(const CloudNotConfiguredException());

  @override
  Future<void> signOut() async {}
}

WebAuthConfiguration _config(String origin) => WebAuthConfiguration.fromValues(
  enabled: true,
  appOrigin: origin,
  endpoint: 'https://cloud.example/v1',
  projectId: 'project',
);
