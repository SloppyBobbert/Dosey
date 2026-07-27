import 'dart:async';
import 'dart:math' as math;

import 'package:dosey_app/features/robot_face/robot_face_animation.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';

RobotFaceControllerCondition? _effectiveControllerCondition(
  RobotFaceState state,
) {
  return switch (state.mode) {
    RobotFaceMode.offline => switch (state.controllerCondition) {
      RobotFaceControllerCondition.online => null,
      final condition => condition,
    },
    RobotFaceMode.error => switch (state.controllerCondition) {
      RobotFaceControllerCondition.bluetoothUnavailable ||
      RobotFaceControllerCondition.fault => state.controllerCondition,
      _ => RobotFaceControllerCondition.fault,
    },
    _ => null,
  };
}

bool _usesNetworkAdvisoryPalette(RobotFaceState state) =>
    state.mode == RobotFaceMode.idle &&
    state.networkAdvisory == RobotFaceNetworkAdvisory.internetOffline;

class RobotFaceCanvas extends StatefulWidget {
  const RobotFaceCanvas({
    super.key,
    required this.state,
    this.isActive = true,
    this.isPreparing = false,
    this.isSpeaking = false,
    this.animationCue,
    this.animationRevision = 0,
    this.onAnimationCompleted,
  });

  final RobotFaceState state;
  final bool isActive;
  final bool isPreparing;
  final bool isSpeaking;
  final RobotFaceAnimationCue? animationCue;
  final int animationRevision;
  final void Function(RobotFaceAnimationCue cue, int revision)?
  onAnimationCompleted;

  @override
  State<RobotFaceCanvas> createState() => _RobotFaceCanvasState();
}

