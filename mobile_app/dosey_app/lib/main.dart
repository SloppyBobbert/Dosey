import 'package:dosey_app/app/dosey_app.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:flutter/material.dart';

export 'package:dosey_app/app/dosey_app.dart';

void main() {
  final buildCapabilities = AppBuildProfile.current.resolve(
    currentAppDevicePlatform(),
  );
  final cloud = createCloudGateways(
    CloudConfiguration.fromEnvironment,
    profile: buildCapabilities.canHostRobot
        ? CloudGatewayProfile.robot
        : CloudGatewayProfile.personal,
  );
  runApp(
    DoseyApp(
      cloudIdentityGateway: cloud.identity,
      householdSyncGateway: cloud.household,
      householdManagementGateway: cloud.householdManagement,
      robotPairingGateway: cloud.pairing,
      mountedRobotAccessGateway: cloud.mountedRobotAccess,
    ),
  );
}
