import 'package:dosey_app/core/cloud/cloud_google_account_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_cloud_identity_gateway.dart';

void main() {
  test(
    'authenticate maps the cloud identity into local account info',
    () async {
      final cloud = FakeCloudIdentityGateway(
        identity: const CloudIdentity.signedIn(
          accountId: 'account-1',
          email: 'owner@example.com',
          displayName: 'Owner',
        ),
        signInResult: const CloudIdentity.signedIn(
          accountId: 'account-1',
          email: 'owner@example.com',
          displayName: 'Owner',
        ),
      );
      final gateway = CloudGoogleAccountGateway(cloud);

      final account = await gateway.authenticate(scopeHint: const ['email']);

      expect(account.id, 'account-1');
      expect(account.email, 'owner@example.com');
      expect(account.displayName, 'Owner');
      expect(cloud.signInCount, 1);
      expect(cloud.lastScopes, const ['email']);
    },
  );

  test('lightweight authentication restores an Appwrite session', () async {
    final cloud = FakeCloudIdentityGateway(
      identity: const CloudIdentity.signedOut(),
    );
    final gateway = CloudGoogleAccountGateway(cloud);

    expect(await gateway.attemptLightweightAuthentication(), isNull);
  });
}
