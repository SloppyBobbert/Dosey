import 'package:appwrite/appwrite.dart';
import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';

typedef AppwriteAccountApiFactory =
    AppwriteAccountApi Function(CloudConfiguration configuration);
typedef AppwriteTeamsApiFactory =
    AppwriteTeamsApi Function(CloudConfiguration configuration);

class CloudGateways {
  const CloudGateways({required this.identity, required this.household});

  final CloudIdentityGateway identity;
  final HouseholdSyncGateway household;
}

CloudGateways createCloudGateways(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
  AppwriteTeamsApiFactory? teamsApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const CloudGateways(
      identity: DisabledCloudIdentityGateway(),
      household: DisabledHouseholdSyncGateway(),
    );
  }

  // Provider construction belongs here so the rest of app composition only
  // sees Dosey-owned contracts when Appwrite is replaced.
  if (accountApiFactory != null || teamsApiFactory != null) {
    final accountApi = (accountApiFactory ?? _createAppwriteAccountApi)(
      configuration,
    );
    final teamsApi = (teamsApiFactory ?? _createAppwriteTeamsApi)(
      configuration,
    );
    return CloudGateways(
      identity: AppwriteCloudIdentityGateway(accountApi),
      household: AppwriteHouseholdSyncGateway(teamsApi),
    );
  }

  final client = _createAppwriteClient(configuration);
  return CloudGateways(
    identity: AppwriteCloudIdentityGateway(
      AppwriteAccountApiAdapter(Account(client)),
    ),
    household: AppwriteHouseholdSyncGateway(
      AppwriteTeamsApiAdapter(Teams(client)),
    ),
  );
}

AppwriteAccountApi _createAppwriteAccountApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteAccountApiAdapter(Account(client));
}

AppwriteTeamsApi _createAppwriteTeamsApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteTeamsApiAdapter(Teams(client));
}

Client _createAppwriteClient(CloudConfiguration configuration) =>
    Client(endPoint: configuration.endpoint!)
      ..setProject(configuration.projectId!);