class _RobotFaceCanvasState extends State<RobotFaceCanvas>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _cueController;
  int _resumeGeneration = 0;
  bool _disableAnimations = false;
  bool _hasBoundDependencies = false;
  RobotFaceAnimationCue? _activeCue;
  RobotFaceAnimationCue? _requestedCue;
  RobotFaceAnimationCue? _outgoingCue;
  double _outgoingCueProgress = 0;
  int _activeCueRevision = 0;
  Timer? _reducedMotionCueTimer;

  static const _ambientDuration = Duration(milliseconds: 5200);
  static const _speakingDuration = Duration(milliseconds: 920);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForWidget(widget),
    );
    _cueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _syncAnimationActivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final changed = _disableAnimations != disableAnimations;
    _disableAnimations = disableAnimations;
    if (changed) {
      _syncAnimationActivity();
      if (_activeCue != null) {
        _startCue(_requestedCue!, _activeCueRevision);
      }
    }
    if (!_hasBoundDependencies) {
      _hasBoundDependencies = true;
      final cue = widget.animationCue;
      if (cue != null && widget.animationRevision > 0) {
        _startCue(cue, widget.animationRevision);
      }
    }
  }

  @override
  void didUpdateWidget(covariant RobotFaceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) {
      _cancelCue();
    } else if (oldWidget.animationRevision != widget.animationRevision) {
      final cue = widget.animationCue;
      if (cue == null) {
        _cancelCue();
      } else {
        _startCue(cue, widget.animationRevision);
      }
    } else {
      final transitionCue = robotFaceTransitionCue(
        oldWidget.state,
        widget.state,
      );
      if (transitionCue != null) {
        _startCue(transitionCue, widget.animationRevision);
      }
    }
    if (oldWidget.isSpeaking != widget.isSpeaking ||
        oldWidget.state.mode != widget.state.mode ||
        oldWidget.state.controllerCondition !=
            widget.state.controllerCondition) {
      _controller.duration = _durationForWidget(widget);
      _controller.stop(canceled: false);
      _controller.value = _controller.lowerBound;
      _syncAnimationActivity();
    } else if (oldWidget.isActive != widget.isActive) {
      _syncAnimationActivity();
    }
  }

  void _syncAnimationActivity() {
    _resumeGeneration += 1;

    if (widget.isActive && !_disableAnimations) {
      if (_controller.isAnimating) {
        return;
      }

      if (_controller.value == _controller.lowerBound) {
        _controller.repeat();
        return;
      }

      final remainingFraction =
          (_controller.upperBound - _controller.value) /
          (_controller.upperBound - _controller.lowerBound);
      final baseDuration = _controller.duration;

      if (baseDuration == null) {
        _controller.repeat();
        return;
      }

      final remainingDuration = Duration(
        microseconds: (baseDuration.inMicroseconds * remainingFraction).round(),
      );
      final resumeGeneration = _resumeGeneration;
      // Resume the current cycle before repeating, so tab switches do not snap
      // the eyes back to the start of the animation.
      _controller
          .animateTo(
            _controller.upperBound,
            duration: remainingDuration,
            curve: Curves.linear,
          )
          .whenCompleteOrCancel(() {
            if (!mounted ||
                !widget.isActive ||
                _controller.isAnimating ||
                resumeGeneration != _resumeGeneration) {
              return;
            }
            _controller
              ..value = _controller.lowerBound
              ..repeat();
          });
      return;
    }

    _controller.stop(canceled: false);
  }

  double get debugPhase => _controller.value;
  Duration get debugAnimationDuration => _controller.duration!;
  bool get debugIsAnimating => _controller.isAnimating;
  RobotFaceAnimationCue? get debugActiveCue => _activeCue;
  bool get debugIsCueAnimating => _cueController.isAnimating;
  double get debugCueProgress => _cueProgress;
  RobotFaceControllerCondition? get debugEffectiveControllerCondition =>
      _effectiveControllerCondition(widget.state);
  bool get debugUsesNetworkAdvisoryPalette =>
      _usesNetworkAdvisoryPalette(widget.state);

  static Duration _durationForWidget(RobotFaceCanvas widget) {
    if (widget.isSpeaking) return _speakingDuration;
    return switch (_effectiveControllerCondition(widget.state)) {
      RobotFaceControllerCondition.connecting => const Duration(
        milliseconds: 3600,
      ),
      RobotFaceControllerCondition.verifying => const Duration(
        milliseconds: 2200,
      ),
      RobotFaceControllerCondition.reconnecting => const Duration(
        milliseconds: 1800,
      ),
      RobotFaceControllerCondition.bluetoothUnavailable => const Duration(
        milliseconds: 2600,
      ),
      RobotFaceControllerCondition.fault => const Duration(milliseconds: 1600),
      _ => _ambientDuration,
    };
  }

  double get _cueProgress {
    if (_activeCue == null) return 0;
    return _disableAnimations ? 0.62 : _cueController.value;
  }

  void _startCue(RobotFaceAnimationCue cue, int revision) {
    if (!widget.isActive) {
      _cancelCue();
      return;
    }

    final effectiveCue = safeRobotFaceAnimationCue(cue, widget.state);
    if (!_disableAnimations && _activeCue != null) {
      _outgoingCue = _activeCue;
      _outgoingCueProgress = _cueController.value;
    } else {
      _outgoingCue = null;
      _outgoingCueProgress = 0;
    }
    _requestedCue = cue;
    _activeCue = effectiveCue;
    _activeCueRevision = revision;
    _reducedMotionCueTimer?.cancel();
    _cueController
      ..stop(canceled: false)
      ..duration = _durationForCue(effectiveCue)
      ..value = _cueController.lowerBound;

    if (_disableAnimations) {
      _reducedMotionCueTimer = Timer(_durationForCue(effectiveCue), () {
        _completeCue(effectiveCue, revision);
      });
      return;
    }

    _cueController.forward().whenCompleteOrCancel(() {
      if (!mounted ||
          _disableAnimations ||
          _activeCue != effectiveCue ||
          _activeCueRevision != revision ||
          _cueController.status != AnimationStatus.completed) {
        return;
      }
      _completeCue(effectiveCue, revision);
    });
  }

  void _completeCue(RobotFaceAnimationCue effectiveCue, int revision) {
    if (!mounted ||
        _activeCue != effectiveCue ||
        _activeCueRevision != revision) {
      return;
    }
    final completedCue = _requestedCue!;
    setState(() {
      _activeCue = null;
      _requestedCue = null;
      _outgoingCue = null;
      _outgoingCueProgress = 0;
    });
    widget.onAnimationCompleted?.call(completedCue, revision);
  }

  void _cancelCue() {
    _reducedMotionCueTimer?.cancel();
    _reducedMotionCueTimer = null;
    _cueController
      ..stop(canceled: false)
      ..value = _cueController.lowerBound;
    _activeCue = null;
    _requestedCue = null;
    _outgoingCue = null;
    _outgoingCueProgress = 0;
  }

  static Duration _durationForCue(RobotFaceAnimationCue cue) => switch (cue) {
    RobotFaceAnimationCue.wake => const Duration(milliseconds: 900),
    RobotFaceAnimationCue.acknowledge => const Duration(milliseconds: 620),
    RobotFaceAnimationCue.notice => const Duration(milliseconds: 720),
    RobotFaceAnimationCue.focus => const Duration(milliseconds: 640),
    RobotFaceAnimationCue.track => const Duration(milliseconds: 880),
    RobotFaceAnimationCue.celebrate => const Duration(milliseconds: 920),
    RobotFaceAnimationCue.concern => const Duration(milliseconds: 820),
    RobotFaceAnimationCue.recover => const Duration(milliseconds: 780),
  };

  @override
  void dispose() {
    _reducedMotionCueTimer?.cancel();
    _controller.dispose();
    _cueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isSpeaking ? 'Robot is speaking' : null,
      liveRegion: widget.isSpeaking,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_controller, _cueController]),
        builder: (context, child) {
          return CustomPaint(
            painter: _RobotFacePainter(
              state: widget.state,
              phase: _controller.value,
              isPreparing: widget.isPreparing,
              isSpeaking: widget.isSpeaking,
              reducedMotion: _disableAnimations,
              animationCue: _activeCue,
              cueProgress: _cueProgress,
              outgoingCue: _outgoingCue,
              outgoingCueProgress: _outgoingCueProgress,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _RobotFacePainter extends CustomPainter {
  const _RobotFacePainter({
    required this.state,
    required this.phase,
    required this.isPreparing,
    required this.isSpeaking,
    required this.reducedMotion,
    required this.animationCue,
    required this.cueProgress,
    this.outgoingCue,
    this.outgoingCueProgress = 0,
  });

  final RobotFaceState state;
  final double phase;
  final bool isPreparing;
  final bool isSpeaking;
  final bool reducedMotion;
  final RobotFaceAnimationCue? animationCue;
  final double cueProgress;
  final RobotFaceAnimationCue? outgoingCue;
  final double outgoingCueProgress;

  List<Color> get debugPaletteColors {
    final palette = _palette;
    return <Color>[
      palette.backgroundTop,
      palette.backgroundBottom,
      palette.eyeTop,
      palette.eyeBottom,
    ];
  }

  List<Rect> debugBaseEyeRects(Size size) =>
      _baseEyeRects(size, centerY: size.height * 0.48);

  List<Rect> debugAmbientGlowRects(Size size) => _ambientGlowRects(size);

  Map<String, Object> debugMotionFrame(
    Size size, {
    double? phase,
    double? cueProgress,
  }) {
    final frame = _motionFrameFor(
      size,
      phase: phase ?? this.phase,
      cueProgress: cueProgress ?? this.cueProgress,
    );
    final baseEyes = _baseEyeRects(size, centerY: size.height * 0.48);
    return <String, Object>{
      'baseAspectRatio': baseEyes.first.width / baseEyes.first.height,
      'eyeOffset': frame.eyeOffset,
      'eyeLift': frame.cue.eyeLift,
      'blink': frame.blink,
      'leftTilt': frame.concernTilt * -1,
      'rightTilt': frame.concernTilt,
      'leftGlowBoost': frame.glowBoost,
    };
  }

  _FacePalette get _palette {
    final controllerCondition = _effectiveControllerCondition(state);
    return controllerCondition == null
        ? _usesNetworkAdvisoryPalette(state)
              ? _networkAdvisoryPalette
              : _paletteFor(state.mode)
        : _controllerPaletteFor(controllerCondition);
  }

  List<Rect> _baseEyeRects(Size size, {required double centerY}) {
    const eyeAspectRatio = 0.79;
    final eyeHeight = math.min(
      size.shortestSide * 0.34,
      math.min(size.height * 0.58, size.width / 2.1),
    );
    final eyeWidth = eyeHeight * eyeAspectRatio;
    final eyeOffset = eyeHeight * 0.55;
    return <Rect>[
      Rect.fromCenter(
        center: Offset(size.width * 0.5 - eyeOffset, centerY),
        width: eyeWidth,
        height: eyeHeight,
      ),
      Rect.fromCenter(
        center: Offset(size.width * 0.5 + eyeOffset, centerY),
        width: eyeWidth,
        height: eyeHeight,
      ),
    ];
  }

  List<Rect> _ambientGlowRects(Size size) {
    final radius = size.shortestSide * 0.32;
    return _baseEyeRects(size, centerY: size.height * 0.48)
        .map((eye) => Rect.fromCircle(center: eye.center, radius: radius))
        .toList(growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final controllerCondition = _effectiveControllerCondition(state);
    final motion = _motionProfileFor(state, size);
    final frame = _motionFrameFor(size);
    final speakingPulse = isSpeaking
        ? reducedMotion
              ? 0.55
              : (math.sin(phase * math.pi * 2) + 1) / 2
        : 0.0;
    final breathing =
        1 +
        math.sin(phase * math.pi * 2) * motion.breathingAmplitude +
        (speakingPulse * 0.035) +
        frame.cue.eyeScale;
    final pulse = _pulseValue();

    final palette = _palette;
    final concernTilt = frame.concernTilt;
    // Keep expression changes in the eyes only. Robot Mode intentionally has no
    // mouth so status color, tilt, blink, and glow carry the state.
    final eyelidOpen =
        (_eyelidOpenFor(state, frame.blink, phase, controllerCondition) +
                frame.cue.eyelidBoost)
            .clamp(0.12, 1.08);

    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    _paintDisplayTexture(canvas, size, palette, state, pulse);

    for (final glow in _ambientGlowRects(size)) {
      _paintGlowOrb(
        canvas,
        center: glow.center,
        radius: glow.width * 0.5,
        color: palette.glow.withValues(
          alpha: 0.14 + motion.glowBoost + frame.ambientGlowPulse,
        ),
      );
    }

    if (motion.wakeAura > 0) {
      _paintWakeAura(canvas, size, palette, motion.wakeAura, pulse);
    }

    if (state.mode == RobotFaceMode.sleepy) {
      _paintSleepVeil(canvas, size, phase);
    }

    final baseEyes = _baseEyeRects(
      size,
      centerY:
          size.height * (0.48 - motion.eyeLift - frame.cue.eyeLift) +
          motion.idleDrift,
    );
    final eyeWidth = baseEyes.first.width * breathing;
    final eyeHeight = baseEyes.first.height * eyelidOpen;
    final eyeRadius = Radius.circular(math.max(26, eyeHeight * 0.42));

    final leftEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: baseEyes.first.center + frame.eyeOffset,
        width: eyeWidth,
        height: math.max(28, eyeHeight),
      ),
      eyeRadius,
    );
    final rightEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: baseEyes[1].center + frame.eyeOffset,
        width: eyeWidth,
        height: math.max(28, eyeHeight),
      ),
      eyeRadius,
    );

    final attentionRingStrength = math.max(
      math.max(motion.attentionRingStrength, frame.cue.attentionRingStrength),
      isSpeaking
          ? 0.38 + (speakingPulse * 0.34)
          : isPreparing
          ? 0.28
          : 0.0,
    );
    if (attentionRingStrength > 0) {
      _paintAttentionRing(
        canvas,
        leftEye.outerRect,
        palette,
        pulse,
        attentionRingStrength,
      );
      _paintAttentionRing(
        canvas,
        rightEye.outerRect,
        palette,
        pulse,
        attentionRingStrength,
      );
    }

    _paintEye(
      canvas,
      leftEye,
      palette,
      concernTilt * -1,
      motion.glowBoost +
          frame.cue.glowBoost +
          (isPreparing ? 0.08 : 0) +
          (speakingPulse * 0.14),
    );
    _paintEye(
      canvas,
      rightEye,
      palette,
      concernTilt,
      motion.glowBoost +
          frame.cue.glowBoost +
          (isPreparing ? 0.08 : 0) +
          (speakingPulse * 0.14),
    );

    _paintDisplayVignette(canvas, rect, state);
  }

  void _paintEye(
    Canvas canvas,
    RRect eye,
    _FacePalette palette,
    double tilt,
    double glowBoost,
  ) {
    canvas.save();
    canvas.translate(eye.center.dx, eye.center.dy);
    canvas.rotate(tilt);
    canvas.translate(-eye.center.dx, -eye.center.dy);

    final outerGlow = Paint()
      ..color = palette.glow.withValues(alpha: 0.24 + glowBoost)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 42 + (glowBoost * 24));
    canvas.drawRRect(eye.inflate(14), outerGlow);

    final shellPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[palette.eyeTop, palette.eyeBottom],
      ).createShader(eye.outerRect);
    canvas.drawRRect(eye, shellPaint);

    final innerFrame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawRRect(eye.deflate(1), innerFrame);

    canvas.restore();
  }

  void _paintGlowOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);
  }

  void _paintAttentionRing(
    Canvas canvas,
    Rect eyeRect,
    _FacePalette palette,
    double pulse,
    double strength,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + (strength * 2.5) + (pulse * strength * 2.5)
      ..color = palette.accent.withValues(
        alpha: 0.08 + (strength * 0.12) + (pulse * strength * 0.16),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        eyeRect.inflate(10 + (strength * 12) + (pulse * strength * 10)),
        Radius.circular(eyeRect.height),
      ),
      ringPaint,
    );
  }

  void _paintWakeAura(
    Canvas canvas,
    Size size,
    _FacePalette palette,
    double intensity,
    double pulse,
  ) {
    final auraRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.3),
      width: size.width * 0.72,
      height: size.height * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(auraRect, Radius.circular(auraRect.height)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            palette.accent.withValues(alpha: 0),
            palette.accent.withValues(alpha: 0.04 + (intensity * 0.08)),
            palette.accent.withValues(alpha: 0),
          ],
          stops: <double>[0, 0.5 + (pulse * 0.05), 1],
        ).createShader(auraRect),
    );
  }

  void _paintDisplayTexture(
    Canvas canvas,
    Size size,
    _FacePalette palette,
    RobotFaceState state,
    double pulse,
  ) {
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.62);
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(
              alpha: state.mode == RobotFaceMode.sleepy ? 0.03 : 0.05,
            ),
            Colors.transparent,
          ],
        ).createShader(sheenRect),
    );

    if (state.mode == RobotFaceMode.sleepy) {
      final restBand = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.82),
        width: size.width * 0.6,
        height: size.height * 0.06,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(restBand, Radius.circular(restBand.height)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              palette.accent.withValues(alpha: 0),
              palette.accent.withValues(alpha: 0.16 + (pulse * 0.04)),
              palette.accent.withValues(alpha: 0),
            ],
          ).createShader(restBand),
      );
    }

    if (state.mode == RobotFaceMode.idle && state.isInAwakeWindow) {
      final awakeRect = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.18),
        width: size.width * 0.84,
        height: size.height * 0.16,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(awakeRect, Radius.circular(awakeRect.height)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              palette.glow.withValues(alpha: 0),
              palette.glow.withValues(alpha: 0.12 + (pulse * 0.04)),
              palette.glow.withValues(alpha: 0),
            ],
          ).createShader(awakeRect),
      );
    }
  }

  void _paintSleepVeil(Canvas canvas, Size size, double phase) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFF02040A).withValues(alpha: 0.12),
            const Color(0xFF02040A).withValues(alpha: 0.34),
            const Color(0xFF02040A).withValues(alpha: 0.58),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(rect),
    );

    final starPaint = Paint()
      ..color = const Color(0xFFD8E4FF).withValues(alpha: 0.2);
    final drift = math.sin(phase * math.pi * 2) * size.width * 0.008;
    final stars = <Offset>[
      Offset(size.width * 0.24 + drift, size.height * 0.2),
      Offset(size.width * 0.52 - drift * 0.6, size.height * 0.14),
      Offset(size.width * 0.76 + drift * 0.4, size.height * 0.22),
    ];

    for (final star in stars) {
      canvas.drawCircle(star, 2.4, starPaint);
      canvas.drawCircle(
        star,
        10,
        Paint()..color = const Color(0xFFA8BAFF).withValues(alpha: 0.05),
      );
    }
  }

  void _paintDisplayVignette(Canvas canvas, Rect rect, RobotFaceState state) {
    final edgeAlpha = switch (state.mode) {
      RobotFaceMode.missed => 0.08,
      RobotFaceMode.sleepy => 0.28,
      RobotFaceMode.idle when state.isInAwakeWindow => 0.12,
      _ => 0.16,
    };

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.92,
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF010204).withValues(alpha: edgeAlpha),
          ],
          stops: const <double>[0.58, 1],
        ).createShader(rect),
    );
  }

  double _blinkValue(double phase) {
    double blinkAt(double center, double halfWidth) =>
        (1 - ((phase - center).abs() / halfWidth)).clamp(0.0, 1.0);
    return math.max(
      math.max(blinkAt(0.18, 0.018), blinkAt(0.23, 0.018)),
      blinkAt(0.7, 0.022),
    );
  }

  double _pulseValue() {
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    return Curves.easeOut.transform(pulse);
  }

  _FaceCueFrame _cueFrameFor(
    RobotFaceAnimationCue? cue,
    double progress,
    Size size,
  ) {
    if (cue == null) return const _FaceCueFrame();
    final normalized = progress.clamp(0.0, 1.0);
    final envelope = math.sin(normalized * math.pi);
    final settle = Curves.easeOutCubic.transform(normalized);
    return switch (cue) {
      RobotFaceAnimationCue.wake => _FaceCueFrame(
        eyelidBoost: (1 - settle) * -0.32 + envelope * 0.12,
        eyeLift: envelope * 0.034,
        eyeScale: envelope * 0.052,
        attentionRingStrength: envelope * 0.38,
        glowBoost: envelope * 0.12,
      ),
      RobotFaceAnimationCue.acknowledge => _FaceCueFrame(
        eyeLift: envelope * 0.018,
        eyeOffset: Offset(0, -size.height * 0.018 * envelope),
        attentionRingStrength: envelope * 0.32,
        glowBoost: envelope * 0.1,
      ),
      RobotFaceAnimationCue.notice => _FaceCueFrame(
        eyelidBoost: envelope * 0.08,
        eyeOffset: Offset(0, -size.height * 0.026 * envelope),
        attentionRingStrength: envelope * 0.42,
        glowBoost: envelope * 0.12,
      ),
      RobotFaceAnimationCue.focus => _FaceCueFrame(
        eyelidBoost: envelope * -0.1,
        eyeLift: envelope * 0.016,
        eyeScale: envelope * 0.025,
        attentionRingStrength: envelope * 0.62,
        glowBoost: envelope * 0.16,
      ),
      RobotFaceAnimationCue.track => _FaceCueFrame(
        eyeOffset: Offset(
          math.sin(progress * math.pi * 2) * size.width * 0.026,
          -size.height * 0.006 * envelope,
        ),
        attentionRingStrength: envelope * 0.42,
        glowBoost: envelope * 0.1,
      ),
      RobotFaceAnimationCue.celebrate => () {
        final firstBounce = normalized <= 0.48
            ? math.sin((normalized / 0.48) * math.pi)
            : 0.0;
        final secondBounce = normalized >= 0.48
            ? math.sin(((normalized - 0.48) / 0.52) * math.pi) * 0.7
            : 0.0;
        final bounce = math.max(firstBounce, secondBounce);
        return _FaceCueFrame(
          eyelidBoost: bounce * 0.12,
          eyeLift: bounce * 0.052,
          eyeScale: bounce * 0.078,
          attentionRingStrength: bounce * 0.72,
          glowBoost: bounce * 0.2,
        );
      }(),
      RobotFaceAnimationCue.concern => _FaceCueFrame(
        eyeLift: envelope * -0.014,
        eyeOffset: Offset(0, size.height * 0.012 * envelope),
        concernTilt: envelope * 0.045,
        attentionRingStrength: envelope * 0.28,
        glowBoost: envelope * 0.08,
      ),
      RobotFaceAnimationCue.recover => _FaceCueFrame(
        eyelidBoost: (1 - settle) * -0.12 + envelope * 0.08,
        eyeLift: envelope * 0.02,
        eyeScale: envelope * 0.035,
        attentionRingStrength: envelope * 0.46,
        glowBoost: envelope * 0.14,
      ),
    };
  }

  _FaceMotionFrame _motionFrameFor(
    Size size, {
    double? phase,
    double? cueProgress,
  }) {
    final framePhase = reducedMotion ? 0.0 : phase ?? this.phase;
    final frameCueProgress = cueProgress ?? this.cueProgress;
    final incomingCue = _cueFrameFor(animationCue, frameCueProgress, size);
    final cue = outgoingCue == null || reducedMotion
        ? incomingCue
        : _FaceCueFrame.lerp(
            _cueFrameFor(outgoingCue, outgoingCueProgress, size),
            incomingCue,
            Curves.easeOutCubic.transform(
              (frameCueProgress / 0.2).clamp(0.0, 1.0),
            ),
          );
    final controllerCondition = _effectiveControllerCondition(state);
    final safetyFace =
        state.mode == RobotFaceMode.missed ||
        state.mode == RobotFaceMode.error ||
        controllerCondition == RobotFaceControllerCondition.fault;
    final strictlySuppressIdlePersonality =
        reducedMotion || safetyFace || isPreparing || isSpeaking;
    final cueExitWeight = animationCue == null
        ? 1.0
        : Curves.easeInOutCubic.transform(
            ((frameCueProgress - 0.65) / 0.35).clamp(0.0, 1.0),
          );
    final ambientWeight = strictlySuppressIdlePersonality ? 0.0 : cueExitWeight;
    final ambientOffset =
        _eyeOffsetFor(state, size, framePhase, controllerCondition) *
        ambientWeight;
    final glowPulse =
        ((math.sin(framePhase * math.pi * 2) + 1) / 2) * 0.035 * ambientWeight;
    return _FaceMotionFrame(
      cue: cue,
      eyeOffset: ambientOffset + cue.eyeOffset,
      blink: _blinkValue(framePhase) * ambientWeight,
      concernTilt:
          _concernTiltFor(state.mode, controllerCondition) + cue.concernTilt,
      ambientGlowPulse: glowPulse,
      glowBoost: cue.glowBoost + glowPulse,
    );
  }

  double _eyelidOpenFor(
    RobotFaceState state,
    double blink,
    double phase,
    RobotFaceControllerCondition? controllerCondition,
  ) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);
    final awakeLift = state.isInAwakeWindow ? 0.04 : 0.0;
    final liveLift = state.mode == RobotFaceMode.idle
        ? ((math.sin(phase * math.pi * 2) + 1) / 2) * 0.03
        : 0.0;
    // Lower lids communicate sleepy/offline/warning states without adding a
    // mouth or extra facial features.
    final base = switch (controllerCondition) {
      RobotFaceControllerCondition.disconnected => 0.42,
      RobotFaceControllerCondition.connecting => 0.72,
      RobotFaceControllerCondition.verifying => 0.94,
      RobotFaceControllerCondition.offline => 0.5,
      RobotFaceControllerCondition.reconnecting => 0.8,
      RobotFaceControllerCondition.bluetoothUnavailable => 0.48,
      RobotFaceControllerCondition.fault => 0.4,
      _ => switch (state.mode) {
        RobotFaceMode.sleepy => 0.22,
        RobotFaceMode.offline => 0.54,
        RobotFaceMode.error || RobotFaceMode.missed => 0.46,
        RobotFaceMode.happyConfirmed => 1.08,
        RobotFaceMode.doseApproaching => 1.0 + awakeLift + (ramp * 0.06),
        RobotFaceMode.doseReady => 1.06,
        RobotFaceMode.dispensing => 0.92,
        RobotFaceMode.waitingForConfirmation => 0.9 + awakeLift,
        RobotFaceMode.idle => 0.94 + awakeLift + liveLift,
      },
    };
    return (base - blink * 0.94).clamp(0.12, 1.08);
  }

  double _concernTiltFor(
    RobotFaceMode mode,
    RobotFaceControllerCondition? controllerCondition,
  ) {
    return switch (controllerCondition) {
      RobotFaceControllerCondition.disconnected => 0.045,
      RobotFaceControllerCondition.offline => 0.07,
      RobotFaceControllerCondition.bluetoothUnavailable => 0.09,
      RobotFaceControllerCondition.fault => 0.13,
      _ => switch (mode) {
        RobotFaceMode.error => 0.1,
        RobotFaceMode.offline => 0.06,
        RobotFaceMode.missed => 0.08,
        _ => 0,
      },
    };
  }

  Offset _eyeOffsetFor(
    RobotFaceState state,
    Size size,
    double phase,
    RobotFaceControllerCondition? controllerCondition,
  ) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);
    final horizontal = math.sin(phase * math.pi * 2) * size.width * 0.012;
    final idleVertical = math.sin(phase * math.pi * 4) * size.height * 0.003;

    return switch (controllerCondition) {
      RobotFaceControllerCondition.disconnected => Offset(
        0,
        size.height * 0.018,
      ),
      RobotFaceControllerCondition.connecting => Offset(
        horizontal * 1.4,
        size.height * 0.004,
      ),
      RobotFaceControllerCondition.verifying => Offset(0, -size.height * 0.012),
      RobotFaceControllerCondition.offline => Offset(
        -size.width * 0.008,
        size.height * 0.014,
      ),
      RobotFaceControllerCondition.reconnecting => Offset(
        horizontal * 2.1,
        -size.height * 0.004,
      ),
      RobotFaceControllerCondition.bluetoothUnavailable => Offset(
        0,
        size.height * 0.008,
      ),
      RobotFaceControllerCondition.fault => Offset(
        size.width * 0.014,
        size.height * 0.01,
      ),
      _ => switch (state.mode) {
        RobotFaceMode.sleepy => Offset(
          -size.width * 0.012,
          size.height * 0.012,
        ),
        RobotFaceMode.doseApproaching => Offset(
          horizontal * (0.35 - (ramp * 0.2)),
          -size.height * (0.01 + (ramp * 0.012)),
        ),
        RobotFaceMode.doseReady => Offset(0, -size.height * 0.024),
        RobotFaceMode.dispensing => Offset(
          horizontal * 0.2,
          -size.height * 0.016 +
              math.sin(phase * math.pi * 4) * size.height * 0.008,
        ),
        RobotFaceMode.waitingForConfirmation => Offset(
          horizontal * 0.18,
          -size.height * 0.014,
        ),
        RobotFaceMode.happyConfirmed => Offset(
          horizontal * 0.3,
          -size.height * 0.022,
        ),
        RobotFaceMode.error => Offset(size.width * 0.008, size.height * 0.006),
        RobotFaceMode.offline => Offset(
          -size.width * 0.006,
          size.height * 0.01,
        ),
        RobotFaceMode.idle when state.isInAwakeWindow => _idlePersonalityOffset(
          size,
          phase,
        ),
        _ => Offset(horizontal, idleVertical),
      },
    };
  }

  Offset _idlePersonalityOffset(Size size, double phase) {
    double transition(double start, double end) {
      final progress = ((phase - start) / (end - start)).clamp(0.0, 1.0);
      return Curves.easeInOutCubic.transform(progress);
    }

    final horizontal = switch (phase) {
      < 0.18 => 0.0,
      < 0.30 => transition(0.18, 0.30),
      < 0.40 => 1.0,
      < 0.52 => 1 - transition(0.40, 0.52),
      < 0.64 => -transition(0.52, 0.64),
      < 0.72 => -1.0,
      < 0.86 => -1 + transition(0.72, 0.86),
      _ => 0.0,
    };
    final glanceLift = horizontal.abs() * size.height * 0.002;
    return Offset(
      horizontal * size.width * 0.012,
      -size.height * 0.012 - glanceLift,
    );
  }

  _FaceMotionProfile _motionProfileFor(RobotFaceState state, Size size) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);
    final controllerCondition = _effectiveControllerCondition(state);

    final controllerMotion = switch (controllerCondition) {
      RobotFaceControllerCondition.disconnected => const _FaceMotionProfile(
        breathingAmplitude: 0.006,
        glowBoost: 0,
        eyeLift: -0.014,
        attentionRingStrength: 0,
        wakeAura: 0,
        idleDrift: 0,
      ),
      RobotFaceControllerCondition.connecting => _FaceMotionProfile(
        breathingAmplitude: 0.01,
        glowBoost: 0.05,
        eyeLift: 0,
        attentionRingStrength: 0.22,
        wakeAura: 0.18,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.003,
      ),
      RobotFaceControllerCondition.verifying => const _FaceMotionProfile(
        breathingAmplitude: 0.012,
        glowBoost: 0.13,
        eyeLift: 0.012,
        attentionRingStrength: 0.48,
        wakeAura: 0.42,
        idleDrift: 0,
      ),
      RobotFaceControllerCondition.offline => const _FaceMotionProfile(
        breathingAmplitude: 0.006,
        glowBoost: 0.01,
        eyeLift: -0.008,
        attentionRingStrength: 0,
        wakeAura: 0,
        idleDrift: 0,
      ),
      RobotFaceControllerCondition.reconnecting => _FaceMotionProfile(
        breathingAmplitude: 0.014,
        glowBoost: 0.1,
        eyeLift: 0.006,
        attentionRingStrength: 0.55,
        wakeAura: 0.48,
        idleDrift: math.sin(phase * math.pi * 4) * size.height * 0.005,
      ),
      RobotFaceControllerCondition.bluetoothUnavailable =>
        const _FaceMotionProfile(
          breathingAmplitude: 0.008,
          glowBoost: 0.16,
          eyeLift: -0.006,
          attentionRingStrength: 0.52,
          wakeAura: 0.22,
          idleDrift: 0,
        ),
      RobotFaceControllerCondition.fault => _FaceMotionProfile(
        breathingAmplitude: 0.01,
        glowBoost: 0.22,
        eyeLift: -0.01,
        attentionRingStrength: 0.72,
        wakeAura: 0.32,
        idleDrift: math.sin(phase * math.pi * 4) * size.height * 0.004,
      ),
      _ => null,
    };
    if (controllerMotion != null) return controllerMotion;

    return switch (state.mode) {
      RobotFaceMode.doseApproaching => _FaceMotionProfile(
        breathingAmplitude: 0.02 - (ramp * 0.004),
        glowBoost: 0.08 + (ramp * 0.12),
        eyeLift: 0.008 + (ramp * 0.018),
        attentionRingStrength: 0.25 + (ramp * 0.45),
        wakeAura: state.isInAwakeWindow ? 0.5 + (ramp * 0.35) : ramp * 0.35,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.004,
      ),
      RobotFaceMode.doseReady => _FaceMotionProfile(
        breathingAmplitude: 0.014,
        glowBoost: 0.26,
        eyeLift: 0.03,
        attentionRingStrength: 1,
        wakeAura: 1,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.003,
      ),
      RobotFaceMode.dispensing => _FaceMotionProfile(
        breathingAmplitude: 0.01,
        glowBoost: 0.3,
        eyeLift: 0.024,
        attentionRingStrength: 0.82,
        wakeAura: 0.92,
        idleDrift: math.sin(phase * math.pi * 4) * size.height * 0.008,
      ),
      RobotFaceMode.waitingForConfirmation => _FaceMotionProfile(
        breathingAmplitude: 0.016,
        glowBoost: 0.14,
        eyeLift: 0.016,
        attentionRingStrength: 0.46,
        wakeAura: 0.5,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.002,
      ),
      RobotFaceMode.idle when state.isInAwakeWindow => _FaceMotionProfile(
        breathingAmplitude: 0.02,
        glowBoost: 0.1,
        eyeLift: 0.014,
        attentionRingStrength: 0.24,
        wakeAura: 0.52,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.006,
      ),
      RobotFaceMode.idle => _FaceMotionProfile(
        breathingAmplitude: 0.022,
        glowBoost: 0.03,
        eyeLift: 0,
        attentionRingStrength: 0,
        wakeAura: 0,
        idleDrift: math.sin(phase * math.pi * 2) * size.height * 0.005,
      ),
      _ => _FaceMotionProfile(
        breathingAmplitude: 0.018,
        glowBoost: 0.04,
        eyeLift: 0,
        attentionRingStrength: 0,
        wakeAura: 0,
        idleDrift: 0,
      ),
    };
  }

  _FacePalette _paletteFor(RobotFaceMode mode) {
    // Ready and waiting states stay on the same green/teal path so follow-up
    // feels like one safe dose-resolution flow, not a new robot state.
    return switch (mode) {
      RobotFaceMode.sleepy => const _FacePalette(
        backgroundTop: Color(0xFF11172A),
        backgroundBottom: Color(0xFF04070D),
        eyeTop: Color(0xFFB8C8EE),
        eyeBottom: Color(0xFF3B4E73),
        glow: Color(0xFF6E86B8),
        accent: Color(0xFF9AA8E8),
      ),
      RobotFaceMode.doseReady => const _FacePalette(
        backgroundTop: Color(0xFF08161A),
        backgroundBottom: Color(0xFF03080A),
        eyeTop: Color(0xFFA4FFE8),
        eyeBottom: Color(0xFF38CDAA),
        glow: Color(0xFF4BF3C8),
        accent: Color(0xFF6EEFD8),
      ),
      RobotFaceMode.waitingForConfirmation => const _FacePalette(
        backgroundTop: Color(0xFF09171A),
        backgroundBottom: Color(0xFF04090B),
        eyeTop: Color(0xFFD0FFF3),
        eyeBottom: Color(0xFF5ED8BA),
        glow: Color(0xFF68F3D2),
        accent: Color(0xFF8AF5E0),
      ),
      RobotFaceMode.doseApproaching => const _FacePalette(
        backgroundTop: Color(0xFF08141F),
        backgroundBottom: Color(0xFF03070B),
        eyeTop: Color(0xFF71F4FF),
        eyeBottom: Color(0xFF1797BE),
        glow: Color(0xFF2AE7FF),
        accent: Color(0xFF7EEDFF),
      ),
      RobotFaceMode.dispensing => const _FacePalette(
        backgroundTop: Color(0xFF08131E),
        backgroundBottom: Color(0xFF03070B),
        eyeTop: Color(0xFF67F0FF),
        eyeBottom: Color(0xFF0FA3D1),
        glow: Color(0xFF34EDFF),
        accent: Color(0xFF8BEFFF),
      ),
      RobotFaceMode.happyConfirmed => const _FacePalette(
        backgroundTop: Color(0xFF091A16),
        backgroundBottom: Color(0xFF04100E),
        eyeTop: Color(0xFF9DF9DB),
        eyeBottom: Color(0xFF38C4A2),
        glow: Color(0xFF56F0C7),
        accent: Color(0xFF83EFD4),
      ),
      RobotFaceMode.error || RobotFaceMode.missed => const _FacePalette(
        backgroundTop: Color(0xFF1D1013),
        backgroundBottom: Color(0xFF0A0607),
        eyeTop: Color(0xFFFFA0AD),
        eyeBottom: Color(0xFFCF5066),
        glow: Color(0xFFFF6C83),
        accent: Color(0xFFFFB366),
      ),
      RobotFaceMode.offline => const _FacePalette(
        backgroundTop: Color(0xFF14161D),
        backgroundBottom: Color(0xFF08090D),
        eyeTop: Color(0xFFB6C0D4),
        eyeBottom: Color(0xFF6E788D),
        glow: Color(0xFF94A4C8),
        accent: Color(0xFF8D93A7),
      ),
      _ => const _FacePalette(
        backgroundTop: Color(0xFF071A2D),
        backgroundBottom: Color(0xFF0B2940),
        eyeTop: Color(0xFF8BFFF3),
        eyeBottom: Color(0xFF36D9EA),
        glow: Color(0xFF62ECFF),
        accent: Color(0xFF8EEBFF),
      ),
    };
  }

  _FacePalette _controllerPaletteFor(RobotFaceControllerCondition condition) {
    return switch (condition) {
      RobotFaceControllerCondition.disconnected => const _FacePalette(
        backgroundTop: Color(0xFF11141A),
        backgroundBottom: Color(0xFF06070A),
        eyeTop: Color(0xFFAEB6C5),
        eyeBottom: Color(0xFF596171),
        glow: Color(0xFF7C879B),
        accent: Color(0xFF858C99),
      ),
      RobotFaceControllerCondition.connecting => const _FacePalette(
        backgroundTop: Color(0xFF0D1822),
        backgroundBottom: Color(0xFF05080C),
        eyeTop: Color(0xFFB8D9E8),
        eyeBottom: Color(0xFF5A8EA8),
        glow: Color(0xFF72BDD9),
        accent: Color(0xFF87CDE5),
      ),
      RobotFaceControllerCondition.verifying => const _FacePalette(
        backgroundTop: Color(0xFF081923),
        backgroundBottom: Color(0xFF03080C),
        eyeTop: Color(0xFFC7F8FF),
        eyeBottom: Color(0xFF52C5DD),
        glow: Color(0xFF55E4FF),
        accent: Color(0xFF8DEEFF),
      ),
      RobotFaceControllerCondition.offline => const _FacePalette(
        backgroundTop: Color(0xFF12141A),
        backgroundBottom: Color(0xFF06070A),
        eyeTop: Color(0xFFA7B0C0),
        eyeBottom: Color(0xFF5E6675),
        glow: Color(0xFF7E899E),
        accent: Color(0xFF838A99),
      ),
      RobotFaceControllerCondition.reconnecting => const _FacePalette(
        backgroundTop: Color(0xFF0B1722),
        backgroundBottom: Color(0xFF04080C),
        eyeTop: Color(0xFFC4E7F3),
        eyeBottom: Color(0xFF4E9DBB),
        glow: Color(0xFF61CBEA),
        accent: Color(0xFF82DDF4),
      ),
      RobotFaceControllerCondition.bluetoothUnavailable => const _FacePalette(
        backgroundTop: Color(0xFF1C1014),
        backgroundBottom: Color(0xFF090607),
        eyeTop: Color(0xFFFFB0BA),
        eyeBottom: Color(0xFFD85C70),
        glow: Color(0xFFFF7388),
        accent: Color(0xFFFF9A79),
      ),
      RobotFaceControllerCondition.fault => const _FacePalette(
        backgroundTop: Color(0xFF210E12),
        backgroundBottom: Color(0xFF0B0507),
        eyeTop: Color(0xFFFF929F),
        eyeBottom: Color(0xFFC83F57),
        glow: Color(0xFFFF536D),
        accent: Color(0xFFFFA15F),
      ),
      RobotFaceControllerCondition.online => _paletteFor(state.mode),
    };
  }

  static const _networkAdvisoryPalette = _FacePalette(
    backgroundTop: Color(0xFF211A0D),
    backgroundBottom: Color(0xFF0A0804),
    eyeTop: Color(0xFFFFE0A1),
    eyeBottom: Color(0xFFD99428),
    glow: Color(0xFFFFB84D),
    accent: Color(0xFFFFCC73),
  );

  @override
  bool shouldRepaint(covariant _RobotFacePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.phase != phase ||
        oldDelegate.isPreparing != isPreparing ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.reducedMotion != reducedMotion ||
        oldDelegate.animationCue != animationCue ||
        oldDelegate.cueProgress != cueProgress ||
        oldDelegate.outgoingCue != outgoingCue ||
        oldDelegate.outgoingCueProgress != outgoingCueProgress;
  }
}

