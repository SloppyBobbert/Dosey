import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled household sync has no cloud robot', () async {
    const gateway = DisabledHouseholdSyncGateway();

    expect(await gateway.watchRobot().first, isNull);
    expect(await gateway.refreshRobot(), isNull);
  });
}
