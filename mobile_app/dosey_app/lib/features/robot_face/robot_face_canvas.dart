import 'dart:math' as math;

import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';

class RobotFaceCanvas extends StatefulWidget {
  const RobotFaceCanvas({super.key, required this.state, this.isActive = true});

  final RobotFaceState state;
  final bool isActive;

  @override
  State<RobotFaceCanvas> createState() => _RobotFaceCanvasState();
}

class _RobotFaceCanvasState extends State<RobotFaceCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _resumeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _syncAnimationActivity();
  }

  @override
  void didUpdateWidget(covariant RobotFaceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncAnimationActivity();
    }
  }

  void _syncAnimationActivity() {
    _resumeGeneration += 1;

    if (widget.isActive) {
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RobotFacePainter(
            state: widget.state,
            phase: _controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RobotFacePainter extends CustomPainter {
  const _RobotFacePainter({required this.state, required this.phase});

  final RobotFaceState state;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final motion = _motionProfileFor(state, size);
    final breathing =
        1 + math.sin(phase * math.pi * 2) * motion.breathingAmplitude;
    final pulse = _pulseValue();
    final blink = _blinkValue();

    final palette = _paletteFor(state.mode);
    final concernTilt = _concernTiltFor(state.mode);
    final eyelidOpen = _eyelidOpenFor(state, blink, phase);
    final pupilOffset = _pupilOffsetFor(state, size, phase);
    final bounceOffset = _bounceOffsetFor(state.mode);

    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    _paintGlowOrb(
      canvas,
      center: Offset(size.width * 0.22, size.height * 0.18),
      radius: size.shortestSide * 0.38,
      color: palette.glow.withValues(alpha: 0.18 + motion.glowBoost),
    );
    _paintGlowOrb(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.24),
      radius: size.shortestSide * 0.26,
      color: palette.accent.withValues(alpha: 0.08 + (motion.glowBoost * 0.75)),
    );

    if (motion.wakeAura > 0) {
      _paintWakeAura(canvas, size, palette, motion.wakeAura, pulse);
    }

    if (state.mode == RobotFaceMode.sleepy) {
      _paintSleepVeil(canvas, size, phase);
    }

    final eyeArea = Rect.fromCenter(
      center: Offset(
        size.width * 0.5,
        size.height * (0.48 - motion.eyeLift) + bounceOffset + motion.idleDrift,
      ),
      width: size.width * 0.8,
      height: size.height * 0.48,
    );
    final eyeWidth = eyeArea.width * 0.36 * breathing;
    final eyeHeight = eyeArea.height * 0.62 * eyelidOpen;
    final eyeRadius = Radius.circular(math.max(26, eyeHeight * 0.42));
    final eyeOffset = eyeArea.width * 0.24;

    final leftEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(eyeArea.center.dx - eyeOffset, eyeArea.center.dy),
        width: eyeWidth,
        height: math.max(28, eyeHeight),
      ),
      eyeRadius,
    );
    final rightEye = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(eyeArea.center.dx + eyeOffset, eyeArea.center.dy),
        width: eyeWidth,
        height: math.max(28, eyeHeight),
      ),
      eyeRadius,
    );

    if (motion.attentionRingStrength > 0) {
      _paintAttentionRing(
        canvas,
        leftEye.outerRect,
        palette,
        pulse,
        motion.attentionRingStrength,
      );
      _paintAttentionRing(
        canvas,
        rightEye.outerRect,
        palette,
        pulse,
        motion.attentionRingStrength,
      );
    }

    _paintEye(
      canvas,
      leftEye,
      palette,
      pupilOffset,
      concernTilt * -1,
      motion.glowBoost,
    );
    _paintEye(
      canvas,
      rightEye,
      palette,
      pupilOffset,
      concernTilt,
      motion.glowBoost,
    );
  }

  void _paintEye(
    Canvas canvas,
    RRect eye,
    _FacePalette palette,
    Offset pupilOffset,
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

    final pupilRect = Rect.fromCenter(
      center: Offset(
        eye.center.dx + pupilOffset.dx,
        eye.center.dy + pupilOffset.dy,
      ),
      width: eye.width * 0.22,
      height: eye.height * 0.48,
    );
    final pupil = RRect.fromRectAndRadius(
      pupilRect,
      Radius.circular(pupilRect.width * 0.48),
    );
    final pupilPaint = Paint()..color = palette.pupil;
    canvas.drawRRect(pupil, pupilPaint);

    final highlightRect = Rect.fromCenter(
      center: Offset(pupil.center.dx - pupil.width * 0.14, pupil.top + 10),
      width: pupil.width * 0.36,
      height: pupil.height * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        highlightRect,
        Radius.circular(highlightRect.height),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

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

  double _blinkValue() {
    final time = phase;
    if (time > 0.18 && time < 0.22) {
      return 1 - ((time - 0.2).abs() / 0.02);
    }
    if (time > 0.68 && time < 0.72) {
      return 1 - ((time - 0.7).abs() / 0.02);
    }
    return 0;
  }

  double _pulseValue() {
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    return Curves.easeOut.transform(pulse);
  }

  double _eyelidOpenFor(RobotFaceState state, double blink, double phase) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);
    final awakeLift = state.isInAwakeWindow ? 0.04 : 0.0;
    final liveLift = state.mode == RobotFaceMode.idle
        ? ((math.sin(phase * math.pi * 2) + 1) / 2) * 0.03
        : 0.0;
    final base = switch (state.mode) {
      RobotFaceMode.sleepy => 0.28,
      RobotFaceMode.offline => 0.54,
      RobotFaceMode.error || RobotFaceMode.missed => 0.46,
      RobotFaceMode.happyConfirmed => 1.08,
      RobotFaceMode.doseApproaching => 1.0 + awakeLift + (ramp * 0.06),
      RobotFaceMode.doseReady => 1.06,
      RobotFaceMode.idle => 0.98 + awakeLift + liveLift,
      _ => 1.0,
    };
    return (base - blink * 0.94).clamp(0.12, 1.08);
  }

  double _concernTiltFor(RobotFaceMode mode) {
    return switch (mode) {
      RobotFaceMode.error => 0.1,
      RobotFaceMode.offline => 0.06,
      RobotFaceMode.missed => 0.08,
      _ => 0,
    };
  }

  Offset _pupilOffsetFor(RobotFaceState state, Size size, double phase) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);
    final horizontal = math.sin(phase * math.pi * 2) * size.width * 0.012;
    final idleVertical = math.sin(phase * math.pi * 4) * size.height * 0.003;

    return switch (state.mode) {
      RobotFaceMode.sleepy => Offset(-size.width * 0.012, size.height * 0.012),
      RobotFaceMode.doseApproaching => Offset(
        horizontal * (0.35 - (ramp * 0.2)),
        -size.height * (0.01 + (ramp * 0.012)),
      ),
      RobotFaceMode.doseReady => Offset(0, -size.height * 0.024),
      RobotFaceMode.happyConfirmed => Offset(
        horizontal * 0.3,
        -size.height * 0.022,
      ),
      RobotFaceMode.error => Offset(size.width * 0.008, size.height * 0.006),
      RobotFaceMode.offline => Offset(-size.width * 0.006, size.height * 0.01),
      RobotFaceMode.idle when state.isInAwakeWindow => Offset(
        horizontal * 0.5,
        -size.height * 0.008 + idleVertical,
      ),
      _ => Offset(horizontal, idleVertical),
    };
  }

  double _bounceOffsetFor(RobotFaceMode mode) {
    if (mode != RobotFaceMode.happyConfirmed) {
      return 0;
    }
    return math.sin(phase * math.pi * 2) * 8;
  }

  _FaceMotionProfile _motionProfileFor(RobotFaceState state, Size size) {
    final ramp = state.rampProgress.clamp(0.0, 1.0);

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
      RobotFaceMode.idle when state.isInAwakeWindow => _FaceMotionProfile(
        breathingAmplitude: 0.022,
        glowBoost: 0.07,
        eyeLift: 0.01,
        attentionRingStrength: 0.16,
        wakeAura: 0.38,
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
    return switch (mode) {
      RobotFaceMode.sleepy => const _FacePalette(
        backgroundTop: Color(0xFF0C1020),
        backgroundBottom: Color(0xFF03050B),
        eyeTop: Color(0xFF5F7CA8),
        eyeBottom: Color(0xFF22324C),
        pupil: Color(0xFFF2F7FF),
        glow: Color(0xFF5877A8),
        accent: Color(0xFF7E90D9),
      ),
      RobotFaceMode.doseReady ||
      RobotFaceMode.doseApproaching => const _FacePalette(
        backgroundTop: Color(0xFF08141F),
        backgroundBottom: Color(0xFF03070B),
        eyeTop: Color(0xFF71F4FF),
        eyeBottom: Color(0xFF1797BE),
        pupil: Color(0xFF04283A),
        glow: Color(0xFF2AE7FF),
        accent: Color(0xFFFFB84F),
      ),
      RobotFaceMode.happyConfirmed => const _FacePalette(
        backgroundTop: Color(0xFF091A16),
        backgroundBottom: Color(0xFF04100E),
        eyeTop: Color(0xFF9DF9DB),
        eyeBottom: Color(0xFF38C4A2),
        pupil: Color(0xFF06372C),
        glow: Color(0xFF56F0C7),
        accent: Color(0xFFFFF2A6),
      ),
      RobotFaceMode.error || RobotFaceMode.missed => const _FacePalette(
        backgroundTop: Color(0xFF1D1013),
        backgroundBottom: Color(0xFF0A0607),
        eyeTop: Color(0xFFFFA0AD),
        eyeBottom: Color(0xFFCF5066),
        pupil: Color(0xFF380911),
        glow: Color(0xFFFF6C83),
        accent: Color(0xFFFFB366),
      ),
      RobotFaceMode.offline => const _FacePalette(
        backgroundTop: Color(0xFF14161D),
        backgroundBottom: Color(0xFF08090D),
        eyeTop: Color(0xFFB6C0D4),
        eyeBottom: Color(0xFF6E788D),
        pupil: Color(0xFF242833),
        glow: Color(0xFF94A4C8),
        accent: Color(0xFF8D93A7),
      ),
      _ => const _FacePalette(
        backgroundTop: Color(0xFF0B1521),
        backgroundBottom: Color(0xFF04070D),
        eyeTop: Color(0xFFC6F8FF),
        eyeBottom: Color(0xFF67D5EB),
        pupil: Color(0xFF062E3C),
        glow: Color(0xFF54E6FF),
        accent: Color(0xFF9D8CFF),
      ),
    };
  }

  @override
  bool shouldRepaint(covariant _RobotFacePainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.phase != phase;
  }
}

class _FacePalette {
  const _FacePalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.eyeTop,
    required this.eyeBottom,
    required this.pupil,
    required this.glow,
    required this.accent,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color eyeTop;
  final Color eyeBottom;
  final Color pupil;
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
