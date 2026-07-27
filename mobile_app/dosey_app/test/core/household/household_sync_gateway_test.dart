import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled household sync has no cloud robot', () async {
    const gateway = DisabledHouseholdSyncGateway();

    expect(await gateway.watchRobot().first, isNull);
    await expectLater(
      gateway.createRobot(
        displayName: 'Kitchen Dosey',
        ownerAccountId: 'owner-1',
        mountedDeviceId: 'mounted-android-1',
      ),
      throwsA(isA<CloudNotConfiguredException>()),
    );
  });
}
