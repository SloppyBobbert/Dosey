import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/doses/dose_action_logger.dart';
import 'package:dosey_app/features/robot_face/demo_face_lab_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/robot_face/robot_face_voice_coordinator.dart';
import 'package:flutter/material.dart';

typedef RobotFaceDoseActionLogger =
    Future<bool> Function(
      BuildContext context,
      DoseLogEvent event,
      String successMessage,
    );

typedef RobotFaceVisibleAndTakenLogger =
    Future<bool> Function(
      BuildContext context, {
      required String doseId,
      required DateTime occurredAt,
      required String successMessage,
    });

typedef RobotFaceActionAuthorizer = Future<bool> Function(BuildContext context);

class RobotFaceScreen extends StatefulWidget {
  const RobotFaceScreen({
    super.key,
    this.controller,
    this.controllerResolver,
    this.stateStream,
    this.initialState,
    this.isActive = true,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
    this.onLongPress,
  });

  static const canvasKey = ValueKey<String>('robot-face-canvas');
  static const bottomCardKey = ValueKey<String>('robot-face-bottom-card');
  static const displayFrameKey = ValueKey<String>('robot-face-display-frame');
  static const flipTransformKey = ValueKey<String>('robot-face-flip-transform');
  static const urgentPromptKey = ValueKey<String>('robot-face-urgent-prompt');
  static const urgentPromptSurfaceKey = ValueKey<String>(
    'robot-face-urgent-prompt-surface',
  );
  static const urgentPromptScaleKey = ValueKey<String>(
    'robot-face-urgent-prompt-scale',
  );
  static const statusBadgeKey = ValueKey<String>('robot-face-status-badge');
  static const exitButtonKey = ValueKey<String>('robot-face-exit-button');
  static const networkAdvisoryBadgeKey = ValueKey<String>(
    'robot-face-network-advisory-badge',
  );
  static const faceLabButtonKey = ValueKey<String>('robot-face-lab-button');
  static const faceLabPanelKey = ValueKey<String>('robot-face-lab-panel');
  static const faceLabPreviewMarkerKey = ValueKey<String>(
    'robot-face-lab-preview-marker',
  );
  static const faceLabFaceSelectorKey = ValueKey<String>(
    'robot-face-lab-face-selector',
  );
  static const faceLabVoiceSpeakingKey = ValueKey<String>(
    'robot-face-lab-voice-speaking',
  );
  static const faceLabVoiceInterruptKey = ValueKey<String>(
    'robot-face-lab-voice-interrupt',
  );
  static const faceLabReducedMotionKey = ValueKey<String>(
    'robot-face-lab-reduced-motion',
  );
  static const faceLabResetKey = ValueKey<String>('robot-face-lab-reset');
  static const faceLabAnimationFocusKey = ValueKey<String>(
    'robot-face-lab-animation-focus',
  );
  static const faceLabAnimationInterruptKey = ValueKey<String>(
    'robot-face-lab-animation-interrupt',
  );
  static const faceLabTourPreviousKey = ValueKey<String>(
    'robot-face-lab-tour-previous',
  );
  static const faceLabTourNextKey = ValueKey<String>(
    'robot-face-lab-tour-next',
  );
  static const actionHostKey = ValueKey<String>('robot-face-action-host');
  static const detailRevealKey = ValueKey<String>('robot-face-detail-reveal');
  static const actionPanelKey = ValueKey<String>('robot-face-action-panel');
  static const confirmTakenButtonKey = ValueKey<String>(
    'robot-face-confirm-taken-button',
  );
  static const skipDoseButtonKey = ValueKey<String>(
    'robot-face-skip-dose-button',
  );
  static const needHelpButtonKey = ValueKey<String>(
    'robot-face-need-help-button',
  );
  static const recognizeMissedDoseButtonKey = ValueKey<String>(
    'robot-face-recognize-missed-dose-button',
  );

  final RobotFaceController? controller;
  final RobotFaceController Function(BuildContext context)? controllerResolver;
  final Stream<RobotFaceState>? stateStream;
  final RobotFaceState? initialState;
  final bool isActive;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;
  final RobotFaceActionAuthorizer? actionAuthorizer;
  final VoidCallback? onLongPress;

  @override
  State<RobotFaceScreen> createState() => _RobotFaceScreenState();
}

