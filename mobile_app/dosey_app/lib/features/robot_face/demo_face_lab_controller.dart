import 'dart:async';

import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';

enum DemoFacePreview {
  idle,
  sleepy,
  doseApproaching,
  doseReady,
  dispensing,
  waitingForConfirmation,
  happyConfirmed,
  missed,
  disconnected,
  connecting,
  verifying,
  online,
  offline,
  reconnecting,
  bluetoothUnavailable,
  fault,
}

enum DemoFaceVoiceResult { completed, interrupted, failed }

enum DemoFaceAnimationResult { playing, completed, interrupted }

class DemoFaceTourStep {
  const DemoFaceTourStep({
    required this.label,
    required this.face,
    required this.cue,
  });

  final String label;
  final DemoFacePreview face;
  final RobotFaceAnimationCue cue;
}

const demoFaceTourSteps = <DemoFaceTourStep>[
  DemoFaceTourStep(
    label: 'Wake up',
    face: DemoFacePreview.idle,
    cue: RobotFaceAnimationCue.wake,
  ),
  DemoFaceTourStep(
    label: 'Notice dose',
    face: DemoFacePreview.doseApproaching,
    cue: RobotFaceAnimationCue.notice,
  ),
  DemoFaceTourStep(
    label: 'Focus',
    face: DemoFacePreview.doseReady,
    cue: RobotFaceAnimationCue.focus,
  ),
  DemoFaceTourStep(
    label: 'Track dispense',
    face: DemoFacePreview.dispensing,
    cue: RobotFaceAnimationCue.track,
  ),
  DemoFaceTourStep(
    label: 'Celebrate',
    face: DemoFacePreview.happyConfirmed,
    cue: RobotFaceAnimationCue.celebrate,
  ),
  DemoFaceTourStep(
    label: 'Show concern',
    face: DemoFacePreview.missed,
    cue: RobotFaceAnimationCue.concern,
  ),
  DemoFaceTourStep(
    label: 'Search',
    face: DemoFacePreview.reconnecting,
    cue: RobotFaceAnimationCue.track,
  ),
  DemoFaceTourStep(
    label: 'Recover',
    face: DemoFacePreview.online,
    cue: RobotFaceAnimationCue.recover,
  ),
];

extension DemoFacePreviewPresentation on DemoFacePreview {
  String get label {
    return switch (this) {
      DemoFacePreview.idle => 'Idle',
      DemoFacePreview.sleepy => 'Sleepy',
      DemoFacePreview.doseApproaching => 'Dose approaching',
      DemoFacePreview.doseReady => 'Dose ready',
      DemoFacePreview.dispensing => 'Dispensing',
      DemoFacePreview.waitingForConfirmation => 'Waiting for confirmation',
      DemoFacePreview.happyConfirmed => 'Dose confirmed',
      DemoFacePreview.missed => 'Dose missed',
      DemoFacePreview.disconnected => 'Controller disconnected',
      DemoFacePreview.connecting => 'Controller connecting',
      DemoFacePreview.verifying => 'Controller verifying',
      DemoFacePreview.online => 'Controller online',
      DemoFacePreview.offline => 'Controller offline',
      DemoFacePreview.reconnecting => 'Controller reconnecting',
      DemoFacePreview.bluetoothUnavailable => 'Bluetooth unavailable',
      DemoFacePreview.fault => 'Controller fault',
    };
  }

  bool get isControllerCondition => index >= DemoFacePreview.disconnected.index;
}

class DemoFaceLabState {
  const DemoFaceLabState({
    this.isExpanded = false,
    this.face,
    this.voicePhase,
    this.voiceResult,
    this.animationCue,
    this.animationRevision = 0,
    this.animationResult,
    this.tourIndex,
    this.internetOffline = false,
    this.reducedMotion = false,
  });

  final bool isExpanded;
  final DemoFacePreview? face;
  final VoicePlaybackPhase? voicePhase;
  final DemoFaceVoiceResult? voiceResult;
  final RobotFaceAnimationCue? animationCue;
  final int animationRevision;
  final DemoFaceAnimationResult? animationResult;
  final int? tourIndex;
  final bool internetOffline;
  final bool reducedMotion;

  bool get isPreviewing =>
      face != null ||
      voicePhase != null ||
      voiceResult != null ||
      animationCue != null ||
      animationResult != null ||
      tourIndex != null ||
      internetOffline ||
      reducedMotion;

