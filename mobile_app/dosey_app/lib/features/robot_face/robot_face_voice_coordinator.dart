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
  late final List<StreamSubscription<Object?>> _subscriptions;

  RobotFaceSettings _settings = const RobotFaceSettings();
  AppDeviceRole? _role;
  RobotFaceState? _lastState;
  String? _lastEffectiveKey;
  final Set<String> _repeatRestrictedEffectiveKeys = <String>{};
  DateTime? _lastIdleChatterAt;
  final Map<_VoiceEffectKind, DateTime> _lastCategorySpokenAt =
      <_VoiceEffectKind, DateTime>{};

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  void _handleState(RobotFaceState state) {
    final effect = _effectFor(state, previousState: _lastState);
    _lastState = state;

    if (effect == null) {
      _lastEffectiveKey = null;
      return;
    }

    final effectiveKey = _effectiveKeyFor(effect, state);
    final isConsecutiveDuplicate =
        effect.dedupe && effectiveKey == _lastEffectiveKey;
    _lastEffectiveKey = effect.dedupe ? effectiveKey : null;

    if (!_shouldSpeak) {
      return;
    }
    if (_isInsideQuietHours && !_canSpeakDuringQuietHours(effect)) {
      return;
    }
    if (!_isCategoryEnabled(effect.kind)) {
      return;
    }

    if (isConsecutiveDuplicate) {
      return;
    }
    if (_repeatRestrictedEffectiveKeys.contains(effectiveKey)) {
      return;
    }
    if (_isCooldownSuppressed(effect)) {
      return;
    }
    if (_isRepeatRestricted(effect.kind)) {
      _repeatRestrictedEffectiveKeys.add(effectiveKey);
    }
    if (_usesReminderRepeatCooldown(effect.kind)) {
      _lastCategorySpokenAt[effect.kind] = _now();
    }
    if (effect.isIdleChatter) {
      _lastIdleChatterAt = _now();
    }

    unawaited(_speakBestEffort(effect.phrase));
  }

  Future<void> _speakBestEffort(DoseyVoicePhrase phrase) async {
    try {
      await _voicePlayer.speak(
        phrase,
        volume: _settings.voiceVolumePreset.volume,
      );
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

  bool get _isInsideQuietHours {
    if (!_settings.voiceQuietHoursEnabled) {
      return false;
    }
    final now = _now();
    final currentMinutes = now.hour * 60 + now.minute;
    final start = _normalizeMinutes(_settings.voiceQuietHoursStartMinutes);
    final end = _normalizeMinutes(_settings.voiceQuietHoursEndMinutes);
    if (start == end) {
      return true;
    }
    if (start < end) {
      return currentMinutes >= start && currentMinutes < end;
    }
    return currentMinutes >= start || currentMinutes < end;
  }

  _VoiceEffect? _effectFor(
    RobotFaceState state, {
    required RobotFaceState? previousState,
  }) {
    final trigger = _triggerFor(state);
    if (trigger != null) {
      final allowQuietSafetyOverride =
          _isInsideQuietHours && _settings.voiceSafetyDuringQuietHoursEnabled;
      return _VoiceEffect(
        phrase: _phraseForTrigger(
          trigger,
          allowQuietSafetyOverride: allowQuietSafetyOverride,
        ),
        triggerKey: trigger.name,
        dedupe: true,
        kind: _effectKindForTrigger(
          trigger,
          allowQuietSafetyOverride: allowQuietSafetyOverride,
        ),
      );
    }

    if (_shouldUseIdleChatter(state, previousState: previousState)) {
      return _VoiceEffect(
        phrase: _phraseForCategory(DoseyVoicePhraseCategory.wakeIdle),
        triggerKey: 'idle:${state.mode.name}',
        dedupe: false,
        isIdleChatter: true,
        kind: _VoiceEffectKind.idle,
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
    if (!_settings.idleChatterVoiceEnabled) {
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
    final cooldown = Duration(minutes: _settings.idleChatterCooldownMinutes);
    if (cooldown == Duration.zero) {
      return true;
    }
    return _now().difference(lastIdleChatterAt) >= cooldown;
  }

  bool _isCooldownSuppressed(_VoiceEffect effect) {
    if (!_isRepeatableAfterCooldown(effect.kind)) {
      return false;
    }

    final cooldown = Duration(minutes: _settings.reminderRepeatCooldownMinutes);
    if (cooldown == Duration.zero) {
      return false;
    }

    final lastSpokenAt = _lastCategorySpokenAt[effect.kind];
    if (lastSpokenAt == null) {
      return false;
    }

    return _now().difference(lastSpokenAt) < cooldown;
  }

  bool _usesReminderRepeatCooldown(_VoiceEffectKind kind) {
    return kind == _VoiceEffectKind.reminder || kind == _VoiceEffectKind.ready;
  }

  bool _isRepeatableAfterCooldown(_VoiceEffectKind kind) {
    return switch (_settings.reminderRepeatPolicy) {
      RobotReminderRepeatPolicy.noRepeats => false,
      RobotReminderRepeatPolicy.repeatRemindersOnly =>
        kind == _VoiceEffectKind.reminder,
      RobotReminderRepeatPolicy.repeatRemindersAndReady =>
        _usesReminderRepeatCooldown(kind),
    };
  }

  bool _isRepeatRestricted(_VoiceEffectKind kind) {
    if (!_usesReminderRepeatCooldown(kind)) {
      return false;
    }

    return !_isRepeatableAfterCooldown(kind);
  }

  String _effectiveKeyFor(_VoiceEffect effect, RobotFaceState state) {
    final occurrenceKey = _occurrenceKeyFor(effect.kind, state);
    if (occurrenceKey == null) {
      return '${effect.triggerKey}:${effect.phrase.name}';
    }
    return '${effect.triggerKey}:$occurrenceKey:${effect.phrase.name}';
  }

  String? _occurrenceKeyFor(_VoiceEffectKind kind, RobotFaceState state) {
    if (!_usesReminderRepeatCooldown(kind)) {
      return null;
    }
    return state.actionDoseId ?? state.nextEventLabel;
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

  DoseyVoicePhrase _phraseForTrigger(
    _VoiceTrigger trigger, {
    required bool allowQuietSafetyOverride,
  }) {
    if (allowQuietSafetyOverride && trigger == _VoiceTrigger.doseReady) {
      return _settings.voiceVarietyEnabled
          ? _phraseForCategory(DoseyVoicePhraseCategory.quietHoursReadySafety)
          : DoseyVoicePhrase.checkRightDose;
    }

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

  _VoiceEffectKind _effectKindForTrigger(
    _VoiceTrigger trigger, {
    required bool allowQuietSafetyOverride,
  }) {
    if (allowQuietSafetyOverride && trigger == _VoiceTrigger.doseReady) {
      return _VoiceEffectKind.confirmationSafety;
    }
    return trigger.effectKind;
  }

  DoseyVoicePhrase _phraseForCategory(DoseyVoicePhraseCategory category) {
    final options = FixedPhraseCatalog.phrasesForCategory(category);
    return options[_randomIndex(options.length)].phrase;
  }

  bool _canSpeakDuringQuietHours(_VoiceEffect effect) {
    if (!_settings.voiceSafetyDuringQuietHoursEnabled) {
      return false;
    }
    return switch (effect.kind) {
      _VoiceEffectKind.confirmationSafety ||
      _VoiceEffectKind.missedReview ||
      _VoiceEffectKind.controllerHardware => true,
      _ => false,
    };
  }

  bool _isCategoryEnabled(_VoiceEffectKind kind) {
    return switch (kind) {
      _VoiceEffectKind.idle => _settings.idleChatterVoiceEnabled,
      _VoiceEffectKind.reminder ||
      _VoiceEffectKind.ready => _settings.reminderVoiceEnabled,
      _VoiceEffectKind.dispensing => _settings.dispenseNarrationEnabled,
      _VoiceEffectKind.confirmationSafety =>
        _settings.safetyConfirmationVoiceEnabled,
      _VoiceEffectKind.missedReview => _settings.missedDoseVoiceEnabled,
      _VoiceEffectKind.controllerHardware =>
        _settings.controllerAlertVoiceEnabled,
    };
  }

  static int _normalizeMinutes(int minutes) {
    const dayMinutes = 24 * 60;
    return ((minutes % dayMinutes) + dayMinutes) % dayMinutes;
  }
}

enum _VoiceTrigger {
  reminderApproaching(
    DoseyVoicePhraseCategory.reminderApproaching,
    _VoiceEffectKind.reminder,
  ),
  doseReady(DoseyVoicePhraseCategory.doseReadyCupCheck, _VoiceEffectKind.ready),
  dispensing(
    DoseyVoicePhraseCategory.dispensingMovement,
    _VoiceEffectKind.dispensing,
  ),
  confirmation(
    DoseyVoicePhraseCategory.confirmationSafety,
    _VoiceEffectKind.confirmationSafety,
  ),
  missed(DoseyVoicePhraseCategory.missedReview, _VoiceEffectKind.missedReview),
  controllerOffline(
    DoseyVoicePhraseCategory.controllerHardware,
    _VoiceEffectKind.controllerHardware,
  ),
  controllerError(
    DoseyVoicePhraseCategory.controllerHardware,
    _VoiceEffectKind.controllerHardware,
  );

  const _VoiceTrigger(this.category, this.effectKind);

  final DoseyVoicePhraseCategory category;
  final _VoiceEffectKind effectKind;
}

enum _VoiceEffectKind {
  idle,
  reminder,
  ready,
  dispensing,
  confirmationSafety,
  missedReview,
  controllerHardware,
}

class _VoiceEffect {
  const _VoiceEffect({
    required this.phrase,
    required this.triggerKey,
    required this.dedupe,
    required this.kind,
    this.isIdleChatter = false,
  });

  final DoseyVoicePhrase phrase;
  final String triggerKey;
  final bool dedupe;
  final _VoiceEffectKind kind;
  final bool isIdleChatter;
}
