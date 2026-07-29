import 'dart:async';
import 'dart:math' as math;

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

class RobotFaceScreen extends StatefulWidget {
  const RobotFaceScreen({
    super.key,
    this.controller,
    this.controllerResolver,
    this.stateStream,
    this.initialState,
    this.isActive = true,
    this.doseActionLogger,
    this.onLongPress,
  });

  static const canvasKey = ValueKey<String>('robot-face-canvas');
  static const bottomCardKey = ValueKey<String>('robot-face-bottom-card');
  static const displayFrameKey = ValueKey<String>('robot-face-display-frame');
  static const flipTransformKey = ValueKey<String>('robot-face-flip-transform');
  static const urgentPromptKey = ValueKey<String>('robot-face-urgent-prompt');
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

  void _handleInteraction() {
    if (!widget.isActive) return;
    setState(() {
      _interactionRevision -= 1;
    });
    _interactionController?.recordInteraction();
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
                    ColoredBox(
                      color: const Color(0xFF04070D),
                      child: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isPortraitFrame =
                                constraints.maxHeight > constraints.maxWidth;
                            Widget frame = _RobotFaceFrame(
                              state: state,
                              isActive: widget.isActive,
                              voicePhase: effectiveVoicePhase,
                              animationCue: animationCue,
                              animationRevision: animationRevision,
                              onAnimationCompleted: labControlsAnimation
                                  ? faceLab?.completeAnimation
                                  : _completeInteractionAnimation,
                              onInteraction: _handleInteraction,
                              onLongPress: widget.onLongPress,
                              doseActionLogger: widget.doseActionLogger,
                            );

                            if (isPortraitFrame) {
                              frame = RotatedBox(quarterTurns: 1, child: frame);
                            }

                            return Center(child: frame);
                          },
                        ),
                      ),
                    ),
                    if (scenarios != null)
                      _DemoPresenterControls(scenarios: scenarios),
                    if (faceLab != null)
                      _DemoFaceLabControls(
                        controller: faceLab,
                        state: labState,
                      ),
                    if (widget.onLongPress != null)
                      _RobotFaceExitButton(onPressed: widget.onLongPress!),
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
          child: Semantics(
            button: true,
            label: 'Open Today',
            child: SizedBox(
              height: 48,
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
  const _UrgentPromptOverlay({required this.state});

  final RobotFaceState state;

  @override
  Widget build(BuildContext context) {
    final prompt = _promptFor(state);
    final promptScale = _promptScaleFor(state);
    if (prompt == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: AnimatedScale(
            key: RobotFaceScreen.urgentPromptScaleKey,
            scale: promptScale,
            duration: const Duration(milliseconds: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF081019).withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _promptColorFor(state.mode).withValues(alpha: 0.32),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _promptColorFor(state.mode).withValues(alpha: 0.14),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
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
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _promptColorFor(
                              state.mode,
                            ).withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
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
      RobotFaceMode.doseApproaching => const Color(0xFF64D8FF),
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
    this.onLongPress,
    this.doseActionLogger,
  });

  final RobotFaceState state;
  final bool isActive;
  final VoicePlaybackPhase voicePhase;
  final RobotFaceAnimationCue? animationCue;
  final int animationRevision;
  final void Function(RobotFaceAnimationCue cue, int revision)?
  onAnimationCompleted;
  final VoidCallback onInteraction;
  final VoidCallback? onLongPress;
  final RobotFaceDoseActionLogger? doseActionLogger;

  @override
  Widget build(BuildContext context) {
    final isMissedState = state.mode == RobotFaceMode.missed;
    final displayAccent = _displayAccentFor(state);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Transform(
          key: RobotFaceScreen.flipTransformKey,
          alignment: Alignment.center,
          transform: state.isFlipped
              ? Matrix4.rotationZ(math.pi)
              : Matrix4.identity(),
          child: Column(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => onInteraction(),
                  onLongPress: onLongPress,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      AnimatedContainer(
                        key: RobotFaceScreen.displayFrameKey,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: const Color(0xFF02050A),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: displayAccent.withValues(
                              alpha: isMissedState ? 0.42 : 0.16,
                            ),
                            width: isMissedState ? 1.6 : 1.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: displayAccent.withValues(
                                alpha: isMissedState ? 0.22 : 0.12,
                              ),
                              blurRadius: isMissedState ? 56 : 44,
                              spreadRadius: isMissedState ? 8 : 4,
                            ),
                            const BoxShadow(
                              color: Color(0xCC010203),
                              blurRadius: 18,
                              spreadRadius: -4,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: SizedBox.expand(
                              key: RobotFaceScreen.canvasKey,
                              child: RobotFaceCanvas(
                                state: state,
                                isActive: isActive,
                                isPreparing:
                                    voicePhase == VoicePlaybackPhase.preparing,
                                isSpeaking:
                                    voicePhase == VoicePlaybackPhase.speaking,
                                animationCue: animationCue,
                                animationRevision: animationRevision,
                                onAnimationCompleted: onAnimationCompleted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          opacity: _displayGlassOpacityFor(state),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.08),
                                ],
                                stops: const <double>[0, 0.26, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _UrgentPromptOverlay(state: state),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _RobotFaceStatusCard(
                key: RobotFaceScreen.bottomCardKey,
                state: state,
                doseActionLogger: doseActionLogger,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _displayAccentFor(RobotFaceState state) {
    if (state.mode == RobotFaceMode.missed) {
      return const Color(0xFFFF728C);
    }
    if (state.mode == RobotFaceMode.sleepy) {
      return const Color(0xFF7288B5);
    }
    if (state.mode == RobotFaceMode.idle && state.isInAwakeWindow) {
      return const Color(0xFF67E8FF);
    }

    return switch (state.mode.tone) {
      RobotFaceTone.ready => const Color(0xFF56EBC6),
      RobotFaceTone.attention || RobotFaceTone.calm => const Color(0xFF43E7FF),
      RobotFaceTone.warning => const Color(0xFFFF728C),
      RobotFaceTone.offline => const Color(0xFF98A5BC),
    };
  }

  double _displayGlassOpacityFor(RobotFaceState state) {
    return switch (state.mode) {
      RobotFaceMode.missed => 0.08,
      RobotFaceMode.sleepy => 0.22,
      RobotFaceMode.idle when state.isInAwakeWindow => 0.14,
      RobotFaceMode.doseApproaching ||
      RobotFaceMode.doseReady ||
      RobotFaceMode.dispensing => 0.12,
      _ => 0.1,
    };
  }
}

class _RobotFaceStatusCard extends StatelessWidget {
  const _RobotFaceStatusCard({
    super.key,
    required this.state,
    this.doseActionLogger,
  });

  final RobotFaceState state;
  final RobotFaceDoseActionLogger? doseActionLogger;

  @override
  Widget build(BuildContext context) {
    final badgeEmphasis = _badgeEmphasisFor(state);
    final showActionPanel =
        state.actionDoseId != null && state.availableActions.isNotEmpty;
    final isMissedState = state.mode == RobotFaceMode.missed;
    final isSleepyState = state.mode == RobotFaceMode.sleepy;
    // The controller owns action availability, including offline/error
    // follow-up states after a dispense. The screen only renders that contract.

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMissedState
            ? const Color(0xD11E0C12)
            : isSleepyState
            ? const Color(0xC20A0E16)
            : const Color(0xC20B111B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isMissedState
              ? const Color(0x66FF728C)
              : isSleepyState
              ? const Color(0x4D92A2C8)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isMissedState
                ? const Color(0x66FF728C)
                : isSleepyState
                ? const Color(0x2F6477A8)
                : Colors.black.withValues(alpha: 0.26),
            blurRadius: isMissedState ? 28 : 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _accentFor(state.mode),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _accentFor(state.mode).withValues(alpha: 0.42),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _headlineFor(state.mode),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isMissedState
                              ? const Color(0xFFFFB4C1)
                              : const Color(0xFF8A96AD),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isMissedState) ...<Widget>[
                        const Text(
                          'This dose was missed.',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF4D7DD),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.nextEventLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFB4C1),
                          ),
                        ),
                      ] else
                        Text(
                          state.nextEventLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_compactStatusLabelFor(state)
                    case final statusLabel?) ...<Widget>[
                  const SizedBox(width: 12),
                  Flexible(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 280),
                      scale: 1 + (badgeEmphasis * 0.05),
                      child: DecoratedBox(
                        key: RobotFaceScreen.statusBadgeKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.06 + (badgeEmphasis * 0.05),
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _accentFor(
                              state.mode,
                            ).withValues(alpha: 0.08 + (badgeEmphasis * 0.14)),
                          ),
                          boxShadow: badgeEmphasis == 0
                              ? null
                              : <BoxShadow>[
                                  BoxShadow(
                                    color: _accentFor(state.mode).withValues(
                                      alpha: 0.12 + (badgeEmphasis * 0.1),
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 + (badgeEmphasis * 2),
                            vertical: 8,
                          ),
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD3DAE7),
                            ),
                          ),
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
            if (showActionPanel) ...<Widget>[
              const SizedBox(height: 10),
              _RobotFaceActionPanel(
                state: state,
                doseActionLogger: doseActionLogger,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _headlineFor(RobotFaceMode mode) {
    return switch (mode) {
      RobotFaceMode.doseReady => 'READY NOW',
      RobotFaceMode.doseApproaching => 'UP NEXT',
      RobotFaceMode.happyConfirmed => 'CONFIRMED',
      RobotFaceMode.error => 'CHECK ROBOT',
      RobotFaceMode.offline => 'OFFLINE',
      RobotFaceMode.sleepy => 'RESTING',
      RobotFaceMode.waitingForConfirmation => 'WAITING',
      RobotFaceMode.dispensing => 'DISPENSING',
      RobotFaceMode.missed => 'MISSED',
      _ => 'NEXT EVENT',
    };
  }

  Color _accentFor(RobotFaceMode mode) {
    return switch (mode.tone) {
      RobotFaceTone.ready => const Color(0xFF56EBC6),
      RobotFaceTone.attention || RobotFaceTone.calm => const Color(0xFF4EE6FF),
      RobotFaceTone.warning => const Color(0xFFFF728C),
      RobotFaceTone.offline => const Color(0xFF98A5BC),
    };
  }

  String? _compactStatusLabelFor(RobotFaceState state) {
    final statusLabel = state.statusLabel?.trim();
    if (statusLabel == null || statusLabel.isEmpty) {
      return null;
    }

    return switch (state.mode) {
      RobotFaceMode.doseReady => 'Ready now',
      RobotFaceMode.doseApproaching => 'Coming up',
      RobotFaceMode.happyConfirmed => 'Dose logged',
      RobotFaceMode.sleepy => 'Sleep mode',
      RobotFaceMode.error => statusLabel,
      RobotFaceMode.missed => 'Missed dose',
      RobotFaceMode.offline => 'Reconnect needed',
      _ => statusLabel,
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
  const _RobotFaceActionPanel({required this.state, this.doseActionLogger});

  final RobotFaceState state;
  final RobotFaceDoseActionLogger? doseActionLogger;

  @override
  State<_RobotFaceActionPanel> createState() => _RobotFaceActionPanelState();
}

class _RobotFaceActionPanelState extends State<_RobotFaceActionPanel> {
  bool _isSubmitting = false;
  // Widget-lifetime local lockout for actions already completed on the
  // currently rendered dose state.
  final Map<String, Set<RobotFaceActionKind>> _completedActionsByDoseId =
      <String, Set<RobotFaceActionKind>>{};

  @override
  Widget build(BuildContext context) {
    final isMissedState = widget.state.mode == RobotFaceMode.missed;

    return DecoratedBox(
      key: RobotFaceScreen.actionPanelKey,
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
        padding: const EdgeInsets.all(8),
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
          label: 'Confirm taken',
          isEnabled: _isActionEnabled(RobotFaceActionKind.confirmTaken),
          onPressed: () {
            final occurredAt = DoseyAppScope.of(context).appClock.now().toUtc();
            unawaited(
              _logAction(
                context,
                actionKind: RobotFaceActionKind.confirmTaken,
                event: DoseLogEvent.doseTakenConfirmed(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: occurredAt,
                ),
                successMessage: 'Taken logged.',
              ),
            );
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
          onPressed: _isSubmitting || !isEnabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD94A66),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
      onPressed: _isSubmitting || !isEnabled ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
        false);
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

  Future<void> _logAction(
    BuildContext context, {
    required RobotFaceActionKind actionKind,
    required DoseLogEvent event,
    required String successMessage,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final actionDoseId = widget.state.actionDoseId;
    if (actionDoseId == null) {
      return;
    }

    if (_isTerminalAction(actionKind) && !await authorizeActionPin(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
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
          final completedActions = _completedActionsForDose(actionDoseId);
          if (_isTerminalAction(actionKind)) {
            // A terminal outcome resolves the dose; suppress every local action
            // until controller state rebuilds without the panel. This avoids a
            // brief second tap window while async streams catch up to the new
            // dose-log state.
            completedActions.addAll(widget.state.availableActions);
          } else {
            completedActions.add(actionKind);
          }
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
        setState(() => _isSubmitting = false);
      }
    }
  }
}
