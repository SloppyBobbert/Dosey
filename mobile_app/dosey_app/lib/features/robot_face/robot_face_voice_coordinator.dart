// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:developer' as developer;

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
  }) : _voicePlayer = voicePlayer,
       _platform = platform ?? currentAppDevicePlatform {
    _subscriptions = <StreamSubscription<Object?>>[
      settingsStream.listen((value) => _settings = value),
      roleStream.listen((value) => _role = value),
      stateStream.listen(_handleState),
    ];
  }

  final DoseyVoicePlayer _voicePlayer;
  final AppDevicePlatform Function() _platform;
  late final List<StreamSubscription<Object?>> _subscriptions;

  RobotFaceSettings _settings = const RobotFaceSettings();
  AppDeviceRole? _role;
  String? _lastEffectiveKey;

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  void _handleState(RobotFaceState state) {
    final phrase = _phraseFor(state);
    final effectiveKey = phrase == null ? null : _effectiveKey(state, phrase);
    if (effectiveKey == _lastEffectiveKey) {
      return;
    }

    if (phrase == null || !_shouldSpeak) {
      return;
    }

    _lastEffectiveKey = effectiveKey;
    unawaited(_speakBestEffort(phrase));
  }

  String _effectiveKey(RobotFaceState state, DoseyVoicePhrase phrase) {
    return '${state.mode.name}:${phrase.name}:${state.isAwaitingControllerConfirmation}';
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

  DoseyVoicePhrase? _phraseFor(RobotFaceState state) {
    return switch (state.mode) {
      RobotFaceMode.doseApproaching => DoseyVoicePhrase.doseSoon,
      RobotFaceMode.doseReady => DoseyVoicePhrase.scheduledDoseReady,
      RobotFaceMode.dispensing => DoseyVoicePhrase.dispensingNow,
      RobotFaceMode.waitingForConfirmation
          when state.isAwaitingControllerConfirmation =>
        DoseyVoicePhrase.checkRightDose,
      RobotFaceMode.missed => DoseyVoicePhrase.missedWarning,
      RobotFaceMode.offline => DoseyVoicePhrase.controllerOffline,
      RobotFaceMode.error => DoseyVoicePhrase.needsCheckingBeforeContinue,
      _ => null,
    };
  }
}
