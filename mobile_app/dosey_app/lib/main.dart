import 'package:dosey_app/app/dosey_app.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:flutter/material.dart';

export 'package:dosey_app/app/dosey_app.dart';

void main() {
  final cloud = createCloudGateways(CloudConfiguration.fromEnvironment);
  runApp(
    DoseyApp(
      cloudIdentityGateway: cloud.identity,
      householdSyncGateway: cloud.household,
      householdManagementGateway: cloud.householdManagement,
      robotPairingGateway: cloud.pairing,
    ),
  );
}
