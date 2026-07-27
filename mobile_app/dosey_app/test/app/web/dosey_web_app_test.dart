import 'dart:async';

import 'package:dosey_app/app/web/dosey_web_app.dart';
import 'package:dosey_app/app/web/dosey_web_dependencies.dart';
import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final identities = <_FakeIdentity>[];

  tearDown(() async {
    for (final identity in identities) {
      await identity.close();
    }
    identities.clear();
  });

  _FakeIdentity track(_FakeIdentity identity) {
    identities.add(identity);
    return identity;
  }

  testWidgets('disabled preview explains the stable release boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: track(_FakeIdentity()),
          config: WebAuthConfiguration.fromValues(enabled: false),
        ),
      ),
    );
    expect(
      find.text(
        'Account access is available on stable staging and production builds.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Robot Face'), findsNothing);
  });

  testWidgets('signed-out personal lane supports email validation', (
    tester,
  ) async {
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: track(_FakeIdentity()),
          config: WebAuthConfiguration.fromValues(
            enabled: true,
            appOrigin: 'http://localhost:8080',
            endpoint: 'https://cloud.example/v1',
            projectId: 'project',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Email me a code'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('signed-in lane shows account details and can sign out', (
    tester,
  ) async {
    final identity = track(
      _FakeIdentity(
        const CloudIdentity.signedIn(
          accountId: 'a',
          email: 'person@example.com',
        ),
      ),
    );
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: WebAuthConfiguration.fromValues(
            enabled: true,
            appOrigin: 'http://localhost:8080',
            endpoint: 'https://cloud.example/v1',
            projectId: 'project',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('person@example.com'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    expect(identity.didSignOut, isTrue);
  });

  testWidgets('staging banner follows the configured origin', (tester) async {
    final identity = track(
      _FakeIdentity(
        const CloudIdentity.signedIn(
          accountId: 'a',
          email: 'person@example.com',
        ),
      ),
    );
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://staging.dosey.dev'),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Staging environment'), findsOneWidget);
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://app.dosey.dev'),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Staging environment'), findsNothing);
  });

  testWidgets('forwards Google callback URLs exactly', (tester) async {
    final identity = track(_FakeIdentity());
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('https://app.dosey.dev'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(identity.googleSuccessUrl, contains('/auth.html?result=success'));
    expect(identity.googleFailureUrl, contains('/auth.html?result=failure'));
  });

  testWidgets('email flow hides secrets and forwards completion values', (
    tester,
  ) async {
    final identity = track(_FakeIdentity.withEmailUserId('user-secret'));
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('http://localhost:8080'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    expect(find.text('Complete sign in'), findsOneWidget);
    expect(find.text('user-secret'), findsNothing);
    await tester.enterText(find.byType(TextField), 'not-a-code');
    await tester.tap(find.text('Complete sign in'));
    await tester.pump();
    expect(
      find.text('Enter the numeric code from your email.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Complete sign in'));
    await tester.pumpAndSettle();
    expect(identity.completedUserId, 'user-secret');
    expect(identity.completedSecret, '2468');
    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('email code state can resend and return to email entry', (
    tester,
  ) async {
    final identity = track(_FakeIdentity.withEmailUserId('user-secret'));
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('http://localhost:8080'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(identity.requestedEmails, [
      'person@example.com',
      'person@example.com',
    ]);
    expect(find.text('Complete sign in'), findsOneWidget);
    await tester.tap(find.text('Use a different email'));
    await tester.pump();
    expect(find.text('Email me a code'), findsOneWidget);
    expect(find.text('Complete sign in'), findsNothing);
  });

  testWidgets(
    'initial restoration shows a restoring state before identity resolves',
    (tester) async {
      final identity = track(_FakeIdentity.deferInitial());
      await tester.pumpWidget(
        DoseyWebApp(
          dependencies: DoseyWebDependencies(
            identity: identity,
            config: _config('http://localhost:8080'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Restoring your account…'), findsOneWidget);
      identity.emit(const CloudIdentity.signedOut());
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    },
  );

  testWidgets('completion failures stay generic and do not leak auth details', (
    tester,
  ) async {
    final identity = track(_FakeIdentity.withEmailUserId('user-secret'))
      ..completeFails = true;
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('http://localhost:8080'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Complete sign in'));
    await tester.pumpAndSettle();
    expect(find.text('secret backend failure'), findsNothing);
    expect(find.text('user-secret'), findsNothing);
    expect(
      find.text('That did not work. Check your details and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('auth failures stay generic and do not leak exception text', (
    tester,
  ) async {
    final identity = track(_FakeIdentity())..requestFails = true;
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('http://localhost:8080'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Email me a code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret backend failure'), findsNothing);
    expect(
      find.text('That did not work. Check your details and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('sign-out failures stay generic', (tester) async {
    final identity = track(
      _FakeIdentity(
        const CloudIdentity.signedIn(
          accountId: 'a',
          email: 'person@example.com',
        ),
      ),
    )..signOutFails = true;
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: _config('http://localhost:8080'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret backend failure'), findsNothing);
    expect(
      find.text('That did not work. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('restoration errors stay in the account lane', (tester) async {
    final identity = track(_FakeIdentity.error());
    await tester.pumpWidget(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: identity,
          config: WebAuthConfiguration.fromValues(
            enabled: true,
            appOrigin: 'http://localhost:8080',
            endpoint: 'https://cloud.example/v1',
            projectId: 'project',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('We could not restore your account.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(identity.watchCount, 2);
  });
}

class _FakeIdentity implements CloudIdentityGateway {
  _FakeIdentity([this.identity = const CloudIdentity.signedOut()])
    : emailUserId = 'user',
      _deferInitial = false,
      _controller = StreamController<CloudIdentity>.broadcast(sync: true);
  _FakeIdentity.withEmailUserId(this.emailUserId)
    : identity = const CloudIdentity.signedOut(),
      _deferInitial = false,
      _controller = StreamController<CloudIdentity>.broadcast(sync: true);
  _FakeIdentity.deferInitial()
    : identity = const CloudIdentity.signedOut(),
      emailUserId = 'user',
      _deferInitial = true,
      _controller = StreamController<CloudIdentity>.broadcast(sync: true);
  _FakeIdentity.error()
    : identity = null,
      emailUserId = 'user',
      _deferInitial = false,
      _controller = StreamController<CloudIdentity>.broadcast(sync: true);

  final CloudIdentity? identity;
  final String emailUserId;
  final StreamController<CloudIdentity> _controller;
  final bool _deferInitial;
  bool didSignOut = false;
  int watchCount = 0;
  String? googleSuccessUrl;
  String? googleFailureUrl;
  String? completedUserId;
  String? completedSecret;
  final requestedEmails = <String>[];
  bool requestFails = false;
  bool completeFails = false;
  bool signOutFails = false;
  bool _closed = false;

  void emit(CloudIdentity value) => _controller.add(value);

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _controller.close();
    }
  }

  @override
  Stream<CloudIdentity> watchIdentity() {
    watchCount++;
    scheduleMicrotask(() {
      if (identity == null) {
        _controller.addError(StateError('restore failed'));
      } else if (!_deferInitial) {
        _controller.add(identity!);
      }
    });
    return _controller.stream;
  }

  @override
  Future<CloudIdentity> signInWithGoogle({
    List<String> scopes = const [],
    String? successUrl,
    String? failureUrl,
  }) async {
    googleSuccessUrl = successUrl;
    googleFailureUrl = failureUrl;
    return const CloudIdentity.signedOut();
  }

  @override
  Future<String> requestEmailOtp(String email) {
    requestedEmails.add(email);
    return requestFails
        ? Future.error(StateError('secret backend failure'))
        : Future.value(emailUserId);
  }

  @override
  Future<CloudIdentity> completeEmailOtp({
    required String userId,
    required String secret,
  }) async {
    completedUserId = userId;
    completedSecret = secret;
    if (completeFails) throw StateError('secret backend failure');
    const signedIn = CloudIdentity.signedIn(
      accountId: 'user-secret',
      email: 'person@example.com',
    );
    _controller.add(signedIn);
    return signedIn;
  }

  @override
  Future<void> signOut() async {
    if (signOutFails) throw StateError('secret backend failure');
    didSignOut = true;
  }
}

WebAuthConfiguration _config(String origin) => WebAuthConfiguration.fromValues(
  enabled: true,
  appOrigin: origin,
  endpoint: 'https://cloud.example/v1',
  projectId: 'project',
);
