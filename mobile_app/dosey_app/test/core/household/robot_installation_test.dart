import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single owner and separate robot identity form a valid robot', () {
    final installation = RobotInstallation(
      id: 'robot-1',
      displayName: 'Kitchen Dosey',
      ownerAccountId: 'owner-1',
      members: [_member('owner-1', HouseholdRole.owner)],
      currentRole: HouseholdRole.owner,
      mountedDeviceId: 'mounted-android-1',
    );

    expect(installation.humanAccountCount, 1);
    expect(installation.isSinglePerson, isTrue);
    expect(installation.humanAccountIds, isNot(contains('mounted-android-1')));
  });

  test('robot accepts up to seven unique human accounts', () {
    final installation = RobotInstallation(
      id: 'robot-1',
      displayName: 'Kitchen Dosey',
      ownerAccountId: 'owner-1',
      members: [
        _member('owner-1', HouseholdRole.owner),
        for (var index = 2; index <= 7; index += 1)
          _member('member-$index', HouseholdRole.member),
      ],
      currentRole: HouseholdRole.member,
      mountedDeviceId: null,
    );

    expect(installation.humanAccountCount, RobotInstallation.maxHumanAccounts);
    expect(installation.isSinglePerson, isFalse);
  });

  test('robot rejects an eighth human account', () {
    expect(
      () => RobotInstallation(
        id: 'robot-1',
        displayName: 'Kitchen Dosey',
        ownerAccountId: 'owner-1',
        members: [
          _member('owner-1', HouseholdRole.owner),
          for (var index = 2; index <= 8; index += 1)
            _member('member-$index', HouseholdRole.member),
        ],
        currentRole: HouseholdRole.owner,
        mountedDeviceId: 'mounted-android-1',
      ),
      throwsArgumentError,
    );
  });

  test('robot requires its owner in the human membership set', () {
    expect(
      () => RobotInstallation(
        id: 'robot-1',
        displayName: 'Kitchen Dosey',
        ownerAccountId: 'owner-1',
        members: [_member('member-2', HouseholdRole.member)],
        currentRole: HouseholdRole.member,
        mountedDeviceId: 'mounted-android-1',
      ),
      throwsArgumentError,
    );
  });

  test('robot rejects an owner role assigned to another member', () {
    expect(
      () => RobotInstallation(
        id: 'robot-1',
        displayName: 'Kitchen Dosey',
        ownerAccountId: 'owner-1',
        members: [
          _member('owner-1', HouseholdRole.owner),
          _member('member-2', HouseholdRole.owner),
        ],
        currentRole: HouseholdRole.owner,
        mountedDeviceId: null,
      ),
      throwsArgumentError,
    );
  });

  test('robot identity cannot also be a human account', () {
    expect(
      () => RobotInstallation(
        id: 'robot-1',
        displayName: 'Kitchen Dosey',
        ownerAccountId: 'owner-1',
        members: [
          _member('owner-1', HouseholdRole.owner),
          _member('mounted-android-1', HouseholdRole.member),
        ],
        currentRole: HouseholdRole.owner,
        mountedDeviceId: 'mounted-android-1',
      ),
      throwsArgumentError,
    );
  });
}

HouseholdMember _member(String accountId, HouseholdRole role) =>
    HouseholdMember(accountId: accountId, label: accountId, role: role);
