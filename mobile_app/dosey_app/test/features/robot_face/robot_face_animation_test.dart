import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RobotFaceState state(
    RobotFaceMode mode, {
    RobotFaceControllerCondition? condition,
  }) => RobotFaceState(
    mode: mode,
    controllerCondition: condition,
    nextEventLabel: 'No reminders scheduled',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 0,
    isInAwakeWindow: true,
  );

  test('workflow entries map to their presentation-only cues', () {
    final idle = state(RobotFaceMode.idle);

    expect(
      robotFaceTransitionCue(idle, state(RobotFaceMode.doseApproaching)),
      RobotFaceAnimationCue.notice,
    );
    expect(
      robotFaceTransitionCue(idle, state(RobotFaceMode.doseReady)),
      RobotFaceAnimationCue.focus,
    );
    expect(
      robotFaceTransitionCue(idle, state(RobotFaceMode.dispensing)),
      RobotFaceAnimationCue.track,
    );
    expect(
      robotFaceTransitionCue(idle, state(RobotFaceMode.happyConfirmed)),
      RobotFaceAnimationCue.celebrate,
    );
    expect(
      robotFaceTransitionCue(idle, state(RobotFaceMode.missed)),
      RobotFaceAnimationCue.concern,
    );
  });

  test('controller entries map to focus, tracking, recovery, and concern', () {
    final disconnected = state(
      RobotFaceMode.offline,
      condition: RobotFaceControllerCondition.disconnected,
    );

    expect(
      robotFaceTransitionCue(
        disconnected,
        state(
          RobotFaceMode.offline,
          condition: RobotFaceControllerCondition.connecting,
        ),
      ),
      RobotFaceAnimationCue.track,
    );
    expect(
      robotFaceTransitionCue(
        disconnected,
        state(
          RobotFaceMode.offline,
          condition: RobotFaceControllerCondition.verifying,
        ),
      ),
      RobotFaceAnimationCue.focus,
    );
    expect(
      robotFaceTransitionCue(
        disconnected,
        state(
          RobotFaceMode.idle,
          condition: RobotFaceControllerCondition.online,
        ),
      ),
      RobotFaceAnimationCue.recover,
    );
    expect(
      robotFaceTransitionCue(
        disconnected,
        state(
          RobotFaceMode.error,
          condition: RobotFaceControllerCondition.fault,
        ),
      ),
      RobotFaceAnimationCue.concern,
    );
  });

  test(
    'active dose workflow cues outrank simultaneous controller recovery',
    () {
      final reconnecting = state(
        RobotFaceMode.offline,
        condition: RobotFaceControllerCondition.reconnecting,
      );

      expect(
        robotFaceTransitionCue(
          reconnecting,
          state(
            RobotFaceMode.doseReady,
            condition: RobotFaceControllerCondition.online,
          ),
        ),
        RobotFaceAnimationCue.focus,
      );
    },
  );

  test('waking from sleepy maps to wake and unchanged state has no cue', () {
    final sleepy = state(RobotFaceMode.sleepy);
    final idle = state(RobotFaceMode.idle);

    expect(robotFaceTransitionCue(sleepy, idle), RobotFaceAnimationCue.wake);
    expect(robotFaceTransitionCue(idle, idle), isNull);
  });

  test('missed and error faces sanitize every cue to concern', () {
    for (final mode in <RobotFaceMode>[
      RobotFaceMode.missed,
      RobotFaceMode.error,
    ]) {
      for (final cue in RobotFaceAnimationCue.values) {
        expect(
          safeRobotFaceAnimationCue(cue, state(mode)),
          RobotFaceAnimationCue.concern,
        );
      }
    }
  });
}
