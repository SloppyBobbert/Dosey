enum HouseholdConnectionState { localOnly, cloudLinked }

class HouseholdAccountState {
  const HouseholdAccountState({
    this.householdDisplayName = 'Dosey household',
    this.robotHubDisplayName = 'Dosey robot phone',
    this.connectionState = HouseholdConnectionState.localOnly,
    this.cloudHouseholdId,
  });

  final String householdDisplayName;
  final String robotHubDisplayName;
  final HouseholdConnectionState connectionState;
  final String? cloudHouseholdId;
}
