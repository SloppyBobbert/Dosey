import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/demo_face_lab_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const liveState = RobotFaceState(
    mode: RobotFaceMode.waitingForConfirmation,
    nextEventLabel: 'Now · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    statusLabel: 'Confirm the visible dose',
    actionDoseId: 'dose-1',
    voiceOccurrenceKey: 'voice-1',
    isAwaitingControllerConfirmation: true,
    availableActions: <RobotFaceActionKind>{
      RobotFaceActionKind.confirmTaken,
      RobotFaceActionKind.skipDose,
      RobotFaceActionKind.askForHelp,
    },
  );

  test('face previews are presentation-only and strip live dose actions', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.selectFace(DemoFacePreview.missed);
    final preview = lab.state.previewStateFor(liveState);

    expect(preview.mode, RobotFaceMode.missed);
    expect(preview.actionDoseId, isNull);
    expect(preview.voiceOccurrenceKey, isNull);
    expect(preview.availableActions, isEmpty);
    expect(preview.isAwaitingControllerConfirmation, isFalse);
    expect(liveState.mode, RobotFaceMode.waitingForConfirmation);
    expect(liveState.availableActions, hasLength(3));
  });

  test('controller previews map to the matching presentation condition', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.selectFace(DemoFacePreview.reconnecting);
    final preview = lab.state.previewStateFor(liveState);

    expect(preview.mode, RobotFaceMode.offline);
    expect(
      preview.controllerCondition,
      RobotFaceControllerCondition.reconnecting,
    );
    expect(preview.statusLabel, 'Reconnecting to controller');
  });

  test('voice controls expose deterministic completion and failure states', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.previewVoicePreparing();
    expect(lab.state.voicePhase, VoicePlaybackPhase.preparing);
    expect(lab.state.voiceResult, isNull);

    lab.previewVoiceSpeaking();
    expect(lab.state.voicePhase, VoicePlaybackPhase.speaking);

    lab.completeVoice();
    expect(lab.state.voicePhase, VoicePlaybackPhase.idle);
    expect(lab.state.voiceResult, DemoFaceVoiceResult.completed);

    lab.failVoice();
    expect(lab.state.voicePhase, VoicePlaybackPhase.idle);
    expect(lab.state.voiceResult, DemoFaceVoiceResult.failed);
  });

  test('closing the panel resets every preview override', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.open();
    lab.selectFace(DemoFacePreview.fault);
    lab.previewVoiceSpeaking();
    lab.setInternetOffline(true);
    lab.setReducedMotion(true);

    lab.closePanel();

    expect(lab.state.isExpanded, isFalse);
    expect(lab.state.isPreviewing, isFalse);
    expect(lab.state.face, isNull);
    expect(lab.state.voicePhase, isNull);
    expect(lab.state.internetOffline, isFalse);
    expect(lab.state.reducedMotion, isFalse);
  });

  test('animation cues can be replayed and interrupted deterministically', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.previewAnimation(RobotFaceAnimationCue.focus);
    final firstRevision = lab.state.animationRevision;

    expect(lab.state.animationCue, RobotFaceAnimationCue.focus);
    expect(lab.state.animationResult, DemoFaceAnimationResult.playing);

    lab.previewAnimation(RobotFaceAnimationCue.focus);
    expect(lab.state.animationRevision, firstRevision + 1);

    lab.interruptAnimation();
    expect(lab.state.animationCue, isNull);
    expect(lab.state.animationResult, DemoFaceAnimationResult.interrupted);
  });

  test('cue-only previews strip live actions without changing live state', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.previewAnimation(RobotFaceAnimationCue.acknowledge);
    final preview = lab.state.previewStateFor(liveState);

    expect(preview.actionDoseId, isNull);
    expect(preview.availableActions, isEmpty);
    expect(preview.isAwaitingControllerConfirmation, isFalse);
    expect(liveState.actionDoseId, 'dose-1');
    expect(liveState.availableActions, hasLength(3));
  });

  test('manual face selection exits and interrupts an active tour', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.nextTourStep();
    lab.selectFace(DemoFacePreview.verifying);

    expect(lab.state.face, DemoFacePreview.verifying);
    expect(lab.state.tourIndex, isNull);
    expect(lab.state.animationCue, isNull);
    expect(lab.state.animationResult, isNull);
  });

  test('manual tour steps through curated face and animation pairs', () {
    final lab = DemoFaceLabController();
    addTearDown(lab.close);

    lab.nextTourStep();
    expect(lab.state.tourIndex, 0);
    expect(lab.state.face, DemoFacePreview.idle);
    expect(lab.state.animationCue, RobotFaceAnimationCue.wake);

    lab.nextTourStep();
    expect(lab.state.tourIndex, 1);
    expect(lab.state.face, DemoFacePreview.doseApproaching);
    expect(lab.state.animationCue, RobotFaceAnimationCue.notice);

    lab.previousTourStep();
    expect(lab.state.tourIndex, 0);
    expect(lab.state.face, DemoFacePreview.idle);
    expect(lab.state.animationCue, RobotFaceAnimationCue.wake);
  });
}
