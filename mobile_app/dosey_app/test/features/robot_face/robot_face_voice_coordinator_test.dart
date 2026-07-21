import 'dart:async';
import 'dart:developer' as developer;

import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/robot_face/robot_face_voice_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missed warning phrase keeps the approved wording', () {
    expect(
      FixedPhraseCatalog.definitionFor(DoseyVoicePhrase.missedWarning).text,
      'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
    );
  });

  test('disabled voice prevents event and idle speech', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: false,
        voiceVarietyEnabled: true,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    harness.emit(_state(RobotFaceMode.idle));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('non-robot role suppresses playback', () async {
    final harness = _VoiceCoordinatorHarness(
      role: AppDeviceRole.androidPersonal,
      settings: const RobotFaceSettings(voiceEnabled: true),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('non-android platform suppresses playback', () async {
    final harness = _VoiceCoordinatorHarness(
      platform: AppDevicePlatform.ios,
      settings: const RobotFaceSettings(voiceEnabled: true),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test(
    'dedupe prevents repeated playback for the same effective state',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(voiceEnabled: true),
      );
      addTearDown(harness.dispose);

      final state = _state(RobotFaceMode.doseReady);
      harness.emit(state);
      harness.emit(state.copyWith(statusLabel: 'Still ready'));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.scheduledDoseReady,
      ]);
    },
  );

  test('fixed mode uses deterministic primary phrases', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(voiceEnabled: true),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseApproaching));
    harness.emit(_state(RobotFaceMode.doseReady));
    harness.emit(_state(RobotFaceMode.dispensing));
    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        isAwaitingControllerConfirmation: true,
      ),
    );
    harness.emit(_state(RobotFaceMode.missed));
    harness.emit(_state(RobotFaceMode.offline));
    harness.emit(_state(RobotFaceMode.error));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.doseSoon,
      DoseyVoicePhrase.scheduledDoseReady,
      DoseyVoicePhrase.dispensingNow,
      DoseyVoicePhrase.checkRightDose,
      DoseyVoicePhrase.missedWarning,
      DoseyVoicePhrase.controllerOffline,
      DoseyVoicePhrase.needsCheckingBeforeContinue,
    ]);
  });

  test(
    'quiet hours helper handles overnight and daytime ranges safely',
    () async {
      final overnightHarness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceQuietHoursEnabled: true,
        ),
        now: DateTime(2026, 7, 20, 23),
      );
      addTearDown(overnightHarness.dispose);
      overnightHarness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();
      expect(overnightHarness.voiceGateway.playedPhrases, isEmpty);

      overnightHarness.now = DateTime(2026, 7, 21, 6, 59);
      overnightHarness.emit(_state(RobotFaceMode.doseApproaching));
      await pumpEventQueue();
      expect(overnightHarness.voiceGateway.playedPhrases, isEmpty);

      final daytimeHarness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceQuietHoursEnabled: true,
          voiceQuietHoursStartMinutes: 8 * 60,
          voiceQuietHoursEndMinutes: 17 * 60,
        ),
        now: DateTime(2026, 7, 20, 12),
      );
      addTearDown(daytimeHarness.dispose);
      daytimeHarness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();
      expect(daytimeHarness.voiceGateway.playedPhrases, isEmpty);

      final outsideHarness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceQuietHoursEnabled: true,
        ),
        now: DateTime(2026, 7, 20, 12),
      );
      addTearDown(outsideHarness.dispose);
      outsideHarness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();
      expect(outsideHarness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.scheduledDoseReady,
      ]);
    },
  );

  test(
    'variety mode chooses from the safe category for each trigger',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceVarietyEnabled: true,
        ),
        randomIndexes: <int>[1, 2, 3, 4, 1, 2, 3],
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.dispensing));
      harness.emit(
        _state(
          RobotFaceMode.waitingForConfirmation,
          isAwaitingControllerConfirmation: true,
        ),
      );
      harness.emit(_state(RobotFaceMode.missed));
      harness.emit(_state(RobotFaceMode.offline));
      harness.emit(_state(RobotFaceMode.error));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.almostTime,
        DoseyVoicePhrase.checkCupBeforeTaking,
        DoseyVoicePhrase.waitWhileMove,
        DoseyVoicePhrase.stopAskHelp,
        DoseyVoicePhrase.missedNeedsReview,
        DoseyVoicePhrase.controllerStillOffline,
        DoseyVoicePhrase.controllerReconnect,
      ]);
    },
  );

  test('idle chatter only speaks in safe idle states after cooldown', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        voiceVarietyEnabled: true,
        idleChatterCooldownMinutes: 10,
      ),
      randomIndexes: <int>[0, 7],
      now: DateTime(2026, 7, 20, 9),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.idle));
    await pumpEventQueue();
    harness.emit(_state(RobotFaceMode.sleepy));
    await pumpEventQueue();
    harness.now = harness.now.add(const Duration(minutes: 11));
    harness.emit(_state(RobotFaceMode.idle));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.awake,
      DoseyVoicePhrase.keepingWatch,
    ]);
  });

  test(
    'idle chatter cooldown off allows repeat after safe state changes',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceVarietyEnabled: true,
          idleChatterCooldownMinutes: 0,
        ),
        randomIndexes: <int>[0, 1],
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.idle));
      await pumpEventQueue();
      harness.emit(_state(RobotFaceMode.sleepy));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.awake,
        DoseyVoicePhrase.helloHere,
      ]);
    },
  );

  test(
    'no-repeats policy keeps reminder and ready speech one-time per trigger key',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          reminderRepeatCooldownMinutes: 5,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.noRepeats,
        ),
        now: DateTime(2026, 7, 20, 9),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      harness.now = harness.now.add(const Duration(minutes: 6));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.doseSoon,
        DoseyVoicePhrase.scheduledDoseReady,
      ]);
    },
  );

  test(
    'reminders-only policy lets reminder speech replay after cooldown',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          reminderRepeatCooldownMinutes: 5,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersOnly,
        ),
        now: DateTime(2026, 7, 20, 9),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      await pumpEventQueue();

      harness.now = harness.now.add(const Duration(minutes: 6));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.doseSoon,
        DoseyVoicePhrase.doseSoon,
      ]);
    },
  );

  test(
    'reminders-only policy keeps ready speech one-time per trigger key',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          reminderRepeatCooldownMinutes: 5,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersOnly,
        ),
        now: DateTime(2026, 7, 20, 9),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.idle));
      await pumpEventQueue();

      harness.now = harness.now.add(const Duration(minutes: 6));
      harness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.scheduledDoseReady,
      ]);
    },
  );

  test(
    'full repeat policy lets reminder and ready speech replay after cooldown',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          reminderRepeatCooldownMinutes: 5,
          reminderRepeatPolicy:
              RobotReminderRepeatPolicy.repeatRemindersAndReady,
        ),
        now: DateTime(2026, 7, 20, 9),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      harness.now = harness.now.add(const Duration(minutes: 6));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.doseSoon,
        DoseyVoicePhrase.scheduledDoseReady,
        DoseyVoicePhrase.doseSoon,
        DoseyVoicePhrase.scheduledDoseReady,
      ]);
    },
  );

  test(
    'urgent categories are not suppressed by reminder repeat cooldown',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          reminderRepeatCooldownMinutes: 15,
          reminderRepeatPolicy: RobotReminderRepeatPolicy.noRepeats,
        ),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.idle));
      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.missed));
      harness.emit(_state(RobotFaceMode.offline));
      harness.emit(_state(RobotFaceMode.error));
      harness.emit(
        _state(
          RobotFaceMode.waitingForConfirmation,
          isAwaitingControllerConfirmation: true,
        ),
      );
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.doseSoon,
        DoseyVoicePhrase.scheduledDoseReady,
        DoseyVoicePhrase.missedWarning,
        DoseyVoicePhrase.controllerOffline,
        DoseyVoicePhrase.needsCheckingBeforeContinue,
        DoseyVoicePhrase.checkRightDose,
      ]);
    },
  );

  test(
    'quiet hours without safety override mute event and idle speech',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceVarietyEnabled: true,
          voiceQuietHoursEnabled: true,
        ),
        now: DateTime(2026, 7, 20, 23),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.missed));
      harness.emit(_state(RobotFaceMode.idle));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, isEmpty);
    },
  );

  test('quiet hours with safety override allow only safety classes', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        voiceVarietyEnabled: true,
        voiceQuietHoursEnabled: true,
        voiceSafetyDuringQuietHoursEnabled: true,
      ),
      now: DateTime(2026, 7, 20, 23),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseApproaching));
    harness.emit(_state(RobotFaceMode.doseReady));
    harness.emit(_state(RobotFaceMode.dispensing));
    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        isAwaitingControllerConfirmation: true,
      ),
    );
    harness.emit(_state(RobotFaceMode.missed));
    harness.emit(_state(RobotFaceMode.offline));
    harness.emit(_state(RobotFaceMode.error));
    harness.emit(_state(RobotFaceMode.idle));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.checkCupTime,
      DoseyVoicePhrase.checkRightDose,
      DoseyVoicePhrase.missedWarning,
      DoseyVoicePhrase.controllerOffline,
      DoseyVoicePhrase.controllerOffline,
    ]);
  });

  test(
    'quiet hours safety override uses check-cup ready phrase without variety',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceQuietHoursEnabled: true,
          voiceSafetyDuringQuietHoursEnabled: true,
        ),
        now: DateTime(2026, 7, 20, 23),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.doseApproaching));
      harness.emit(_state(RobotFaceMode.doseReady));
      harness.emit(_state(RobotFaceMode.dispensing));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.checkRightDose,
      ]);
    },
  );

  test('blocked reminder category suppresses reminder speech', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        reminderVoiceEnabled: false,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseApproaching));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('blocked dispense category suppresses dispense narration', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        dispenseNarrationEnabled: false,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.dispensing));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('blocked idle category suppresses idle chatter', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        voiceVarietyEnabled: true,
        idleChatterVoiceEnabled: false,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.idle));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('blocked missed category suppresses missed speech', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        missedDoseVoiceEnabled: false,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.missed));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('blocked controller category suppresses controller speech', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        controllerAlertVoiceEnabled: false,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.offline));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('quiet-hour safety override still respects category toggles', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        voiceQuietHoursEnabled: true,
        voiceSafetyDuringQuietHoursEnabled: true,
        safetyConfirmationVoiceEnabled: false,
        missedDoseVoiceEnabled: true,
        controllerAlertVoiceEnabled: true,
      ),
      now: DateTime(2026, 7, 20, 23),
    );
    addTearDown(harness.dispose);

    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        isAwaitingControllerConfirmation: true,
      ),
    );
    harness.emit(_state(RobotFaceMode.missed));
    harness.emit(_state(RobotFaceMode.offline));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.missedWarning,
      DoseyVoicePhrase.controllerOffline,
    ]);
  });

  test(
    'idle chatter never starts directly from missed or dispensing states',
    () async {
      final harness = _VoiceCoordinatorHarness(
        settings: const RobotFaceSettings(
          voiceEnabled: true,
          voiceVarietyEnabled: true,
        ),
        randomIndexes: <int>[0, 1],
        now: DateTime(2026, 7, 20, 9),
      );
      addTearDown(harness.dispose);

      harness.emit(_state(RobotFaceMode.missed));
      harness.emit(_state(RobotFaceMode.idle));
      harness.now = harness.now.add(const Duration(minutes: 11));
      harness.emit(_state(RobotFaceMode.dispensing));
      harness.emit(_state(RobotFaceMode.idle));
      await pumpEventQueue();

      expect(harness.voiceGateway.playedPhrases, [
        DoseyVoicePhrase.missedWarning,
        DoseyVoicePhrase.dispensingNow,
      ]);
    },
  );

  test('voice playback does not write dose-state side effects', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(
        voiceEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.quiet,
      ),
    );
    addTearDown(harness.dispose);

    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        isAwaitingControllerConfirmation: true,
      ),
    );
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.checkRightDose,
    ]);
    expect(
      harness.voiceGateway.lastVolume,
      RobotVoiceVolumePreset.quiet.volume,
    );
    expect(harness.voiceGateway.sideEffectsSeen, isFalse);
  });

  test('playback failures stay best-effort', () async {
    final zoneErrors = <Object>[];

    await runZonedGuarded(
      () async {
        final harness = _VoiceCoordinatorHarness(
          settings: const RobotFaceSettings(voiceEnabled: true),
          voiceGateway: _ThrowingVoicePlaybackGateway(),
        );
        addTearDown(harness.dispose);

        harness.emit(_state(RobotFaceMode.doseReady));
        await pumpEventQueue();
      },
      (error, stackTrace) {
        zoneErrors.add(error);
        developer.log(
          'Unexpected zone error during playback failure test.',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    expect(zoneErrors, isEmpty);
  });
}

RobotFaceState _state(
  RobotFaceMode mode, {
  bool isAwaitingControllerConfirmation = false,
}) {
  return RobotFaceState(
    mode: mode,
    nextEventLabel: '9:00 · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: mode == RobotFaceMode.doseApproaching ? 0.5 : 1,
    isInAwakeWindow: true,
    isAwaitingControllerConfirmation: isAwaitingControllerConfirmation,
  );
}

class _VoiceCoordinatorHarness {
  _VoiceCoordinatorHarness({
    this.role = AppDeviceRole.androidRobot,
    this.settings = const RobotFaceSettings(),
    this.platform = AppDevicePlatform.android,
    DateTime? now,
    List<int> randomIndexes = const <int>[0],
    _InspectableVoicePlaybackGateway? voiceGateway,
  }) : _randomIndexes = List<int>.from(randomIndexes),
       now = now ?? DateTime(2026, 7, 20, 9) {
    final gateway = voiceGateway ?? _FakeVoicePlaybackGateway();
    this.voiceGateway = gateway;
    coordinator = RobotFaceVoiceCoordinator(
      stateStream: states.stream,
      settingsStream: Stream<RobotFaceSettings>.value(settings),
      roleStream: Stream<AppDeviceRole>.value(role),
      voicePlayer: DoseyVoicePlayer(playbackGateway: gateway),
      platform: () => platform,
      now: () => this.now,
      randomIndex: _nextRandomIndex,
    );
  }

  final AppDeviceRole role;
  final RobotFaceSettings settings;
  final AppDevicePlatform platform;
  final List<int> _randomIndexes;
  final states = StreamController<RobotFaceState>.broadcast();
  late final _InspectableVoicePlaybackGateway voiceGateway;
  late final RobotFaceVoiceCoordinator coordinator;
  DateTime now;
  int _randomCallCount = 0;

  int _nextRandomIndex(int max) {
    final value = _randomIndexes[_randomCallCount % _randomIndexes.length];
    _randomCallCount += 1;
    return value % max;
  }

  void emit(RobotFaceState state) => states.add(state);

  Future<void> dispose() async {
    await coordinator.close();
    await states.close();
  }
}

abstract interface class _InspectableVoicePlaybackGateway
    implements VoicePlaybackGateway {
  List<DoseyVoicePhrase> get playedPhrases;
  bool get sideEffectsSeen;
  double? get lastVolume;
}

class _FakeVoicePlaybackGateway implements _InspectableVoicePlaybackGateway {
  @override
  final List<DoseyVoicePhrase> playedPhrases = <DoseyVoicePhrase>[];
  @override
  double? lastVolume;

  @override
  bool sideEffectsSeen = false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    playedPhrases.add(
      FixedPhraseCatalog.phrases
          .singleWhere((phrase) => phrase.assetPath == assetPath)
          .phrase,
    );
    lastVolume = volume;
  }
}

class _ThrowingVoicePlaybackGateway
    implements _InspectableVoicePlaybackGateway {
  @override
  List<DoseyVoicePhrase> get playedPhrases => const <DoseyVoicePhrase>[];

  @override
  bool get sideEffectsSeen => false;

  @override
  double? get lastVolume => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath, {required double volume}) {
    throw StateError('Playback failed for $assetPath');
  }
}
