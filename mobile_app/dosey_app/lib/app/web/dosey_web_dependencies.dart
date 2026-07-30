import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';

import 'web_auth_configuration.dart';

class DoseyWebDependencies {
  const DoseyWebDependencies({
    required this.identity,
    required this.config,
    this.household = const DisabledHouseholdSyncGateway(),
    this.householdManagement = const DisabledHouseholdManagementGateway(),
    this.caregiver = const DisabledCaregiverSyncGateway(),
    this.now = DateTime.now,
  });

  final CloudIdentityGateway identity;
  final WebAuthConfiguration config;
  final HouseholdSyncGateway household;
  final HouseholdManagementGateway householdManagement;
  final CaregiverSyncGateway caregiver;
  final DateTime Function() now;
}
