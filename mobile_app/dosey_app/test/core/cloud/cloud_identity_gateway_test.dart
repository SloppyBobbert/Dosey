import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled cloud identity remains signed out', () async {
    const gateway = DisabledCloudIdentityGateway();

    expect(
      await gateway.watchIdentity().first,
      const CloudIdentity.signedOut(),
    );
    await expectLater(
      gateway.signInWithGoogle(),
      throwsA(isA<CloudNotConfiguredException>()),
    );
    await gateway.signOut();
  });
}
