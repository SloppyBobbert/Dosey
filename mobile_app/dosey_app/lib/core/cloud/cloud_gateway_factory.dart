import 'package:appwrite/appwrite.dart';
import 'package:dosey_app/core/cloud/appwrite_cloud_identity_gateway.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_sync_gateway.dart';
import 'package:dosey_app/core/household/appwrite_household_management_gateway.dart';
import 'package:dosey_app/core/household/appwrite_robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/household/mounted_robot_access_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';

typedef AppwriteAccountApiFactory =
    AppwriteAccountApi Function(CloudConfiguration configuration);

CloudIdentityGateway createWebCloudIdentityGateway(
  CloudConfiguration configuration, {
  AppwriteAccountApiFactory? accountApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const DisabledCloudIdentityGateway();
  }

  final accountApi = accountApiFactory != null
      ? accountApiFactory(configuration)
      : _createAppwriteAccountApi(configuration);
  return AppwriteCloudIdentityGateway(accountApi);
}

typedef AppwriteTeamsApiFactory =
    AppwriteTeamsApi Function(CloudConfiguration configuration);
typedef AppwritePairingApiFactory =
    AppwriteRobotPairingApi Function(CloudConfiguration configuration);
typedef AppwriteHouseholdFunctionsApiFactory =
    AppwriteHouseholdFunctionsApi Function(CloudConfiguration configuration);
typedef AppwriteMountedRobotAccessApiFactory =
    AppwriteMountedRobotAccessApi Function(CloudConfiguration configuration);

enum CloudGatewayProfile { personal, robot }

class CloudGateways {
  const CloudGateways({
    required this.identity,
    required this.household,
    required this.householdManagement,
    required this.pairing,
    required this.mountedRobotAccess,
  });

  final CloudIdentityGateway identity;
  final HouseholdSyncGateway household;
  final HouseholdManagementGateway householdManagement;
  final RobotPairingGateway pairing;
  final MountedRobotAccessGateway mountedRobotAccess;
}

CloudGateways createCloudGateways(
  CloudConfiguration configuration, {
  CloudGatewayProfile profile = CloudGatewayProfile.personal,
  AppwriteAccountApiFactory? accountApiFactory,
  AppwriteTeamsApiFactory? teamsApiFactory,
  AppwritePairingApiFactory? pairingApiFactory,
  AppwriteHouseholdFunctionsApiFactory? householdFunctionsApiFactory,
  AppwriteMountedRobotAccessApiFactory? mountedRobotAccessApiFactory,
}) {
  if (!configuration.isEnabled) {
    return const CloudGateways(
      identity: DisabledCloudIdentityGateway(),
      household: DisabledHouseholdSyncGateway(),
      householdManagement: DisabledHouseholdManagementGateway(),
      pairing: DisabledRobotPairingGateway(),
      mountedRobotAccess: DisabledMountedRobotAccessGateway(),
    );
  }

  // Provider construction belongs here so the rest of app composition only
  // sees Dosey-owned contracts when Appwrite is replaced.
  if (accountApiFactory != null ||
      teamsApiFactory != null ||
      pairingApiFactory != null ||
      householdFunctionsApiFactory != null ||
      mountedRobotAccessApiFactory != null) {
    final accountApi = (accountApiFactory ?? _createAppwriteAccountApi)(
      configuration,
    );
    final household = profile == CloudGatewayProfile.robot
        ? const DisabledHouseholdSyncGateway()
        : AppwriteHouseholdSyncGateway(
            _LazyAppwriteTeamsApi(
              () => (teamsApiFactory ?? _createAppwriteTeamsApi)(configuration),
            ),
          );
    final pairingEnabled = profile == CloudGatewayProfile.robot
        ? configuration.isRobotClaimEnabled
        : configuration.isPersonalPairingEnabled;
    final pairing = pairingEnabled
        ? AppwriteRobotPairingGateway(
            (pairingApiFactory ?? _createAppwritePairingApi)(configuration),
            profile == CloudGatewayProfile.personal
                ? configuration.createPairingCodeFunctionId
                : null,
            configuration.claimRobotFunctionId!,
          )
        : const DisabledRobotPairingGateway();
    return CloudGateways(
      identity: AppwriteCloudIdentityGateway(accountApi),
      household: household,
      householdManagement: profile == CloudGatewayProfile.robot
          ? const DisabledHouseholdManagementGateway()
          : _createHouseholdManagementGateway(
              configuration,
              householdFunctionsApiFactory,
            ),
      pairing: pairing,
      mountedRobotAccess:
          profile == CloudGatewayProfile.robot &&
              configuration.isMountedRobotAccessEnabled
          ? AppwriteMountedRobotAccessGateway(
              _LazyMountedRobotAccessApi(
                () =>
                    (mountedRobotAccessApiFactory ??
                    _createAppwriteMountedRobotAccessApi)(configuration),
              ),
              configuration.getMountedRobotFunctionId!,
            )
          : const DisabledMountedRobotAccessGateway(),
    );
  }

  final client = _createAppwriteClient(configuration);
  final household = profile == CloudGatewayProfile.robot
      ? const DisabledHouseholdSyncGateway()
      : AppwriteHouseholdSyncGateway(
          _LazyAppwriteTeamsApi(
            () => AppwriteTeamsApiAdapter(Teams(client), Account(client)),
          ),
        );
  final pairingEnabled = profile == CloudGatewayProfile.robot
      ? configuration.isRobotClaimEnabled
      : configuration.isPersonalPairingEnabled;
  return CloudGateways(
    identity: AppwriteCloudIdentityGateway(
      AppwriteAccountApiAdapter(Account(client)),
    ),
    household: household,
    householdManagement: profile == CloudGatewayProfile.robot
        ? const DisabledHouseholdManagementGateway()
        : configuration.isHouseholdManagementEnabled
        ? AppwriteHouseholdManagementGateway(
            AppwriteHouseholdFunctionsApiAdapter(Functions(client)),
            createRobotFunctionId: configuration.createRobotFunctionId!,
            createInvitationFunctionId:
                configuration.createHouseholdInvitationFunctionId!,
            acceptInvitationFunctionId:
                configuration.acceptHouseholdInvitationFunctionId!,
            removeMemberFunctionId:
                configuration.removeHouseholdMemberFunctionId!,
          )
        : const DisabledHouseholdManagementGateway(),
    pairing: pairingEnabled
        ? AppwriteRobotPairingGateway(
            AppwriteRobotPairingApiAdapter(Account(client), Functions(client)),
            profile == CloudGatewayProfile.personal
                ? configuration.createPairingCodeFunctionId
                : null,
            configuration.claimRobotFunctionId!,
          )
        : const DisabledRobotPairingGateway(),
    mountedRobotAccess:
        profile == CloudGatewayProfile.robot &&
            configuration.isMountedRobotAccessEnabled
        ? AppwriteMountedRobotAccessGateway(
            _LazyMountedRobotAccessApi(
              () => AppwriteMountedRobotAccessApiAdapter(Functions(client)),
            ),
            configuration.getMountedRobotFunctionId!,
          )
        : const DisabledMountedRobotAccessGateway(),
  );
}

