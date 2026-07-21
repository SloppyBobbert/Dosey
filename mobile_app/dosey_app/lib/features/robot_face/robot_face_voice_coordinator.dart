// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';

class RobotFaceVoiceCoordinator {
  RobotFaceVoiceCoordinator({
    required Stream<RobotFaceState> stateStream,
    required Stream<RobotFaceSettings> settingsStream,
    required Stream<AppDeviceRole> roleStream,
    required DoseyVoicePlayer voicePlayer,
    AppDevicePlatform Function()? platform,
    DateTime Function()? now,
    int Function(int max)? randomIndex,
    this.idleChatterCooldown = const Duration(minutes: 10),
  }) : _voicePlayer = voicePlayer,
       _platform = platform ?? currentAppDevicePlatform,
       _now = now ?? DateTime.now,
       _randomIndex = randomIndex ?? ((max) => Random().nextInt(max)) {
    _subscriptions = <StreamSubscription<Object?>>[
      settingsStream.listen((value) => _settings = value),
      roleStream.listen((value) => _role = value),
      stateStream.listen(_handleState),
    ];
  }

  final DoseyVoicePlayer _voicePlayer;
  final AppDevicePlatform Function() _platform;
  final DateTime Function() _now;
  final int Function(int max) _randomIndex;
  final Duration idleChatterCooldown;
  late final List<StreamSubscription<Object?>> _subscriptions;

  RobotFaceSettings _settings = const RobotFaceSettings();
  AppDeviceRole? _role;
  RobotFaceState? _lastState;
  String? _lastEffectiveKey;
  DateTime? _lastIdleChatterAt;

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  void _handleState(RobotFaceState state) {
    final effect = _effectFor(state, previousState: _lastState);
    _lastState = state;

    if (effect == null || !_shouldSpeak) {
      return;
    }

    final effectiveKey = '${effect.triggerKey}:${effect.phrase.name}';
    if (effect.dedupe && effectiveKey == _lastEffectiveKey) {
      return;
    }
    if (effect.dedupe) {
      _lastEffectiveKey = effectiveKey;
    }
    if (effect.isIdleChatter) {
      _lastIdleChatterAt = _now();
    }

    unawaited(_speakBestEffort(effect.phrase));
  }

  Future<void> _speakBestEffort(DoseyVoicePhrase phrase) async {
    try {
      await _voicePlayer.speak(phrase);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Robot Face voice playback failed; continuing without speech.',
        name: 'dosey.robot_face_voice',
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool get _shouldSpeak {
    return _platform() == AppDevicePlatform.android &&
        _role == AppDeviceRole.androidRobot &&
        _settings.voiceEnabled;
  }

  _VoiceEffect? _effectFor(
    RobotFaceState state, {
    required RobotFaceState? previousState,
  }) {
    final trigger = _triggerFor(state);
    if (trigger != null) {
      return _VoiceEffect(
        phrase: _phraseForTrigger(trigger),
        triggerKey: trigger.name,
        dedupe: true,
      );
    }

    if (_shouldUseIdleChatter(state, previousState: previousState)) {
      return _VoiceEffect(
        phrase: _phraseForCategory(DoseyVoicePhraseCategory.wakeIdle),
        triggerKey: 'idle:${state.mode.name}',
        dedupe: false,
        isIdleChatter: true,
      );
    }

    return null;
  }

  bool _shouldUseIdleChatter(
    RobotFaceState state, {
    required RobotFaceState? previousState,
  }) {
    if (!_settings.voiceVarietyEnabled) {
      return false;
    }
    if (state.mode != RobotFaceMode.idle &&
        state.mode != RobotFaceMode.sleepy) {
      return false;
    }
    if (previousState?.mode == state.mode) {
      return false;
    }
    if (previousState != null &&
        (previousState.mode == RobotFaceMode.missed ||
            previousState.mode == RobotFaceMode.error ||
            previousState.mode == RobotFaceMode.dispensing)) {
      return false;
    }
    final lastIdleChatterAt = _lastIdleChatterAt;
    if (lastIdleChatterAt == null) {
      return true;
    }
    return _now().difference(lastIdleChatterAt) >= idleChatterCooldown;
  }

  _VoiceTrigger? _triggerFor(RobotFaceState state) {
    return switch (state.mode) {
      RobotFaceMode.doseApproaching => _VoiceTrigger.reminderApproaching,
      RobotFaceMode.doseReady => _VoiceTrigger.doseReady,
      RobotFaceMode.dispensing => _VoiceTrigger.dispensing,
      RobotFaceMode.waitingForConfirmation
          when state.isAwaitingControllerConfirmation =>
        _VoiceTrigger.confirmation,
      RobotFaceMode.missed => _VoiceTrigger.missed,
      RobotFaceMode.offline => _VoiceTrigger.controllerOffline,
      RobotFaceMode.error => _VoiceTrigger.controllerError,
      _ => null,
    };
  }

  DoseyVoicePhrase _phraseForTrigger(_VoiceTrigger trigger) {
    if (!_settings.voiceVarietyEnabled) {
      return switch (trigger) {
        _VoiceTrigger.reminderApproaching => DoseyVoicePhrase.doseSoon,
        _VoiceTrigger.doseReady => DoseyVoicePhrase.scheduledDoseReady,
        _VoiceTrigger.dispensing => DoseyVoicePhrase.dispensingNow,
        _VoiceTrigger.confirmation => DoseyVoicePhrase.checkRightDose,
        _VoiceTrigger.missed => DoseyVoicePhrase.missedWarning,
        _VoiceTrigger.controllerOffline => DoseyVoicePhrase.controllerOffline,
        _VoiceTrigger.controllerError =>
          DoseyVoicePhrase.needsCheckingBeforeContinue,
      };
    }

    return _phraseForCategory(trigger.category);
  }

  DoseyVoicePhrase _phraseForCategory(DoseyVoicePhraseCategory category) {
    final options = FixedPhraseCatalog.phrasesForCategory(category);
    return options[_randomIndex(options.length)].phrase;
  }
}

enum _VoiceTrigger {
  reminderApproaching(DoseyVoicePhraseCategory.reminderApproaching),
  doseReady(DoseyVoicePhraseCategory.doseReadyCupCheck),
  dispensing(DoseyVoicePhraseCategory.dispensingMovement),
  confirmation(DoseyVoicePhraseCategory.confirmationSafety),
  missed(DoseyVoicePhraseCategory.missedReview),
  controllerOffline(DoseyVoicePhraseCategory.controllerHardware),
  controllerError(DoseyVoicePhraseCategory.controllerHardware);

  const _VoiceTrigger(this.category);

  final DoseyVoicePhraseCategory category;
}

class _VoiceEffect {
  const _VoiceEffect({
    required this.phrase,
    required this.triggerKey,
    required this.dedupe,
    this.isIdleChatter = false,
  });

  final DoseyVoicePhrase phrase;
  final String triggerKey;
  final bool dedupe;
  final bool isIdleChatter;
}
