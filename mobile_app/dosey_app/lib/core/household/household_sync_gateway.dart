import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';

abstract interface class HouseholdSyncGateway {
  // Robot ownership is a Dosey domain concept, not an Appwrite Team concept.
  // Provider adapters are responsible for translating between the two.
  Stream<RobotInstallation?> watchRobot();

  Future<RobotInstallation> createRobot({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  });
}

class DisabledHouseholdSyncGateway implements HouseholdSyncGateway {
  const DisabledHouseholdSyncGateway();

  @override
  Stream<RobotInstallation?> watchRobot() => Stream.value(null);

  @override
  Future<RobotInstallation> createRobot({
    required String displayName,
    required String ownerAccountId,
    required String mountedDeviceId,
  }) => Future.error(const CloudNotConfiguredException());
}
