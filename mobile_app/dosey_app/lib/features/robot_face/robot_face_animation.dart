import 'package:dosey_app/features/robot_face/robot_face_state.dart';

enum RobotFaceAnimationCue {
  wake,
  acknowledge,
  notice,
  focus,
  track,
  celebrate,
  concern,
  recover,
}

extension RobotFaceAnimationCuePresentation on RobotFaceAnimationCue {
  String get label => switch (this) {
    RobotFaceAnimationCue.wake => 'Wake',
    RobotFaceAnimationCue.acknowledge => 'Acknowledge',
    RobotFaceAnimationCue.notice => 'Notice',
    RobotFaceAnimationCue.focus => 'Focus',
    RobotFaceAnimationCue.track => 'Track',
    RobotFaceAnimationCue.celebrate => 'Celebrate',
    RobotFaceAnimationCue.concern => 'Concern',
    RobotFaceAnimationCue.recover => 'Recover',
  };
}

RobotFaceAnimationCue safeRobotFaceAnimationCue(
  RobotFaceAnimationCue cue,
  RobotFaceState state,
) {
  if (state.mode == RobotFaceMode.missed || state.mode == RobotFaceMode.error) {
    return RobotFaceAnimationCue.concern;
  }
  return cue;
}

RobotFaceAnimationCue? robotFaceTransitionCue(
  RobotFaceState previous,
  RobotFaceState current,
) {
  if (previous.mode == current.mode &&
      previous.controllerCondition == current.controllerCondition) {
    return null;
  }

  if (current.mode == RobotFaceMode.missed ||
      current.mode == RobotFaceMode.error) {
    return RobotFaceAnimationCue.concern;
  }
  if (previous.mode == RobotFaceMode.sleepy &&
      current.mode == RobotFaceMode.idle) {
    return RobotFaceAnimationCue.wake;
  }

  final workflowCue = switch (current.mode) {
    RobotFaceMode.doseApproaching => RobotFaceAnimationCue.notice,
    RobotFaceMode.doseReady => RobotFaceAnimationCue.focus,
    RobotFaceMode.dispensing => RobotFaceAnimationCue.track,
    RobotFaceMode.happyConfirmed => RobotFaceAnimationCue.celebrate,
    _ => null,
  };
  if (workflowCue != null) return workflowCue;

  final condition = current.controllerCondition;
  if (condition == RobotFaceControllerCondition.connecting ||
      condition == RobotFaceControllerCondition.reconnecting) {
    return RobotFaceAnimationCue.track;
  }
  if (condition == RobotFaceControllerCondition.verifying) {
    return RobotFaceAnimationCue.focus;
  }
  if (condition == RobotFaceControllerCondition.online &&
      previous.controllerCondition != RobotFaceControllerCondition.online) {
    return RobotFaceAnimationCue.recover;
  }

  return null;
}
