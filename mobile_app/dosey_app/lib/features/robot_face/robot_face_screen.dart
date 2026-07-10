import 'dart:math' as math;

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/features/doses/dose_action_logger.dart';
import 'package:dosey_app/features/robot_face/robot_face_canvas.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
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
    this.stateStream,
    this.initialState,
    this.isActive = true,
    this.doseActionLogger,
  });

  static const canvasKey = ValueKey<String>('robot-face-canvas');
  static const bottomCardKey = ValueKey<String>('robot-face-bottom-card');
  static const flipTransformKey = ValueKey<String>('robot-face-flip-transform');
  static const urgentPromptKey = ValueKey<String>('robot-face-urgent-prompt');
  static const urgentPromptScaleKey = ValueKey<String>(
    'robot-face-urgent-prompt-scale',
  );
  static const statusBadgeKey = ValueKey<String>('robot-face-status-badge');
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

  final RobotFaceController? controller;
  final Stream<RobotFaceState>? stateStream;
  final RobotFaceState? initialState;
  final bool isActive;
  final RobotFaceDoseActionLogger? doseActionLogger;

  @override
  State<RobotFaceScreen> createState() => _RobotFaceScreenState();
}

class _RobotFaceScreenState extends State<RobotFaceScreen> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindStream();
  }

  @override
  void didUpdateWidget(covariant RobotFaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.stateStream != widget.stateStream ||
        oldWidget.initialState != widget.initialState) {
      _bindStream();
    }
  }

  void _bindStream() {
    _stateStream = widget.stateStream ?? widget.controller?.watchState();
    if (_stateStream == null && widget.initialState == null) {
      _stateStream = DoseyAppScope.of(context).robotFaceController.watchState();
    }
    _initialState = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04070D),
      body: StreamBuilder<RobotFaceState>(
        stream: _stateStream,
        initialData: _initialState ?? _fallbackState,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _fallbackState;
          return ColoredBox(
            color: const Color(0xFF04070D),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isPortraitFrame =
                      constraints.maxHeight > constraints.maxWidth;
                  Widget frame = _RobotFaceFrame(
                    state: state,
                    isActive: widget.isActive,
                    doseActionLogger: widget.doseActionLogger,
                  );

                  if (isPortraitFrame) {
                    frame = RotatedBox(quarterTurns: 1, child: frame);
                  }

                  return Center(child: frame);
                },
              ),
            ),
          );
        },
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
    this.doseActionLogger,
  });

  final RobotFaceState state;
  final bool isActive;
  final RobotFaceDoseActionLogger? doseActionLogger;

  @override
  Widget build(BuildContext context) {
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
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF43E7FF,
                            ).withValues(alpha: 0.12),
                            blurRadius: 50,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: SizedBox.expand(
                          key: RobotFaceScreen.canvasKey,
                          child: RobotFaceCanvas(
                            state: state,
                            isActive: isActive,
                          ),
                        ),
                      ),
                    ),
                    _UrgentPromptOverlay(state: state),
                  ],
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xC20B111B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 22,
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
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF8A96AD),
                        ),
                      ),
                      const SizedBox(height: 4),
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
      RobotFaceMode.error => 'Check robot',
      RobotFaceMode.offline => 'Reconnect needed',
      _ => statusLabel,
    };
  }

  double _badgeEmphasisFor(RobotFaceState state) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);

    return switch (state.mode) {
      RobotFaceMode.doseApproaching => 0.28 + (ramp * 0.52),
      RobotFaceMode.doseReady => 1,
      RobotFaceMode.idle when state.isInAwakeWindow => 0.24,
      _ => 0,
    };
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
    return DecoratedBox(
      key: RobotFaceScreen.actionPanelKey,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildActionButton(
              key: RobotFaceScreen.confirmTakenButtonKey,
              label: 'Confirm taken',
              isEnabled: _isActionEnabled(RobotFaceActionKind.confirmTaken),
              onPressed: () => _logAction(
                context,
                actionKind: RobotFaceActionKind.confirmTaken,
                event: DoseLogEvent.doseTakenConfirmed(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: DateTime.now().toUtc(),
                ),
                successMessage: 'Taken logged.',
              ),
            ),
            _buildActionButton(
              key: RobotFaceScreen.skipDoseButtonKey,
              label: 'Skip',
              isEnabled: _isActionEnabled(RobotFaceActionKind.skipDose),
              onPressed: () => _logAction(
                context,
                actionKind: RobotFaceActionKind.skipDose,
                event: DoseLogEvent.doseSkipped(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: DateTime.now().toUtc(),
                ),
                successMessage: 'Skip logged.',
              ),
            ),
            _buildActionButton(
              key: RobotFaceScreen.needHelpButtonKey,
              label: 'Need help',
              isEnabled: _isActionEnabled(RobotFaceActionKind.askForHelp),
              onPressed: () => _logAction(
                context,
                actionKind: RobotFaceActionKind.askForHelp,
                event: DoseLogEvent.caregiverHelpRequested(
                  doseId: widget.state.actionDoseId!,
                  occurredAt: DateTime.now().toUtc(),
                ),
                successMessage: 'Help request logged.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required Key key,
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonal(
      key: key,
      onPressed: _isSubmitting || !isEnabled ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
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
      RobotFaceActionKind.askForHelp => false,
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

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      final logged =
          await (widget.doseActionLogger ?? DoseActionLogger.logDoseAction)(
            context,
            event,
            successMessage,
          );
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
