import 'package:dosey_app/app/dosey_app.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/runtime/local_runtime_capability_repository.dart';
import 'package:dosey_app/core/runtime/runtime_bootstrap.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/material.dart';

export 'package:dosey_app/app/dosey_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final buildProfile = AppBuildProfile.current;
  final capability = RuntimeCapability.resolve(
    configuredValue: RuntimeCapability.configuredEnvironmentValue,
    buildProfile: buildProfile,
    platform: currentAppDevicePlatform(),
  );
  final database = DoseyDatabase();
  await LocalRuntimeCapabilityRepository(database).ensureConfigured(capability);

  if (!RuntimeBootstrap.shouldCreateCloudGateways(capability)) {
    runApp(
      DoseyApp(
        database: database,
        buildProfile: buildProfile,
        runtimeCapability: capability,
      ),
    );
    return;
  }

  final cloud = createCloudGateways(CloudConfiguration.fromEnvironment);
  runApp(
    DoseyApp(
      database: database,
      buildProfile: buildProfile,
      runtimeCapability: capability,
      cloudIdentityGateway: cloud.identity,
      householdSyncGateway: cloud.household,
      householdManagementGateway: cloud.householdManagement,
      robotPairingGateway: cloud.pairing,
    ),
  );
}