  RobotFaceState previewStateFor(RobotFaceState liveState) {
    final selectedFace = face;
    if (!isPreviewing) return liveState;

    final presentation = selectedFace == null
        ? null
        : _presentationFor(selectedFace);
    return liveState.copyWith(
      mode: presentation?.mode,
      statusLabel: presentation?.statusLabel,
      controllerCondition: presentation?.controllerCondition,
      networkAdvisory: internetOffline
          ? RobotFaceNetworkAdvisory.internetOffline
          : null,
      actionDoseId: null,
      voiceOccurrenceKey: null,
      isAwaitingControllerConfirmation: false,
      availableActions: const <RobotFaceActionKind>{},
      hasPinnedShortageAlert: false,
      activeShortageLabel: null,
      activeShortageMedicationLabel: null,
      activeShortageScheduledLabel: null,
      activeShortageSlotNumber: null,
    );
  }
}

class DemoFaceLabController {
  DemoFaceLabState _state = const DemoFaceLabState();
  final StreamController<DemoFaceLabState> _states =
      StreamController<DemoFaceLabState>.broadcast();

  DemoFaceLabState get state => _state;
  Stream<DemoFaceLabState> get states => _states.stream;

  void open() => _emit(_copyWith(isExpanded: true));

  void closePanel() {
    _emit(const DemoFaceLabState());
  }

  void selectFace(DemoFacePreview face) {
    _emit(
      _copyWith(
        face: face,
        animationRevision: _state.animationRevision + 1,
        clearVoiceResult: true,
        clearAnimationCue: true,
        clearAnimationResult: true,
        clearTourIndex: true,
      ),
    );
  }

  void previewVoicePreparing() {
    _emit(
      _copyWith(
        voicePhase: VoicePlaybackPhase.preparing,
        clearVoiceResult: true,
      ),
    );
  }

  void previewVoiceSpeaking() {
    _emit(
      _copyWith(
        voicePhase: VoicePlaybackPhase.speaking,
        clearVoiceResult: true,
      ),
    );
  }

  void completeVoice() => _finishVoice(DemoFaceVoiceResult.completed);

  void interruptVoice() => _finishVoice(DemoFaceVoiceResult.interrupted);

  void failVoice() => _finishVoice(DemoFaceVoiceResult.failed);

  void previewAnimation(RobotFaceAnimationCue cue) {
    _emit(
      _copyWith(
        animationCue: cue,
        animationRevision: _state.animationRevision + 1,
        animationResult: DemoFaceAnimationResult.playing,
        clearTourIndex: true,
      ),
    );
  }

  void completeAnimation(RobotFaceAnimationCue cue, int revision) {
    if (_state.animationCue != cue ||
        _state.animationRevision != revision ||
        _state.animationResult != DemoFaceAnimationResult.playing) {
      return;
    }
    _emit(_copyWith(animationResult: DemoFaceAnimationResult.completed));
  }

  void interruptAnimation() {
    _emit(
      _copyWith(
        animationRevision: _state.animationRevision + 1,
        animationResult: DemoFaceAnimationResult.interrupted,
        clearAnimationCue: true,
      ),
    );
  }

  void nextTourStep() {
    final nextIndex = ((_state.tourIndex ?? -1) + 1) % demoFaceTourSteps.length;
    _showTourStep(nextIndex);
  }

  void previousTourStep() {
    final previousIndex =
        ((_state.tourIndex ?? 1) - 1) % demoFaceTourSteps.length;
    _showTourStep(previousIndex);
  }

  void setInternetOffline(bool value) {
    _emit(_copyWith(internetOffline: value));
  }

  void setReducedMotion(bool value) {
    _emit(_copyWith(reducedMotion: value));
  }

  void reset() {
    _emit(DemoFaceLabState(isExpanded: _state.isExpanded));
  }

  Future<void> close() => _states.close();

  void _finishVoice(DemoFaceVoiceResult result) {
    _emit(_copyWith(voicePhase: VoicePlaybackPhase.idle, voiceResult: result));
  }