class _FacePalette {
  const _FacePalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.eyeTop,
    required this.eyeBottom,
    required this.glow,
    required this.accent,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color eyeTop;
  final Color eyeBottom;
  final Color glow;
  final Color accent;
}

class _FaceMotionProfile {
  const _FaceMotionProfile({
    required this.breathingAmplitude,
    required this.glowBoost,
    required this.eyeLift,
    required this.attentionRingStrength,
    required this.wakeAura,
    required this.idleDrift,
  });

  final double breathingAmplitude;
  final double glowBoost;
  final double eyeLift;
  final double attentionRingStrength;
  final double wakeAura;
  final double idleDrift;
}

class _FaceCueFrame {
  const _FaceCueFrame({
    this.eyelidBoost = 0,
    this.eyeLift = 0,
    this.eyeScale = 0,
    this.eyeOffset = Offset.zero,
    this.concernTilt = 0,
    this.attentionRingStrength = 0,
    this.glowBoost = 0,
  });

  final double eyelidBoost;
  final double eyeLift;
  final double eyeScale;
  final Offset eyeOffset;
  final double concernTilt;
  final double attentionRingStrength;
  final double glowBoost;

  static _FaceCueFrame lerp(
    _FaceCueFrame begin,
    _FaceCueFrame end,
    double progress,
  ) {
    return _FaceCueFrame(
      eyelidBoost: _lerpDouble(begin.eyelidBoost, end.eyelidBoost, progress),
      eyeLift: _lerpDouble(begin.eyeLift, end.eyeLift, progress),
      eyeScale: _lerpDouble(begin.eyeScale, end.eyeScale, progress),
      eyeOffset: Offset.lerp(begin.eyeOffset, end.eyeOffset, progress)!,
      concernTilt: _lerpDouble(begin.concernTilt, end.concernTilt, progress),
      attentionRingStrength: _lerpDouble(
        begin.attentionRingStrength,
        end.attentionRingStrength,
        progress,
      ),
      glowBoost: _lerpDouble(begin.glowBoost, end.glowBoost, progress),
    );
  }

  static double _lerpDouble(double begin, double end, double progress) =>
      begin + (end - begin) * progress;
}

class _FaceMotionFrame {
  const _FaceMotionFrame({
    required this.cue,
    required this.eyeOffset,
    required this.blink,
    required this.concernTilt,
    required this.ambientGlowPulse,
    required this.glowBoost,
  });

  final _FaceCueFrame cue;
  final Offset eyeOffset;
  final double blink;
  final double concernTilt;
  final double ambientGlowPulse;
  final double glowBoost;
}