class _RobotFaceScreenState extends State<RobotFaceScreen>
    with WidgetsBindingObserver {
  static const _fallbackState = RobotFaceState(
    mode: RobotFaceMode.offline,
    nextEventLabel: 'No reminders scheduled',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 0,
    isInAwakeWindow: false,
    statusLabel: 'Robot Face unavailable',
  );

  Stream<RobotFaceState>? _stateStream;
  RobotFaceState? _initialState;
  RobotFaceController? _interactionController;
  RobotFaceVoiceCoordinator? _voiceCoordinator;
  Future<void> _voiceBinding = Future<void>.value();
  int _voiceBindingGeneration = 0;
  late bool _isForeground;
  int _interactionRevision = 0;
  bool _detailsRevealed = false;
  String? _detailIdentity;

  bool get _isVoiceActive => widget.isActive && _isForeground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindStream();
  }

  @override
  void didUpdateWidget(covariant RobotFaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _voiceCoordinator?.setActive(_isVoiceActive);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.controllerResolver != widget.controllerResolver ||
        oldWidget.stateStream != widget.stateStream ||
        oldWidget.initialState != widget.initialState) {
      _bindStream();
    }
  }

  void _bindStream() {
    // Tests can inject a controller, stream, or fixed state. Production falls
    // back to the app-scoped Robot Face controller.
    _interactionController = widget.controller;
    if (_interactionController == null && widget.stateStream == null) {
      _interactionController =
          widget.controllerResolver?.call(context) ??
          DoseyAppScope.maybeOf(context)?.robotFaceController;
    }
    _stateStream = _asBroadcast(
      widget.stateStream ?? widget.controller?.watchState(),
    );
    if (_stateStream == null && widget.initialState == null) {
      _stateStream = _asBroadcast(_interactionController?.watchState());
    }
    _initialState = widget.initialState;
    _bindVoiceCoordinator();
  }

  Stream<RobotFaceState>? _asBroadcast(Stream<RobotFaceState>? stream) {
    if (stream == null || stream.isBroadcast) return stream;
    return stream.asBroadcastStream();
  }

  void _bindVoiceCoordinator() {
    final dependencies = DoseyAppScope.maybeOf(context);
    final stateStream = _stateStream;
    final generation = ++_voiceBindingGeneration;
    _voiceBinding = _voiceBinding.then((_) async {
      final previousCoordinator = _voiceCoordinator;
      _voiceCoordinator = null;
      if (previousCoordinator != null) {
        final cleanup = previousCoordinator.close();
        await previousCoordinator.deactivate();
        unawaited(cleanup);
      }
      if (!mounted || generation != _voiceBindingGeneration) return;
      if (dependencies == null || stateStream == null) return;

      _voiceCoordinator = RobotFaceVoiceCoordinator(
        stateStream: stateStream,
        settingsStream: dependencies.robotFaceSettings.watchSettings(),
        roleStream: dependencies.effectiveRole.watchDeviceRole(),
        voicePlayer: dependencies.voicePlayer,
        isActive: _isVoiceActive,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) return;
    _isForeground = isForeground;
    _voiceCoordinator?.setActive(_isVoiceActive);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceBindingGeneration += 1;
    unawaited(
      _voiceBinding.then((_) async {
        final coordinator = _voiceCoordinator;
        _voiceCoordinator = null;
        await coordinator?.close();
      }),
    );
    super.dispose();
  }

  void _activateFace() {
    _revealDetails();
    if (!widget.isActive) return;
    setState(() {
      _interactionRevision -= 1;
    });
    _interactionController?.recordInteraction();
  }

  void _revealDetails() {
    if (_detailsRevealed) return;
    setState(() => _detailsRevealed = true);
  }

  void _resetDetailsFor(RobotFaceState state) {
    final identity =
        state.actionDoseId != null && state.availableActions.isNotEmpty
        ? 'action:${state.actionDoseId}'
        : 'presentation:${state.voiceOccurrenceKey ?? state.nextEventLabel}:${state.nextEventLabel}';
    if (_detailIdentity == identity) return;
    _detailIdentity = identity;
    _detailsRevealed = false;
  }

  void _completeInteractionAnimation(RobotFaceAnimationCue cue, int revision) {
    if (!mounted || revision >= 0 || revision != _interactionRevision) return;
    setState(() {
      _interactionRevision = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.maybeOf(context);
    final scenarios = dependencies?.demoScenarios;
    final faceLab = dependencies?.demoFaceLab;
    return Scaffold(
      backgroundColor: const Color(0xFF04070D),
      body: StreamBuilder<VoicePlaybackPhase>(
        stream: dependencies?.voicePlayer.phases,
        initialData: dependencies?.voicePlayer.phase ?? VoicePlaybackPhase.idle,
        builder: (context, voiceSnapshot) {
          final voicePhase = widget.isActive
              ? voiceSnapshot.data ?? VoicePlaybackPhase.idle
              : VoicePlaybackPhase.idle;
          return StreamBuilder<RobotFaceState>(
            stream: _stateStream,
            initialData: _initialState ?? _fallbackState,
            builder: (context, snapshot) {
              final liveState = snapshot.data ?? _fallbackState;
              Widget buildFace(DemoFaceLabState labState) {
                final state = labState.previewStateFor(liveState);
                _resetDetailsFor(state);
                final effectiveVoicePhase = labState.voicePhase ?? voicePhase;
                final labControlsAnimation = labState.animationRevision > 0;
                final animationCue = labControlsAnimation
                    ? labState.animationCue
                    : _interactionRevision < 0
                    ? RobotFaceAnimationCue.acknowledge
                    : null;
                final animationRevision = labControlsAnimation
                    ? labState.animationRevision
                    : _interactionRevision;
                Widget content = Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isPortraitFrame =
                            constraints.maxHeight > constraints.maxWidth;
                        final physicalSafePadding = MediaQuery.paddingOf(
                          context,
                        );
                        final rotatedStatusSafePadding = isPortraitFrame
                            ? EdgeInsets.fromLTRB(
                                physicalSafePadding.top,
                                physicalSafePadding.right,
                                physicalSafePadding.bottom,
                                physicalSafePadding.left,
                              )
                            : physicalSafePadding;
                        final statusSafePadding = state.isFlipped
                            ? EdgeInsets.fromLTRB(
                                rotatedStatusSafePadding.right,
                                rotatedStatusSafePadding.bottom,
                                rotatedStatusSafePadding.left,
                                rotatedStatusSafePadding.top,
                              )
                            : rotatedStatusSafePadding;
                        final squarePrompt =
                            (state.mode == RobotFaceMode.doseReady ||
                                state.mode == RobotFaceMode.error) &&
                            (isPortraitFrame ||
                                state.isFlipped ||
                                physicalSafePadding != EdgeInsets.zero ||
                                MediaQuery.textScalerOf(context).scale(1) >=
                                    1.8);
                        Widget frame = _RobotFaceFrame(
                          state: state,
                          isActive: widget.isActive,
                          voicePhase: effectiveVoicePhase,
                          animationCue: animationCue,
                          animationRevision: animationRevision,
                          onAnimationCompleted: labControlsAnimation
                              ? faceLab?.completeAnimation
                              : _completeInteractionAnimation,
                          onInteraction: _activateFace,
                          detailsRevealed: _detailsRevealed,
                          onLongPress: widget.onLongPress,
                          doseActionLogger: widget.doseActionLogger,
                          visibleAndTakenLogger: widget.visibleAndTakenLogger,
                          actionAuthorizer: widget.actionAuthorizer,
                          // Noncompact rotated/flipped text must also clear
                          // the fixed physical exit; the surface stays full-size.
                          statusSafePadding: squarePrompt
                              ? statusSafePadding
                              : statusSafePadding +
                                    (isPortraitFrame
                                        ? (state.isFlipped
                                              ? const EdgeInsets.only(right: 60)
                                              : const EdgeInsets.only(left: 60))
                                        : (state.isFlipped
                                              ? const EdgeInsets.only(
                                                  bottom: 60,
                                                )
                                              : EdgeInsets.zero)),
                          squarePrompt: squarePrompt,
                          isPortrait: isPortraitFrame,
                        );

                        if (isPortraitFrame) {
                          frame = RotatedBox(quarterTurns: 1, child: frame);
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            frame,
                            if (squarePrompt)
                              Positioned(
                                left: physicalSafePadding.left + 8,
                                top: physicalSafePadding.top + 8,
                                width: 64,
                                height: 64,
                                child: _UrgentPromptOverlay(
                                  state: state,
                                  safePadding: EdgeInsets.zero,
                                  isPortrait: isPortraitFrame,
                                  constrained: true,
                                ),
                              ),
                            if (widget.onLongPress != null)
                              if (squarePrompt)
                                // Share the reserved physical badge strip; keep
                                // the exit touch target out of status and eyes.
                                Positioned(
                                  left: isPortraitFrame
                                      ? constraints.maxWidth -
                                            physicalSafePadding.right -
                                            56
                                      : physicalSafePadding.left + 8,
                                  top:
                                      physicalSafePadding.top +
                                      (isPortraitFrame ? 8 : 80),
                                  width: 48,
                                  height: 48,
                                  child: IconButton.outlined(
                                    key: RobotFaceScreen.exitButtonKey,
                                    tooltip: 'Open Today',
                                    onPressed: widget.onLongPress,
                                    style: IconButton.styleFrom(
                                      foregroundColor: const Color(0xFFD5F4FF),
                                      backgroundColor: const Color(0xED102A43),
                                      side: const BorderSide(
                                        color: Color(0x9900A8E8),
                                      ),
                                    ),
                                    icon: RotatedBox(
                                      quarterTurns:
                                          (isPortraitFrame ? 1 : 0) +
                                          (state.isFlipped ? 2 : 0),
                                      child: const Icon(
                                        Icons.arrow_back_rounded,
                                        semanticLabel: 'Open Today',
                                      ),
                                    ),
                                  ),
                                )
                              else
                                _RobotFaceExitButton(
                                  onPressed: widget.onLongPress!,
                                ),
                          ],
                        );
                      },
                    ),
                    if (scenarios != null)
                      _DemoPresenterControls(scenarios: scenarios),
                    if (faceLab != null)
                      _DemoFaceLabControls(
                        controller: faceLab,
                        state: labState,
                      ),
                  ],
                );
                if (labState.reducedMotion) {
                  content = MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: content,
                  );
                }
                return content;
              }

              if (faceLab == null) {
                return buildFace(const DemoFaceLabState());
              }
              return StreamBuilder<DemoFaceLabState>(
                stream: faceLab.states,
                initialData: faceLab.state,
                builder: (context, labSnapshot) {
                  return buildFace(labSnapshot.requireData);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _RobotFaceExitButton extends StatelessWidget {
  const _RobotFaceExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: OutlinedButton.icon(
              key: RobotFaceScreen.exitButtonKey,
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Open Today'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD5F4FF),
                backgroundColor: const Color(0xED102A43),
                side: const BorderSide(color: Color(0x9900A8E8)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoFaceLabControls extends StatelessWidget {
  const _DemoFaceLabControls({required this.controller, required this.state});

  final DemoFaceLabController controller;
  final DemoFaceLabState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          if (state.isPreviewing)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  label: 'Face Lab preview active',
                  child: DecoratedBox(
                    key: RobotFaceScreen.faceLabPreviewMarkerKey,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5B942),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'PREVIEW',
                        style: TextStyle(
                          color: Color(0xFF201500),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: state.isExpanded
                  ? _DemoFaceLabPanel(controller: controller, state: state)
                  : Tooltip(
                      message: 'Open deterministic face preview controls',
                      child: FloatingActionButton.small(
                        key: RobotFaceScreen.faceLabButtonKey,
                        heroTag: 'robot-face-lab',
                        onPressed: controller.open,
                        backgroundColor: const Color(0xFF172334),
                        foregroundColor: const Color(0xFF9DE8FF),
                        child: const Icon(Icons.face_retouching_natural),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoFaceLabPanel extends StatelessWidget {
  const _DemoFaceLabPanel({required this.controller, required this.state});

  final DemoFaceLabController controller;
  final DemoFaceLabState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: RobotFaceScreen.faceLabPanelKey,
      color: const Color(0xF5111824),
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'FACE LAB',
                      style: TextStyle(
                        color: Color(0xFF9DE8FF),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Face Lab and clear preview',
                    onPressed: controller.closePanel,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DemoFacePreview>(
                key: RobotFaceScreen.faceLabFaceSelectorKey,
                initialValue: state.face,
                isExpanded: true,
                dropdownColor: const Color(0xFF172334),
                decoration: const InputDecoration(
                  labelText: 'Face state',
                  border: OutlineInputBorder(),
                ),
                items: DemoFacePreview.values
                    .map(
                      (face) => DropdownMenuItem(
                        value: face,
                        child: Text(face.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (face) {
                  if (face != null) controller.selectFace(face);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Voice lifecycle',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FaceLabAction(
                    label: 'Preparing',
                    onPressed: controller.previewVoicePreparing,
                  ),
                  _FaceLabAction(
                    key: RobotFaceScreen.faceLabVoiceSpeakingKey,
                    label: 'Speaking',
                    onPressed: controller.previewVoiceSpeaking,
                  ),
                  _FaceLabAction(
                    label: 'Complete',
                    onPressed: controller.completeVoice,
                  ),
                  _FaceLabAction(
                    key: RobotFaceScreen.faceLabVoiceInterruptKey,
                    label: 'Interrupt',
                    onPressed: controller.interruptVoice,
                  ),
                  _FaceLabAction(
                    label: 'Playback error',
                    onPressed: controller.failVoice,
                  ),
                ],
              ),
              if (state.voiceResult case final result?) ...[
                const SizedBox(height: 8),
                Text(switch (result) {
                  DemoFaceVoiceResult.completed => 'Voice completed',
                  DemoFaceVoiceResult.interrupted => 'Voice interrupted',
                  DemoFaceVoiceResult.failed => 'Voice playback failed',
                }, style: const TextStyle(color: Color(0xFFF5B942))),
              ],
              const SizedBox(height: 14),
              const Text(
                'Animation cues',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cue in RobotFaceAnimationCue.values)
                    _FaceLabAction(
                      key: cue == RobotFaceAnimationCue.focus
                          ? RobotFaceScreen.faceLabAnimationFocusKey
                          : ValueKey<String>(
                              'robot-face-lab-animation-${cue.name}',
                            ),
                      label: cue.label,
                      onPressed: () => controller.previewAnimation(cue),
                    ),
                  _FaceLabAction(
                    key: RobotFaceScreen.faceLabAnimationInterruptKey,
                    label: 'Interrupt animation',
                    onPressed: controller.interruptAnimation,
                  ),
                ],
              ),
              if (state.animationResult case final result?) ...[
                const SizedBox(height: 8),
                Text(switch (result) {
                  DemoFaceAnimationResult.playing =>
                    'Playing ${state.animationCue?.label ?? 'animation'}',
                  DemoFaceAnimationResult.completed =>
                    '${state.animationCue?.label ?? 'Animation'} complete',
                  DemoFaceAnimationResult.interrupted =>
                    'Animation interrupted',
                }, style: const TextStyle(color: Color(0xFFF5B942))),
              ],
              const SizedBox(height: 14),
              const Text(
                'Animation tour',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (state.tourIndex case final index?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tour ${index + 1} of ${demoFaceTourSteps.length} · '
                    '${demoFaceTourSteps[index].label}',
                    style: const TextStyle(color: Color(0xFF9DE8FF)),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: RobotFaceScreen.faceLabTourPreviousKey,
                      onPressed: controller.previousTourStep,
                      icon: const Icon(Icons.skip_previous),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: RobotFaceScreen.faceLabTourNextKey,
                      onPressed: controller.nextTourStep,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Next'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Internet offline'),
                subtitle: const Text('Local reminders remain available'),
                value: state.internetOffline,
                onChanged: controller.setInternetOffline,
              ),
              SwitchListTile.adaptive(
                key: RobotFaceScreen.faceLabReducedMotionKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduced motion preview'),
                value: state.reducedMotion,
                onChanged: controller.setReducedMotion,
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: RobotFaceScreen.faceLabResetKey,
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset preview'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceLabAction extends StatelessWidget {
  const _FaceLabAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _DemoPresenterControls extends StatelessWidget {
  const _DemoPresenterControls({required this.scenarios});

  final DemoScenarioService scenarios;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DemoScenarioState>(
      stream: scenarios.states,
      initialData: scenarios.state,
      builder: (context, snapshot) {
        final state = snapshot.requireData;
        if (!state.isPresenting) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEE101722),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x5564D8FF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresenterButton(
                        tooltip: 'Advance to the next demo state',
                        label: 'Next demo step',
                        icon: Icons.skip_next_outlined,
                        onPressed: state.isPlaying || state.isComplete
                            ? null
                            : () => unawaited(
                                _runDemoAction(context, scenarios.next),
                              ),
                      ),
                      _PresenterButton(
                        tooltip: state.isPlaying
                            ? 'Pause automatic demo playback'
                            : 'Play demo automatically',
                        label: state.isPlaying ? 'Pause demo' : 'Play demo',
                        icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
                        onPressed: state.isComplete
                            ? null
                            : state.isPlaying
                            ? scenarios.pause
                            : () => unawaited(
                                _runDemoAction(context, scenarios.play),
                              ),
                      ),
                      _PresenterButton(
                        tooltip: 'Restart the demo from its fake baseline',
                        label: 'Restart demo',
                        icon: Icons.restart_alt,
                        onPressed: () => unawaited(
                          _runDemoAction(context, scenarios.restart),
                        ),
                      ),
                      _PresenterButton(
                        tooltip: 'Stop presenting and return to Controller',
                        label: 'Return to Controller',
                        icon: Icons.memory_outlined,
                        onPressed: () => unawaited(
                          _runDemoAction(context, () async {
                            scenarios.stopPresentation();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _runDemoAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Demo action failed: $error')));
  }
}

class _PresenterButton extends StatelessWidget {
  const _PresenterButton({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Tooltip(
        message: tooltip,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}

class _UrgentPromptOverlay extends StatelessWidget {
  const _UrgentPromptOverlay({
    required this.state,
    required this.safePadding,
    required this.isPortrait,
    required this.constrained,
  });

  final RobotFaceState state;
  final EdgeInsets safePadding;
  final bool isPortrait;
  final bool constrained;

  @override
  Widget build(BuildContext context) {
    final prompt = _promptFor(state);
    final promptScale = _promptScaleFor(state);
    if (prompt == null) {
      return const SizedBox.shrink();
    }

    final quarterTurns = (isPortrait ? 1 : 0) + (state.isFlipped ? 2 : 0);
    if (constrained &&
        (state.mode == RobotFaceMode.doseReady ||
            state.mode == RobotFaceMode.error)) {
      // A square keeps physical safe bounds unchanged by the face rotation.
      return IgnorePointer(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Align(
            alignment: Alignment.center,
            child: SizedBox.square(
              dimension: 64,
              child: DecoratedBox(
                key: RobotFaceScreen.urgentPromptSurfaceKey,
                decoration: BoxDecoration(
                  color: const Color(0xFF081019),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _promptColorFor(state.mode)),
                ),
                child: RotatedBox(
                  quarterTurns: quarterTurns,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          prompt,
                          key: RobotFaceScreen.urgentPromptKey,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _promptColorFor(state.mode),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 6),
          child: AnimatedScale(
            key: RobotFaceScreen.urgentPromptScaleKey,
            scale: promptScale,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 280),
            child: DecoratedBox(
              key: RobotFaceScreen.urgentPromptSurfaceKey,
              decoration: BoxDecoration(
                color: const Color(0xFF081019).withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _promptColorFor(state.mode).withValues(alpha: 0.32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: state.mode == RobotFaceMode.doseReady ? 10 : 8,
                      height: state.mode == RobotFaceMode.doseReady ? 10 : 8,
                      decoration: BoxDecoration(
                        color: _promptColorFor(state.mode),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      prompt,
                      key: RobotFaceScreen.urgentPromptKey,
                      style: TextStyle(
                        fontSize: state.mode == RobotFaceMode.doseReady
                            ? 20
                            : 16,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _promptFor(RobotFaceState state) {
    return switch (state.mode) {
      RobotFaceMode.doseReady => 'READY',
      RobotFaceMode.doseApproaching => 'SOON',
      RobotFaceMode.missed => 'MISSED',
      RobotFaceMode.happyConfirmed => 'DONE',
      RobotFaceMode.error => 'HELP',
      RobotFaceMode.offline => 'OFFLINE',
      _ => null,
    };
  }

  Color _promptColorFor(RobotFaceMode mode) {
    return switch (mode) {
      RobotFaceMode.doseReady => const Color(0xFF62E9C5),
      RobotFaceMode.doseApproaching => const Color(0xFFFFB84D),
      RobotFaceMode.happyConfirmed => const Color(0xFF62E9C5),
      RobotFaceMode.error => const Color(0xFFFF728C),
      RobotFaceMode.offline => const Color(0xFF9AA3B8),
      _ => Colors.white,
    };
  }

  double _promptScaleFor(RobotFaceState state) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);

    return switch (state.mode) {
      RobotFaceMode.doseApproaching => 1 + (ramp * 0.06),
      RobotFaceMode.doseReady => 1.1,
      _ => 1,
    };
  }
}

class _RobotFaceFrame extends StatelessWidget {
  const _RobotFaceFrame({
    required this.state,
    required this.isActive,
    required this.voicePhase,
    required this.animationCue,
    required this.animationRevision,
    required this.onAnimationCompleted,
    required this.onInteraction,
    required this.detailsRevealed,
    required this.statusSafePadding,
    required this.squarePrompt,
    required this.isPortrait,
    this.onLongPress,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
  });

  final RobotFaceState state;
  final bool isActive;
  final VoicePlaybackPhase voicePhase;
  final RobotFaceAnimationCue? animationCue;
  final int animationRevision;
  final void Function(RobotFaceAnimationCue cue, int revision)?
  onAnimationCompleted;
  final VoidCallback onInteraction;
  final bool detailsRevealed;
  final EdgeInsets statusSafePadding;
  final bool squarePrompt;
  final bool isPortrait;
  final VoidCallback? onLongPress;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;
  final RobotFaceActionAuthorizer? actionAuthorizer;

  @override
  Widget build(BuildContext context) {
    final hasActionPanel =
        state.actionDoseId != null && state.availableActions.isNotEmpty;
    final requiresDetails =
        hasActionPanel ||
        state.mode == RobotFaceMode.doseApproaching ||
        state.mode == RobotFaceMode.doseReady ||
        state.mode == RobotFaceMode.dispensing ||
        state.mode == RobotFaceMode.missed ||
        state.mode == RobotFaceMode.error ||
        state.hasPinnedShortageAlert ||
        state.controllerCondition == RobotFaceControllerCondition.fault ||
        state.controllerCondition ==
            RobotFaceControllerCondition.bluetoothUnavailable;
    final showDetails = detailsRevealed || requiresDetails;
    final useCompactOverlay =
        (state.mode == RobotFaceMode.doseReady ||
            state.mode == RobotFaceMode.error) &&
        squarePrompt;
    final preferActionRail =
        useCompactOverlay &&
        hasActionPanel &&
        state.availableActions.length == 1 &&
        state.availableActions.contains(RobotFaceActionKind.askForHelp);
    final actionHost = _RobotFaceActionHost(
      key: RobotFaceScreen.actionHostKey,
      state: state,
      isCompact: useCompactOverlay,
      preferRail: preferActionRail,
      isVisible: hasActionPanel && showDetails,
      doseActionLogger: doseActionLogger,
      visibleAndTakenLogger: visibleAndTakenLogger,
      actionAuthorizer: actionAuthorizer,
    );

    return SizedBox.expand(
      child: Transform(
        key: RobotFaceScreen.flipTransformKey,
        alignment: Alignment.center,
        transform: state.isFlipped
            ? Matrix4.rotationZ(math.pi)
            : Matrix4.identity(),
        child: Stack(
          key: RobotFaceScreen.displayFrameKey,
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => onInteraction(),
              onLongPress: onLongPress,
              child: RobotFaceSurface(state: state),
            ),
            Padding(
              padding: statusSafePadding.add(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: CustomMultiChildLayout(
                delegate: _ReservedFaceLayout(
                  squarePrompt: squarePrompt,
                  isFlipped: state.isFlipped,
                  isPortrait: isPortrait,
                  reserveExitRow:
                      MediaQuery.textScalerOf(context).scale(12) > 12,
                  preferActionRail: preferActionRail,
                  preferInlineAction:
                      !useCompactOverlay &&
                      hasActionPanel &&
                      state.availableActions.length == 1 &&
                      state.availableActions.contains(
                        RobotFaceActionKind.askForHelp,
                      ),
                ),
                children: <Widget>[
                  LayoutId(
                    id: 'prompt',
                    child: squarePrompt
                        ? const SizedBox.shrink()
                        : _UrgentPromptOverlay(
                            state: state,
                            safePadding: EdgeInsets.zero,
                            isPortrait: false,
                            constrained: false,
                          ),
                  ),
                  LayoutId(
                    id: 'face',
                    child: Semantics(
                      key: RobotFaceScreen.detailRevealKey,
                      button: true,
                      label: showDetails
                          ? 'Robot Face. Reminder details are shown.'
                          : 'Robot Face. Tap to show reminder details.',
                      onTap: onInteraction,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => onInteraction(),
                        onLongPress: onLongPress,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Match the reservation's aspect ratio, then scale uniformly.
                            // A 400dp paint height also scales rings/minimum lids safely
                            // when mandatory content leaves only a sliver for the face.
                            final scale = math.max(
                              1.0,
                              400 / math.max(1.0, constraints.maxHeight),
                            );
                            return FittedBox(
                              // Let the soft glow blend across the full surface.
                              fit: BoxFit.contain,
                              child: SizedBox(
                                key: RobotFaceScreen.canvasKey,
                                width: constraints.maxWidth * scale,
                                height:
                                    math.max(1.0, constraints.maxHeight) *
                                    scale,
                                child: RobotFaceCanvas(
                                  state: state,
                                  paintSurface: false,
                                  isActive: isActive,
                                  isPreparing:
                                      voicePhase ==
                                      VoicePlaybackPhase.preparing,
                                  isSpeaking:
                                      voicePhase == VoicePlaybackPhase.speaking,
                                  animationCue: animationCue,
                                  animationRevision: animationRevision,
                                  onAnimationCompleted: onAnimationCompleted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  LayoutId(
                    id: 'status',
                    child: _ScrollableFaceDetails(
                      key: RobotFaceScreen.bottomCardKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTap: onInteraction,
                        onLongPress: () {},
                        child: _RobotFaceStatusCard(
                          state: state,
                          actionHost: const SizedBox.shrink(),
                          showDetails: showDetails,
                          compactOverlay: useCompactOverlay,
                        ),
                      ),
                    ),
                  ),
                  LayoutId(
                    id: 'actions',
                    child: _RailOrBodyAction(
                      preferRail: preferActionRail,
                      child: actionHost,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Native scrolling keeps the urgent badge and actions outside the viewport.
class _ScrollableFaceDetails extends StatefulWidget {
  const _ScrollableFaceDetails({super.key, required this.child});
  final Widget child;

  @override
  State<_ScrollableFaceDetails> createState() => _ScrollableFaceDetailsState();
}

class _ScrollableFaceDetailsState extends State<_ScrollableFaceDetails> {
  bool _overflows = false;
  bool _moreBelow = false;
  (bool, bool)? _pendingMetrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      void update(ScrollMetrics metrics) {
        // Compare the unmodified content against the whole allocation, not the
        // reduced viewport, so resizing can remove the fallback again.
        final overflows =
            metrics.maxScrollExtent + metrics.viewportDimension >
            constraints.maxHeight + 0.01;
        final moreBelow = overflows && metrics.extentAfter > 0.01;
        final pending = _pendingMetrics != null;
        if (!pending && overflows == _overflows && moreBelow == _moreBelow) {
          return;
        }
        _pendingMetrics = (overflows, moreBelow);
        if (pending) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final (overflows, moreBelow) = _pendingMetrics!;
          _pendingMetrics = null;
          if (!mounted ||
              (overflows == _overflows && moreBelow == _moreBelow)) {
            return;
          }
          setState(() {
            _overflows = overflows;
            _moreBelow = moreBelow;
          });
        });
        // Metrics can arrive after the frame in a microtask. A post-frame
        // callback alone does not request the frame that will execute it.
        WidgetsBinding.instance.ensureVisualUpdate();
      }

      return NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          update(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            update(notification.metrics);
            return false;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  primary: false,
                  child: widget.child,
                ),
              ),
              if (_overflows)
                Visibility(
                  visible: _moreBelow,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.textScalerOf(context).scale(12) / 6,
                    ),
                    child: const Text(
                      'Scroll for more details',
                      key: ValueKey('robot-face-more-details'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

// Keep one action subtree: measure a rail candidate, then lay it out at body
// width if rejected. MultiChildLayoutDelegate itself permits only one layout
// per child, so this proxy owns the optional second measurement.
class _RailOrBodyAction extends SingleChildRenderObjectWidget {
  const _RailOrBodyAction({required this.preferRail, required super.child});
  final bool preferRail;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRailOrBodyAction(preferRail);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRailOrBodyAction renderObject,
  ) {
    renderObject.preferRail = preferRail;
  }
}

class _RenderRailOrBodyAction extends RenderProxyBox {
  _RenderRailOrBodyAction(this._preferRail);
  bool _preferRail;
  set preferRail(bool value) {
    if (_preferRail == value) return;
    _preferRail = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final narrow = constraints.copyWith(
      maxWidth: math.min(64, constraints.maxWidth),
    );
    child!.layout(_preferRail ? narrow : constraints, parentUsesSize: true);
    if (_preferRail &&
        child!.size.height > constraints.maxHeight - 64 - 48 - 16) {
      child!.layout(constraints, parentUsesSize: true);
    }
    size = child!.size;
  }
}

// Measure required content and touch targets before assigning leftover space
// to the decorative face. Scroll only status when its text exceeds the area.
class _ReservedFaceLayout extends MultiChildLayoutDelegate {
  _ReservedFaceLayout({
    required this.squarePrompt,
    required this.isFlipped,
    required this.isPortrait,
    required this.preferActionRail,
    required this.preferInlineAction,
    required this.reserveExitRow,
  });

  final bool reserveExitRow;
  final bool preferInlineAction;
  final bool squarePrompt;
  final bool isFlipped;
  final bool isPortrait;
  final bool preferActionRail;

  @override
  void performLayout(Size size) {
    final gutter = squarePrompt ? 72.0 : 0.0;
    final start = isFlipped ? 0.0 : gutter;
    // The prompt overlays the gap between the eyes, not an excluded canvas row.
    // Scaled exit text widens into the eye column; keep its whole row clear.
    final header = squarePrompt ? 0.0 : (reserveExitRow ? 60.0 : 32.0);
    final width = math.max(0.0, size.width - gutter);
    final normalMargin = math.min(8.0, size.height / 2);
    final bodyHeight = size.height - 2 * normalMargin;
    // Long text must still stop below the exit; only eyes can use the center gap.
    final height = math.max(0.0, bodyHeight - (squarePrompt ? 0 : 60));
    layoutChild(
      'prompt',
      BoxConstraints.tight(squarePrompt ? Size.zero : Size(size.width, 60)),
    );
    positionChild('prompt', Offset(0, normalMargin));
    final actions = layoutChild(
      'actions',
      BoxConstraints(maxWidth: width, maxHeight: height),
    );
    // Badge (64), exit (48), and two 8dp gaps leave the measurable rail
    // capacity. A Help action moves there only when its actual size fits.
    final useRail =
        preferActionRail &&
        actions.width <= 64 &&
        actions.height <= bodyHeight - 64 - 48 - 16;
    final actionHeight = useRail ? 0.0 : actions.height;
    // A single Help control can share the bottom overlay with full-size text.
    // If that would leave a narrow text column, retain the existing stack.
    final inlineAction =
        preferInlineAction && width - actions.width - 16 >= 400;
    final statusWidth = inlineAction ? width - actions.width - 16 : width;
    // Required content may reclaim up to 8dp of decorative margin, never
    // physical safe insets. The badge, exit, and accepted rail stay anchored.
    final reclaimable = squarePrompt ? math.min(8.0, 2 * normalMargin) : 0.0;
    final status = layoutChild(
      'status',
      BoxConstraints(
        minWidth: statusWidth,
        maxWidth: statusWidth,
        maxHeight: math.max(
          0.0,
          height - (inlineAction ? 0 : actionHeight) + reclaimable,
        ),
      ),
    );
    final overlayHeight = inlineAction
        ? math.max(status.height, actionHeight)
        : status.height + actionHeight;
    final reclaimed = math.max(0.0, overlayHeight - height);
    final margin = normalMargin - reclaimed / 2;
    positionChild(
      'actions',
      useRail
          ? Offset(
              isFlipped ? size.width - actions.width : 0,
              normalMargin +
                  (isPortrait
                      ? (bodyHeight + (isFlipped ? 16 : -16) - actions.height) /
                            2
                      : isFlipped
                      ? bodyHeight - 128 - actions.height
                      : 128),
            )
          : Offset(
              start + (width - actions.width) / (inlineAction ? 1 : 2),
              size.height - margin - actions.height,
            ),
    );
    positionChild(
      'status',
      Offset(
        start,
        size.height -
            margin -
            (inlineAction ? 0 : actionHeight) -
            status.height,
      ),
    );
    final faceHeight = math.max(
      0.0,
      bodyHeight - header + reclaimed - overlayHeight - 8,
    );
    layoutChild('face', BoxConstraints.tight(Size(width, faceHeight)));
    positionChild('face', Offset(start, margin + header));
  }

  @override
  bool shouldRelayout(_ReservedFaceLayout oldDelegate) =>
      squarePrompt != oldDelegate.squarePrompt ||
      isFlipped != oldDelegate.isFlipped ||
      isPortrait != oldDelegate.isPortrait ||
      preferActionRail != oldDelegate.preferActionRail ||
      preferInlineAction != oldDelegate.preferInlineAction ||
      reserveExitRow != oldDelegate.reserveExitRow;
}

class _RobotFaceStatusCard extends StatelessWidget {
  const _RobotFaceStatusCard({
    required this.state,
    required this.actionHost,
    required this.showDetails,
    required this.compactOverlay,
  });

  final RobotFaceState state;
  final Widget actionHost;
  final bool showDetails;
  final bool compactOverlay;

  String? get _requiredStatus =>
      state.statusLabel ??
      switch (state.controllerCondition) {
        RobotFaceControllerCondition.fault => 'Controller fault',
        RobotFaceControllerCondition.bluetoothUnavailable =>
          'Bluetooth unavailable',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final badgeEmphasis = _badgeEmphasisFor(state);
    final isMissedState = state.mode == RobotFaceMode.missed;
    // The controller owns action availability, including offline/error
    // follow-up states after a dispense. The screen only renders that contract.

    final content = compactOverlay && state.hasPinnedShortageAlert
        ? Padding(
            // Reserve scaled edge space for font-metric and antialias overhang.
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.textScalerOf(context).scale(12) / 6,
            ),
            child: Text(
              <String>[
                if (state.nextEventLabel.trim().isNotEmpty)
                  state.nextEventLabel,
                if (_requiredStatus?.trim().isNotEmpty == true)
                  _requiredStatus!,
                'Shortage: ${state.activeShortageMedicationLabel ?? 'Medication'}'
                    '${state.activeShortageScheduledLabel == null ? '' : ' · ${state.activeShortageScheduledLabel}'}'
                    '${state.activeShortageSlotNumber == null ? '' : ' · Slot ${state.activeShortageSlotNumber}'}. '
                    'Local only; pinned until loading is handled. Check Carousel loading before dispense.',
                if (state.networkAdvisory ==
                    RobotFaceNetworkAdvisory.internetOffline)
                  'Internet offline. Local reminders still work.',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                letterSpacing: 0,
                color: Color(0xFFFFB4C1),
              ),
            ),
          )
        : compactOverlay
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (state.nextEventLabel.trim().isNotEmpty)
                Text(
                  state.nextEventLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
              if (_requiredStatus case final status?)
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: Color(0xFFFFB4C1),
                  ),
                ),
              if (state.networkAdvisory ==
                  RobotFaceNetworkAdvisory.internetOffline)
                const _RobotFaceNetworkAdvisoryBadge(),
            ],
          )
        : !showDetails
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xC40B111B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _accentFor(state.mode),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      state.nextEventLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.expand_less_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          )
        : _buildDetails(
            context,
            badgeEmphasis: badgeEmphasis,
            isMissedState: isMissedState,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (compactOverlay &&
            !state.hasPinnedShortageAlert &&
            (state.nextEventLabel.trim().isNotEmpty ||
                _requiredStatus != null ||
                state.networkAdvisory ==
                    RobotFaceNetworkAdvisory.internetOffline))
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.textScalerOf(context).scale(12) / 6,
            ),
            child: content,
          )
        else
          content,
        actionHost,
      ],
    );
  }

  Widget _buildDetails(
    BuildContext context, {
    required double badgeEmphasis,
    required bool isMissedState,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_headlineFor(state.mode) case final headline?) ...[
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isMissedState
                            ? const Color(0xFFFFB4C1)
                            : const Color(0xFF8A96AD),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    state.nextEventLabel,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (isMissedState) ...<Widget>[
                    const SizedBox(height: 12),
                    const Text(
                      'This dose was missed.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF4D7DD),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
              if (_requiredStatus case final statusLabel?) ...<Widget>[
                const SizedBox(height: 4),
                DecoratedBox(
                  key: RobotFaceScreen.statusBadgeKey,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _accentFor(
                          state.mode,
                        ).withValues(alpha: 0.16 + badgeEmphasis * 0.2),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD3DAE7),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (state.networkAdvisory ==
              RobotFaceNetworkAdvisory.internetOffline) ...<Widget>[
            const SizedBox(height: 10),
            const _RobotFaceNetworkAdvisoryBadge(),
          ],
          if (state.hasPinnedShortageAlert) ...<Widget>[
            const SizedBox(height: 12),
            _RobotFaceShortageCard(state: state),
          ],
        ],
      ),
    );
  }

  // Urgent modes already have a pinned headline above the face.
  String? _headlineFor(RobotFaceMode mode) => switch (mode) {
    RobotFaceMode.sleepy => 'RESTING',
    RobotFaceMode.waitingForConfirmation => 'WAITING',
    RobotFaceMode.dispensing => 'DISPENSING',
    RobotFaceMode.idle => 'NEXT EVENT',
    _ => null,
  };

  Color _accentFor(RobotFaceMode mode) {
    return switch (mode.tone) {
      RobotFaceTone.ready => const Color(0xFF56EBC6),
      RobotFaceTone.attention => const Color(0xFFFFB84D),
      RobotFaceTone.calm => const Color(0xFF4EE6FF),
      RobotFaceTone.warning => const Color(0xFFFF728C),
      RobotFaceTone.offline => const Color(0xFF98A5BC),
    };
  }

  double _badgeEmphasisFor(RobotFaceState state) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);

    return switch (state.mode) {
      RobotFaceMode.doseApproaching => 0.28 + (ramp * 0.52),
      RobotFaceMode.doseReady => 1,
      RobotFaceMode.missed => 0.92,
      RobotFaceMode.sleepy => 0.18,
      RobotFaceMode.idle when state.isInAwakeWindow => 0.24,
      _ => 0,
    };
  }
}

class _RobotFaceActionHost extends StatelessWidget {
  const _RobotFaceActionHost({
    super.key,
    required this.state,
    required this.isVisible,
    required this.isCompact,
    required this.preferRail,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
  });

  final RobotFaceState state;
  final bool isVisible;
  final bool isCompact;
  final bool preferRail;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;
  final RobotFaceActionAuthorizer? actionAuthorizer;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !isVisible,
      child: TickerMode(
        enabled: isVisible,
        child: ExcludeSemantics(
          excluding: !isVisible,
          child: ExcludeFocus(
            excluding: !isVisible,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: isCompact ? 0 : 10),
                _RobotFaceActionPanel(
                  key: RobotFaceScreen.actionPanelKey,
                  state: state,
                  isCompact: isCompact,
                  preferRail: preferRail,
                  doseActionLogger: doseActionLogger,
                  visibleAndTakenLogger: visibleAndTakenLogger,
                  actionAuthorizer: actionAuthorizer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RobotFaceNetworkAdvisoryBadge extends StatelessWidget {
  const _RobotFaceNetworkAdvisoryBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: RobotFaceScreen.networkAdvisoryBadgeKey,
      decoration: BoxDecoration(
        color: const Color(0xFFFFB84D).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC765).withValues(alpha: 0.3),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFFFCC73)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Internet offline. Local reminders still work.',
                style: TextStyle(
                  color: Color(0xFFFFD99A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotFaceShortageCard extends StatelessWidget {
  const _RobotFaceShortageCard({required this.state});

  final RobotFaceState state;

  @override
  Widget build(BuildContext context) {
    final medicationLabel = state.activeShortageMedicationLabel ?? 'Medication';
    final slotNumber = state.activeShortageSlotNumber;
    final scheduledLabel = state.activeShortageScheduledLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x26FF728C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66FF728C)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24FF728C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9AAC)),
                SizedBox(width: 8),
                Text(
                  'Urgent shortage',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              medicationLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: <Widget>[
                if (scheduledLabel != null)
                  Text(
                    'Scheduled $scheduledLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF8C8D1),
                    ),
                  ),
                if (slotNumber != null)
                  Text(
                    'Slot $slotNumber',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF8C8D1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Local-only alert on this phone. Open Carousel to review loading before the next dispense.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFFF4D7DD),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pinned until loading is handled on this phone.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFB4C1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RobotFaceActionPanel extends StatefulWidget {
  const _RobotFaceActionPanel({
    super.key,
    required this.state,
    required this.isCompact,
    required this.preferRail,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
  });

  final RobotFaceState state;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;
  final RobotFaceActionAuthorizer? actionAuthorizer;

  final bool isCompact;
  final bool preferRail;

  @override
  State<_RobotFaceActionPanel> createState() => _RobotFaceActionPanelState();
}

class _RobotFaceActionPanelState extends State<_RobotFaceActionPanel> {
  final Set<String> _submittingDoseIds = <String>{};
  // Help can start during terminal authorization; each submission owns its lock.
  final Set<String> _terminalSubmittingDoseIds = <String>{};
  final Set<String> _terminalReservedDoseIds = <String>{};
  String? _latestNonNullActionDoseId;
  int _nonNullActionDoseGeneration = 0;
  // Widget-lifetime local lockout for actions already completed on the
  // currently rendered dose state.
  final Map<String, Set<RobotFaceActionKind>> _completedActionsByDoseId =
      <String, Set<RobotFaceActionKind>>{};

  @override
  void initState() {
    super.initState();
    _observeNonNullActionDoseId(widget.state.actionDoseId);
  }

  @override
  void didUpdateWidget(covariant _RobotFaceActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final actionDoseId = widget.state.actionDoseId;
    _observeNonNullActionDoseId(actionDoseId);
    if (actionDoseId == null || oldWidget.state.actionDoseId == actionDoseId) {
      return;
    }
    _completedActionsByDoseId.removeWhere(
      (doseId, _) => doseId != actionDoseId,
    );
  }

  void _observeNonNullActionDoseId(String? actionDoseId) {
    if (actionDoseId == null || actionDoseId == _latestNonNullActionDoseId) {
      return;
    }
    _latestNonNullActionDoseId = actionDoseId;
    _nonNullActionDoseGeneration += 1;
  }

  @override
  Widget build(BuildContext context) {
    final isMissedState = widget.state.mode == RobotFaceMode.missed;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMissedState
            ? const Color(0x26FF728C)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMissedState
              ? const Color(0x66FF728C)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.isCompact ? 0 : 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _buildActionButtons(context),
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (widget.state.availableActions.contains(
      RobotFaceActionKind.recognizeMissedDose,
    )) {
      buttons.add(
        _buildActionButton(
          key: RobotFaceScreen.recognizeMissedDoseButtonKey,
          label: 'I saw this missed dose',
          isEnabled: _isActionEnabled(RobotFaceActionKind.recognizeMissedDose),
          isProminent: true,
          onPressed: () {
            final occurredAt = DoseyAppScope.of(context).appClock.now().toUtc();
            unawaited(
              _logAction(
                context,
                actionKind: RobotFaceActionKind.recognizeMissedDose,
                event: DoseLogEvent.doseMissedRecognized(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: occurredAt,
                ),
                successMessage: 'Missed dose noted.',
              ),
            );
          },
        ),
      );
    }

    if (widget.state.availableActions.contains(
      RobotFaceActionKind.confirmTaken,
    )) {
      buttons.add(
        _buildActionButton(
          key: RobotFaceScreen.confirmTakenButtonKey,
          label: 'I can see it and took it',
          isEnabled: _isActionEnabled(RobotFaceActionKind.confirmTaken),
          onPressed: () {
            final occurredAt = DoseyAppScope.of(context).appClock.now().toUtc();
            unawaited(_logVisibleAndTaken(context, occurredAt: occurredAt));
          },
        ),
      );
    }

    if (widget.state.availableActions.contains(RobotFaceActionKind.skipDose)) {
      buttons.add(
        _buildActionButton(
          key: RobotFaceScreen.skipDoseButtonKey,
          label: 'Skip',
          isEnabled: _isActionEnabled(RobotFaceActionKind.skipDose),
          onPressed: () {
            final occurredAt = DoseyAppScope.of(context).appClock.now().toUtc();
            unawaited(
              _logAction(
                context,
                actionKind: RobotFaceActionKind.skipDose,
                event: DoseLogEvent.doseSkipped(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: occurredAt,
                ),
                successMessage: 'Skip logged.',
              ),
            );
          },
        ),
      );
    }

    if (widget.state.availableActions.contains(
      RobotFaceActionKind.askForHelp,
    )) {
      buttons.add(
        _buildActionButton(
          key: RobotFaceScreen.needHelpButtonKey,
          label: 'Need help',
          isEnabled: _isActionEnabled(RobotFaceActionKind.askForHelp),
          onPressed: () {
            final occurredAt = DoseyAppScope.of(context).appClock.now().toUtc();
            unawaited(
              _logAction(
                context,
                actionKind: RobotFaceActionKind.askForHelp,
                event: DoseLogEvent.caregiverHelpRequested(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: occurredAt,
                ),
                successMessage: 'Help request logged.',
              ),
            );
          },
        ),
      );
    }

    return buttons;
  }

  Widget _buildActionButton({
    required Key key,
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
    bool isProminent = false,
  }) {
    final child = Text(label, textAlign: TextAlign.center);

    if (isProminent) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280),
        child: FilledButton(
          key: key,
          onPressed: _isSubmittingCurrentDose || !isEnabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD94A66),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      );
    }

    return FilledButton.tonal(
      key: key,
      onPressed: _isSubmittingCurrentDose || !isEnabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(widget.preferRail ? 48 : 0, 48),
        shape: widget.preferRail
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            : null,
        padding: widget.preferRail
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
          fontSize: widget.preferRail ? 12 : 13,
          height: widget.preferRail ? 1.2 : 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: child,
    );
  }

  bool _isActionEnabled(RobotFaceActionKind actionKind) {
    final actionDoseId = widget.state.actionDoseId;
    if (actionDoseId == null) {
      return false;
    }

    if (!widget.state.availableActions.contains(actionKind)) {
      return false;
    }

    return !(_completedActionsByDoseId[actionDoseId]?.contains(actionKind) ??
            false) &&
        !(_isTerminalAction(actionKind) &&
            _terminalReservedDoseIds.contains(actionDoseId));
  }

  bool get _isSubmittingCurrentDose {
    final actionDoseId = widget.state.actionDoseId;
    return actionDoseId != null &&
        (_submittingDoseIds.contains(actionDoseId) ||
            _terminalSubmittingDoseIds.contains(actionDoseId));
  }

  Set<RobotFaceActionKind> _completedActionsForDose(String actionDoseId) {
    return _completedActionsByDoseId.putIfAbsent(
      actionDoseId,
      () => <RobotFaceActionKind>{},
    );
  }

  bool _isTerminalAction(RobotFaceActionKind actionKind) {
    return switch (actionKind) {
      RobotFaceActionKind.confirmTaken || RobotFaceActionKind.skipDose => true,
      RobotFaceActionKind.askForHelp ||
      RobotFaceActionKind.recognizeMissedDose => false,
    };
  }

  bool _reserveTerminalDose(
    String actionDoseId,
    RobotFaceActionKind actionKind,
  ) {
    if (!widget.state.availableActions.contains(actionKind) ||
        _completedActionsByDoseId[actionDoseId]?.contains(actionKind) == true) {
      return false;
    }
    if (!_terminalReservedDoseIds.add(actionDoseId)) return false;
    if (mounted) setState(() {});
    return true;
  }

  void _releaseTerminalDose(String actionDoseId) {
    if (!_terminalReservedDoseIds.remove(actionDoseId)) return;
    if (mounted) setState(() {});
  }

  Future<bool> _authorizeAction(BuildContext context) {
    return widget.actionAuthorizer?.call(context) ??
        authorizeActionPin(context);
  }

  Future<void> _logAction(
    BuildContext context, {
    required RobotFaceActionKind actionKind,
    required DoseLogEvent event,
    required String successMessage,
  }) async {
    final actionDoseId = widget.state.actionDoseId;
    if (actionDoseId == null || _isSubmittingCurrentDose) {
      return;
    }
    if (_isTerminalAction(actionKind)) {
      return _runTerminalAction(
        context,
        actionDoseId: actionDoseId,
        actionKind: actionKind,
        event: event,
        successMessage: successMessage,
      );
    }
    final submissionGeneration = _nonNullActionDoseGeneration;
    setState(() => _submittingDoseIds.add(actionDoseId));
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      final logged =
          await (widget.doseActionLogger ?? DoseActionLogger.logDoseAction)(
            context,
            event,
            successMessage,
          );
      // The shared logger returns false after handled failures. Leave the
      // buttons available so the user can retry instead of locking the dose.
      if (!logged) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      if (mounted) {
        setState(() {
          if (_nonNullActionDoseGeneration != submissionGeneration) {
            return;
          }
          final completedActions = _completedActionsForDose(actionDoseId);
          completedActions.add(actionKind);
        });
      }
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Dose action failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingDoseIds.remove(actionDoseId));
      }
    }
  }

  Future<void> _logVisibleAndTaken(
    BuildContext context, {
    required DateTime occurredAt,
  }) async {
    final actionDoseId = widget.state.actionDoseId;
    if (actionDoseId == null) return;
    return _runTerminalAction(
      context,
      actionDoseId: actionDoseId,
      actionKind: RobotFaceActionKind.confirmTaken,
      occurredAt: occurredAt,
      successMessage: 'Taken logged.',
    );
  }

  Future<void> _runTerminalAction(
    BuildContext context, {
    required String actionDoseId,
    required RobotFaceActionKind actionKind,
    DoseLogEvent? event,
    DateTime? occurredAt,
    required String successMessage,
  }) async {
    if (!_reserveTerminalDose(actionDoseId, actionKind)) return;
    var isSubmitting = false;
    ScaffoldMessengerState? messenger;
    try {
      final submissionGeneration = _nonNullActionDoseGeneration;
      if (!await _authorizeAction(context) ||
          !context.mounted ||
          _nonNullActionDoseGeneration != submissionGeneration ||
          widget.state.actionDoseId != actionDoseId ||
          !widget.state.availableActions.contains(actionKind)) {
        return;
      }

      setState(() => _terminalSubmittingDoseIds.add(actionDoseId));
      isSubmitting = true;
      messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      final logged = actionKind == RobotFaceActionKind.confirmTaken
          ? await (widget.visibleAndTakenLogger ??
                DoseActionLogger.logRobotFaceVisibleAndTaken)(
              context,
              doseId: actionDoseId,
              occurredAt: occurredAt!,
              successMessage: successMessage,
            )
          : await (widget.doseActionLogger ?? DoseActionLogger.logDoseAction)(
              context,
              event!,
              successMessage,
            );
      if (!logged || !context.mounted) return;
      setState(() {
        if (_nonNullActionDoseGeneration != submissionGeneration) {
          return;
        }
        // Close even terminal kinds offered later, but not independent Help.
        _completedActionsForDose(
          actionDoseId,
        ).addAll(RobotFaceActionKind.values.where(_isTerminalAction));
      });
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger?.showSnackBar(
        SnackBar(content: Text('Dose action failed: $error')),
      );
    } finally {
      if (isSubmitting && mounted) {
        setState(() => _terminalSubmittingDoseIds.remove(actionDoseId));
      }
      _releaseTerminalDose(actionDoseId);
    }
  }
}
