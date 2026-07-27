import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/shell/robot_face_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const controller = RobotFaceShellController();

  RobotFaceShellDecision decide({
    AppDeviceRole role = AppDeviceRole.androidRobot,
    RobotFaceShellEvent event = RobotFaceShellEvent.launch,
    RobotFaceShellDestination current = RobotFaceShellDestination.dashboard,
    RobotFaceShellOrientation orientation = RobotFaceShellOrientation.landscape,
    RobotFaceShellOrientation? previousOrientation,
    bool shellRouteCurrent = true,
    bool nestedRouteVisible = false,
    bool lifecycleResumed = true,
    bool authoritativeNavigationPending = false,
    bool externalActionReturnPending = false,
    RobotFaceShellDestination? deliberateDestination,
  }) {
    return controller.decide(
      RobotFaceShellInput(
        role: role,
        event: event,
        currentDestination: current,
        orientation: orientation,
        previousOrientation: previousOrientation,
        shellRouteCurrent: shellRouteCurrent,
        nestedRouteVisible: nestedRouteVisible,
        lifecycleResumed: lifecycleResumed,
        authoritativeNavigationPending: authoritativeNavigationPending,
        externalActionReturnPending: externalActionReturnPending,
        deliberateDestination: deliberateDestination,
      ),
    );
  }

  test('Personal role never selects Robot Face', () {
    for (final event in RobotFaceShellEvent.values) {
      expect(
        decide(
          role: AppDeviceRole.androidPersonal,
          event: event,
          current: RobotFaceShellDestination.robotFace,
          previousOrientation: RobotFaceShellOrientation.portrait,
          deliberateDestination: RobotFaceShellDestination.robotFace,
        ).destination,
        isNot(RobotFaceShellDestination.robotFace),
      );
    }
  });

  test('Robot launch and resume select Face only in eligible landscape', () {
    for (final event in [
      RobotFaceShellEvent.launch,
      RobotFaceShellEvent.resume,
    ]) {
      expect(
        decide(event: event).destination,
        RobotFaceShellDestination.robotFace,
      );
      expect(
        decide(
          event: event,
          orientation: RobotFaceShellOrientation.portrait,
        ).destination,
        RobotFaceShellDestination.dashboard,
      );
      expect(
        decide(event: event, shellRouteCurrent: false).destination,
        isNull,
      );
      expect(
        decide(event: event, nestedRouteVisible: true).destination,
        isNull,
      );
      expect(decide(event: event, lifecycleResumed: false).destination, isNull);
    }
  });

  test(
    'authoritative navigation and external returns win launch or resume',
    () {
      for (final event in [
        RobotFaceShellEvent.launch,
        RobotFaceShellEvent.resume,
      ]) {
        expect(
          decide(
            event: event,
            authoritativeNavigationPending: true,
          ).destination,
          isNull,
        );
        expect(
          decide(event: event, externalActionReturnPending: true).destination,
          isNull,
        );
      }
    },
  );

  test('long press exits Face and deliberate navigation is preserved', () {
    expect(
      decide(
        event: RobotFaceShellEvent.longPressExit,
        current: RobotFaceShellDestination.robotFace,
      ).destination,
      RobotFaceShellDestination.dashboard,
    );
    expect(
      decide(
        event: RobotFaceShellEvent.deliberateNavigation,
        current: RobotFaceShellDestination.robotFace,
        deliberateDestination: RobotFaceShellDestination.settings,
      ).destination,
      RobotFaceShellDestination.settings,
    );
  });

  test('portrait exits Face even when authoritative navigation is pending', () {
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        current: RobotFaceShellDestination.robotFace,
        orientation: RobotFaceShellOrientation.portrait,
        previousOrientation: RobotFaceShellOrientation.landscape,
        authoritativeNavigationPending: true,
      ).destination,
      isNull,
    );
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        current: RobotFaceShellDestination.robotFace,
        orientation: RobotFaceShellOrientation.portrait,
        previousOrientation: RobotFaceShellOrientation.landscape,
      ).destination,
      RobotFaceShellDestination.dashboard,
    );
  });

  test('portrait-to-landscape edge reopens Face only from Dashboard', () {
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        previousOrientation: RobotFaceShellOrientation.portrait,
      ).destination,
      RobotFaceShellDestination.robotFace,
    );

    for (final destination in [
      RobotFaceShellDestination.schedule,
      RobotFaceShellDestination.carousel,
      RobotFaceShellDestination.settings,
      RobotFaceShellDestination.todayDetails,
    ]) {
      expect(
        decide(
          event: RobotFaceShellEvent.orientationChanged,
          current: destination,
          previousOrientation: RobotFaceShellOrientation.portrait,
        ).destination,
        isNull,
      );
    }
  });

  test('landscape level never reopens Face after a Dashboard exit', () {
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        previousOrientation: RobotFaceShellOrientation.landscape,
      ).destination,
      isNull,
    );
    expect(
      decide(event: RobotFaceShellEvent.orientationChanged).destination,
      isNull,
    );
  });

  test('orientation does not interrupt nested or hidden shell routes', () {
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        previousOrientation: RobotFaceShellOrientation.portrait,
        nestedRouteVisible: true,
      ).destination,
      isNull,
    );
    expect(
      decide(
        event: RobotFaceShellEvent.orientationChanged,
        previousOrientation: RobotFaceShellOrientation.portrait,
        shellRouteCurrent: false,
      ).destination,
      isNull,
    );
  });
}
