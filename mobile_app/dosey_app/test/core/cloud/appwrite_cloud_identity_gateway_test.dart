import 'dart:async';

import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled gateway rejects email OTP operations', () async {
    const gateway = DisabledCloudIdentityGateway();

    await expectLater(
      gateway.requestEmailOtp('owner@example.com'),
      throwsA(isA<CloudNotConfiguredException>()),
    );
    await expectLater(
      gateway.completeEmailOtp(userId: 'user-1', secret: 'secret-1'),
      throwsA(isA<CloudNotConfiguredException>()),
    );
  });

  test('watchIdentity restores the current Appwrite account', () async {
    final account = _FakeAppwriteAccountApi(
      currentIdentity: const CloudIdentity.signedIn(
        accountId: 'account-1',
        email: 'owner@example.com',
        displayName: 'Owner',
      ),
    );
    final gateway = AppwriteCloudIdentityGateway(account);

    await expectLater(
      gateway.watchIdentity().first,
      completion(account.currentIdentity),
    );
  });

  test('watchIdentity restores signed out when no session exists', () async {
    final gateway = AppwriteCloudIdentityGateway(_FakeAppwriteAccountApi());

    await expectLater(
      gateway.watchIdentity().first,
      completion(const CloudIdentity.signedOut()),
    );
  });

  test('watchIdentity reports restoration failures to subscribers', () async {
    final gateway = AppwriteCloudIdentityGateway(
      _FakeAppwriteAccountApi(restoreError: StateError('restore failed')),
    );

    await expectLater(gateway.watchIdentity().first, throwsStateError);
  });

  test('Google sign-in publishes the authenticated identity', () async {
    const signedIn = CloudIdentity.signedIn(
      accountId: 'account-1',
      email: 'owner@example.com',
    );
    final account = _FakeAppwriteAccountApi(identityAfterSignIn: signedIn);
    final gateway = AppwriteCloudIdentityGateway(account);
    final identities = StreamIterator(gateway.watchIdentity());
    expect(await identities.moveNext(), isTrue);
    final changed = identities.moveNext();

    final result = await gateway.signInWithGoogle(scopes: const ['email']);

    expect(result, signedIn);
    expect(await changed, isTrue);
    expect(identities.current, signedIn);
    expect(account.googleSignInCount, 1);
    expect(account.lastScopes, const ['email']);
    unawaited(identities.cancel());
  });

  test('Google sign-in forwards callback URLs', () async {
    final account = _FakeAppwriteAccountApi(
      identityAfterSignIn: const CloudIdentity.signedIn(
        accountId: 'account-1',
        email: 'owner@example.com',
      ),
    );

    await AppwriteCloudIdentityGateway(account).signInWithGoogle(
      successUrl: 'https://dosey.example/success',
      failureUrl: 'https://dosey.example/failure',
    );

    expect(account.lastSuccessUrl, 'https://dosey.example/success');
    expect(account.lastFailureUrl, 'https://dosey.example/failure');
  });

  test(
    'email OTP request normalizes email and returns UI-only user ID',
    () async {
      final account = _FakeAppwriteAccountApi(emailTokenUserId: 'user-1');

      final userId = await AppwriteCloudIdentityGateway(
        account,
      ).requestEmailOtp('  OWNER@EXAMPLE.COM ');

      expect(userId, 'user-1');
      expect(account.lastEmail, 'owner@example.com');
      expect(account.lastEmailUserId, 'user-1');
    },
  );

  test(
    'email OTP completion creates a session and publishes identity',
    () async {
      const signedIn = CloudIdentity.signedIn(
        accountId: 'account-1',
        email: 'owner@example.com',
      );
      final account = _FakeAppwriteAccountApi(identityAfterOtp: signedIn);
      final gateway = AppwriteCloudIdentityGateway(account);
      final identities = StreamIterator(gateway.watchIdentity());
      expect(await identities.moveNext(), isTrue);
      final changed = identities.moveNext();

      final result = await gateway.completeEmailOtp(
        userId: 'user-1',
        secret: 'secret-1',
      );

      expect(result, signedIn);
      expect(account.lastOtpUserId, 'user-1');
      expect(account.lastOtpSecret, 'secret-1');
      expect(await changed, isTrue);
      expect(identities.current, signedIn);
      unawaited(identities.cancel());
    },
  );

  test(
    'email OTP completion rejects when Appwrite has no current identity',
    () {
      return expectLater(
        AppwriteCloudIdentityGateway(
          _FakeAppwriteAccountApi(),
        ).completeEmailOtp(userId: 'user-1', secret: 'secret-1'),
        throwsStateError,
      );
    },
  );

  test('sign out deletes only the current device session', () async {
    final account = _FakeAppwriteAccountApi();
    final gateway = AppwriteCloudIdentityGateway(account);
    final identities = StreamIterator(gateway.watchIdentity());
    expect(await identities.moveNext(), isTrue);
    final changed = identities.moveNext();

    await gateway.signOut();

    expect(await changed, isTrue);
    expect(identities.current, const CloudIdentity.signedOut());
    expect(account.signOutCount, 1);
    unawaited(identities.cancel());
  });
}

class _FakeAppwriteAccountApi implements AppwriteAccountApi {
  _FakeAppwriteAccountApi({
    this.currentIdentity,
    this.identityAfterSignIn,
    this.identityAfterOtp,
    this.emailTokenUserId,
    this.restoreError,
  });

  CloudIdentity? currentIdentity;
  final CloudIdentity? identityAfterSignIn;
  final CloudIdentity? identityAfterOtp;
  final String? emailTokenUserId;
  final Object? restoreError;
  int googleSignInCount = 0;
  List<String>? lastScopes;
  String? lastSuccessUrl;
  String? lastFailureUrl;
  String? lastEmail;
  String? lastEmailUserId;
  String? lastOtpUserId;
  String? lastOtpSecret;
  int signOutCount = 0;

  @override
  Future<CloudIdentity?> getCurrentIdentity() async {
    if (restoreError case final error?) throw error;
    return currentIdentity;
  }

  @override
  Future<void> signInWithGoogle({
    required List<String> scopes,
    String? successUrl,
    String? failureUrl,
  }) async {
    googleSignInCount += 1;
    lastScopes = scopes;
    lastSuccessUrl = successUrl;
    lastFailureUrl = failureUrl;
    currentIdentity = identityAfterSignIn;
  }

  @override
  Future<String> requestEmailOtp(String email) async {
    lastEmail = email;
    lastEmailUserId = emailTokenUserId;
    return emailTokenUserId!;
  }

  @override
  Future<void> completeEmailOtp({
    required String userId,
    required String secret,
  }) async {
    lastOtpUserId = userId;
    lastOtpSecret = secret;
    currentIdentity = identityAfterOtp;
  }

  @override
  Future<void> signOutCurrentSession() async {
    signOutCount += 1;
    currentIdentity = null;
  }
}
