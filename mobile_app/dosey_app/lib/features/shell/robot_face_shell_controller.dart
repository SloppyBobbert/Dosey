import 'package:dosey_app/core/settings/device_role.dart';

enum RobotFaceShellDestination {
  dashboard,
  schedule,
  carousel,
  settings,
  robotFace,
  todayDetails,
}

enum RobotFaceShellOrientation { portrait, landscape }

enum RobotFaceShellEvent {
  launch,
  resume,
  orientationChanged,
  longPressExit,
  deliberateNavigation,
}

class RobotFaceShellInput {
  const RobotFaceShellInput({
    required this.role,
    required this.event,
    required this.currentDestination,
    required this.orientation,
    this.previousOrientation,
    required this.shellRouteCurrent,
    required this.nestedRouteVisible,
    required this.lifecycleResumed,
    required this.authoritativeNavigationPending,
    required this.externalActionReturnPending,
    this.deliberateDestination,
  });

  final AppDeviceRole role;
  final RobotFaceShellEvent event;
  final RobotFaceShellDestination currentDestination;
  final RobotFaceShellOrientation orientation;
  final RobotFaceShellOrientation? previousOrientation;
  final bool shellRouteCurrent;
  final bool nestedRouteVisible;
  final bool lifecycleResumed;
  final bool authoritativeNavigationPending;
  final bool externalActionReturnPending;
  final RobotFaceShellDestination? deliberateDestination;
}

class RobotFaceShellDecision {
  const RobotFaceShellDecision.preserve() : destination = null;

  const RobotFaceShellDecision.select(this.destination);

  final RobotFaceShellDestination? destination;
}

class RobotFaceShellController {
  const RobotFaceShellController();

  RobotFaceShellDecision decide(RobotFaceShellInput input) {
    if (!input.role.canHostRobot) {
      return input.currentDestination == RobotFaceShellDestination.robotFace
          ? const RobotFaceShellDecision.select(
              RobotFaceShellDestination.dashboard,
            )
          : const RobotFaceShellDecision.preserve();
    }

    if (input.authoritativeNavigationPending ||
        input.externalActionReturnPending) {
      return const RobotFaceShellDecision.preserve();
    }

    if (input.event == RobotFaceShellEvent.orientationChanged &&
        input.currentDestination == RobotFaceShellDestination.robotFace &&
        input.orientation == RobotFaceShellOrientation.portrait) {
      return const RobotFaceShellDecision.select(
        RobotFaceShellDestination.dashboard,
      );
    }

    if (input.event == RobotFaceShellEvent.longPressExit) {
      return const RobotFaceShellDecision.select(
        RobotFaceShellDestination.dashboard,
      );
    }

    if (input.event == RobotFaceShellEvent.deliberateNavigation) {
      final destination = input.deliberateDestination;
      if (destination == null) {
        return const RobotFaceShellDecision.preserve();
      }
      return RobotFaceShellDecision.select(destination);
    }

    if (!input.lifecycleResumed ||
        !input.shellRouteCurrent ||
        input.nestedRouteVisible) {
      return const RobotFaceShellDecision.preserve();
    }

    if (input.event == RobotFaceShellEvent.launch ||
        input.event == RobotFaceShellEvent.resume) {
      return RobotFaceShellDecision.select(
        input.orientation == RobotFaceShellOrientation.landscape
            ? RobotFaceShellDestination.robotFace
            : RobotFaceShellDestination.dashboard,
      );
    }

    final isPortraitToLandscape =
        input.event == RobotFaceShellEvent.orientationChanged &&
        input.previousOrientation == RobotFaceShellOrientation.portrait &&
        input.orientation == RobotFaceShellOrientation.landscape;
    if (isPortraitToLandscape &&
        input.currentDestination == RobotFaceShellDestination.dashboard) {
      return const RobotFaceShellDecision.select(
        RobotFaceShellDestination.robotFace,
      );
    }

    return const RobotFaceShellDecision.preserve();
  }
}