  DemoFaceLabState _copyWith({
    bool? isExpanded,
    DemoFacePreview? face,
    VoicePlaybackPhase? voicePhase,
    DemoFaceVoiceResult? voiceResult,
    RobotFaceAnimationCue? animationCue,
    int? animationRevision,
    DemoFaceAnimationResult? animationResult,
    int? tourIndex,
    bool? internetOffline,
    bool? reducedMotion,
    bool clearVoiceResult = false,
    bool clearAnimationCue = false,
    bool clearAnimationResult = false,
    bool clearTourIndex = false,
  }) {
    return DemoFaceLabState(
      isExpanded: isExpanded ?? _state.isExpanded,
      face: face ?? _state.face,
      voicePhase: voicePhase ?? _state.voicePhase,
      voiceResult: clearVoiceResult ? null : voiceResult ?? _state.voiceResult,
      animationCue: clearAnimationCue
          ? null
          : animationCue ?? _state.animationCue,
      animationRevision: animationRevision ?? _state.animationRevision,
      animationResult: clearAnimationResult
          ? null
          : animationResult ?? _state.animationResult,
      tourIndex: clearTourIndex ? null : tourIndex ?? _state.tourIndex,
      internetOffline: internetOffline ?? _state.internetOffline,
      reducedMotion: reducedMotion ?? _state.reducedMotion,
    );
  }

  void _emit(DemoFaceLabState state) {
    _state = state;
    _states.add(state);
  }

  void _showTourStep(int index) {
    final step = demoFaceTourSteps[index];
    _emit(
      _copyWith(
        face: step.face,
        animationCue: step.cue,
        animationRevision: _state.animationRevision + 1,
        animationResult: DemoFaceAnimationResult.playing,
        tourIndex: index,
        clearVoiceResult: true,
      ),
    );
  }
}

({
  RobotFaceMode mode,
  RobotFaceControllerCondition? controllerCondition,
  String statusLabel,
})
_presentationFor(DemoFacePreview preview) {
  return switch (preview) {
    DemoFacePreview.idle => (
      mode: RobotFaceMode.idle,
      controllerCondition: null,
      statusLabel: 'Robot ready',
    ),
    DemoFacePreview.sleepy => (
      mode: RobotFaceMode.sleepy,
      controllerCondition: null,
      statusLabel: 'Resting between reminders',
    ),
    DemoFacePreview.doseApproaching => (
      mode: RobotFaceMode.doseApproaching,
      controllerCondition: null,
      statusLabel: 'Dose coming up',
    ),
    DemoFacePreview.doseReady => (
      mode: RobotFaceMode.doseReady,
      controllerCondition: null,
      statusLabel: 'Ready to dispense',
    ),
    DemoFacePreview.dispensing => (
      mode: RobotFaceMode.dispensing,
      controllerCondition: null,
      statusLabel: 'Dispense command in progress',
    ),
    DemoFacePreview.waitingForConfirmation => (
      mode: RobotFaceMode.waitingForConfirmation,
      controllerCondition: null,
      statusLabel: 'Waiting for confirmation',
    ),
    DemoFacePreview.happyConfirmed => (
      mode: RobotFaceMode.happyConfirmed,
      controllerCondition: null,
      statusLabel: 'Dose confirmed taken',
    ),
    DemoFacePreview.missed => (
      mode: RobotFaceMode.missed,
      controllerCondition: null,
      statusLabel: 'Dose missed',
    ),
    DemoFacePreview.disconnected => (
      mode: RobotFaceMode.offline,
      controllerCondition: RobotFaceControllerCondition.disconnected,
      statusLabel: 'Controller disconnected',
    ),
    DemoFacePreview.connecting => (
      mode: RobotFaceMode.offline,
      controllerCondition: RobotFaceControllerCondition.connecting,
      statusLabel: 'Connecting to controller',
    ),
    DemoFacePreview.verifying => (
      mode: RobotFaceMode.offline,
      controllerCondition: RobotFaceControllerCondition.verifying,
      statusLabel: 'Verifying controller heartbeat',
    ),
    DemoFacePreview.online => (
      mode: RobotFaceMode.idle,
      controllerCondition: RobotFaceControllerCondition.online,
      statusLabel: 'Controller online',
    ),
    DemoFacePreview.offline => (
      mode: RobotFaceMode.offline,
      controllerCondition: RobotFaceControllerCondition.offline,
      statusLabel: 'Controller offline',
    ),
    DemoFacePreview.reconnecting => (
      mode: RobotFaceMode.offline,
      controllerCondition: RobotFaceControllerCondition.reconnecting,
      statusLabel: 'Reconnecting to controller',
    ),
    DemoFacePreview.bluetoothUnavailable => (
      mode: RobotFaceMode.error,
      controllerCondition: RobotFaceControllerCondition.bluetoothUnavailable,
      statusLabel: 'Bluetooth is unavailable',
    ),
    DemoFacePreview.fault => (
      mode: RobotFaceMode.error,
      controllerCondition: RobotFaceControllerCondition.fault,
      statusLabel: 'Controller fault requires attention',
    ),
  };
}
