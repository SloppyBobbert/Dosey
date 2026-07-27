import 'dart:async';

import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    final result = await gateway.signInWithGoogle();

    expect(result, signedIn);
    expect(await changed, isTrue);
    expect(identities.current, signedIn);
    expect(account.googleSignInCount, 1);
    unawaited(identities.cancel());
  });

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
  _FakeAppwriteAccountApi({this.currentIdentity, this.identityAfterSignIn});

  CloudIdentity? currentIdentity;
  final CloudIdentity? identityAfterSignIn;
  int googleSignInCount = 0;
  int signOutCount = 0;

  @override
  Future<CloudIdentity?> getCurrentIdentity() async => currentIdentity;

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCount += 1;
    currentIdentity = identityAfterSignIn;
  }

  @override
  Future<void> signOutCurrentSession() async {
    signOutCount += 1;
    currentIdentity = null;
  }
}