AppwriteAccountApi _createAppwriteAccountApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteAccountApiAdapter(Account(client));
}

AppwriteTeamsApi _createAppwriteTeamsApi(CloudConfiguration configuration) {
  final client = _createAppwriteClient(configuration);
  return AppwriteTeamsApiAdapter(Teams(client), Account(client));
}

AppwriteMountedRobotAccessApi _createAppwriteMountedRobotAccessApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteMountedRobotAccessApiAdapter(Functions(client));
}

HouseholdManagementGateway _createHouseholdManagementGateway(
  CloudConfiguration configuration,
  AppwriteHouseholdFunctionsApiFactory? apiFactory,
) {
  if (!configuration.isHouseholdManagementEnabled) {
    return const DisabledHouseholdManagementGateway();
  }
  return AppwriteHouseholdManagementGateway(
    (apiFactory ?? _createAppwriteHouseholdFunctionsApi)(configuration),
    createRobotFunctionId: configuration.createRobotFunctionId!,
    createInvitationFunctionId:
        configuration.createHouseholdInvitationFunctionId!,
    acceptInvitationFunctionId:
        configuration.acceptHouseholdInvitationFunctionId!,
    removeMemberFunctionId: configuration.removeHouseholdMemberFunctionId!,
  );
}

AppwriteHouseholdFunctionsApi _createAppwriteHouseholdFunctionsApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteHouseholdFunctionsApiAdapter(Functions(client));
}

AppwriteRobotPairingApi _createAppwritePairingApi(
  CloudConfiguration configuration,
) {
  final client = _createAppwriteClient(configuration);
  return AppwriteRobotPairingApiAdapter(Account(client), Functions(client));
}

Client _createAppwriteClient(CloudConfiguration configuration) =>
    Client(endPoint: configuration.endpoint!)
      ..setProject(configuration.projectId!);

class _LazyAppwriteTeamsApi implements AppwriteTeamsApi {
  _LazyAppwriteTeamsApi(this._create);

  final AppwriteTeamsApi Function() _create;
  AppwriteTeamsApi? _delegate;

  AppwriteTeamsApi get _api => _delegate ??= _create();

  @override
  Future<List<RobotInstallation>> listRobotTeams() => _api.listRobotTeams();
}

class _LazyMountedRobotAccessApi implements AppwriteMountedRobotAccessApi {
  _LazyMountedRobotAccessApi(this._create);

  final AppwriteMountedRobotAccessApi Function() _create;
  AppwriteMountedRobotAccessApi? _delegate;

  AppwriteMountedRobotAccessApi get _api => _delegate ??= _create();

  @override
  Future<MountedRobotFunctionResponse> execute({
    required String functionId,
    required String body,
  }) => _api.execute(functionId: functionId, body: body);
}
