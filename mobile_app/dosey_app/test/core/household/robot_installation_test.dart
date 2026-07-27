import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single owner and separate robot identity form a valid robot', () {
    final installation = RobotInstallation(
      id: 'robot-1',
      displayName: 'Kitchen Dosey',
      ownerAccountId: 'owner-1',
      humanAccountIds: {'owner-1'},
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
      humanAccountIds: {
        'owner-1',
        'member-2',
        'member-3',
        'member-4',
        'member-5',
        'member-6',
        'member-7',
      },
      mountedDeviceId: 'mounted-android-1',
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
        humanAccountIds: {
          'owner-1',
          'member-2',
          'member-3',
          'member-4',
          'member-5',
          'member-6',
          'member-7',
          'member-8',
        },
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
        humanAccountIds: {'member-2'},
        mountedDeviceId: 'mounted-android-1',
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
        humanAccountIds: {'owner-1', 'mounted-android-1'},
        mountedDeviceId: 'mounted-android-1',
      ),
      throwsArgumentError,
    );
  });
}
