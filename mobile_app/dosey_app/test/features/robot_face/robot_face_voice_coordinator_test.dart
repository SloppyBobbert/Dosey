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

  test('disabled voice prevents speech', () async {
    final harness = _VoiceCoordinatorHarness(
      settings: const RobotFaceSettings(voiceEnabled: false),
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('non-robot role suppresses playback', () async {
    final harness = _VoiceCoordinatorHarness(
      role: AppDeviceRole.androidPersonal,
    );
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test('non-android platform suppresses playback', () async {
    final harness = _VoiceCoordinatorHarness(platform: AppDevicePlatform.ios);
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseReady));
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, isEmpty);
  });

  test(
    'dedupe prevents repeated playback for the same effective state',
    () async {
      final harness = _VoiceCoordinatorHarness();
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

  test(
    'first eligible state still speaks after role/settings settle',
    () async {
      final states = StreamController<RobotFaceState>.broadcast();
      final settings = StreamController<RobotFaceSettings>.broadcast();
      final roles = StreamController<AppDeviceRole>.broadcast();
      final gateway = _FakeVoicePlaybackGateway();
      final coordinator = RobotFaceVoiceCoordinator(
        stateStream: states.stream,
        settingsStream: settings.stream,
        roleStream: roles.stream,
        voicePlayer: DoseyVoicePlayer(playbackGateway: gateway),
        platform: () => AppDevicePlatform.android,
      );
      addTearDown(() async {
        await coordinator.close();
        await states.close();
        await settings.close();
        await roles.close();
      });

      states.add(_state(RobotFaceMode.doseReady));
      roles.add(AppDeviceRole.androidRobot);
      settings.add(const RobotFaceSettings());
      states.add(_state(RobotFaceMode.doseReady));
      await pumpEventQueue();

      expect(gateway.playedPhrases, [DoseyVoicePhrase.scheduledDoseReady]);
    },
  );

  test('playback triggers on required robot face state transitions', () async {
    final harness = _VoiceCoordinatorHarness();
    addTearDown(harness.dispose);

    harness.emit(_state(RobotFaceMode.doseApproaching));
    harness.emit(_state(RobotFaceMode.doseReady));
    harness.emit(
      _state(RobotFaceMode.dispensing, statusLabel: 'Dispensing in progress'),
    );
    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        statusLabel: 'Awaiting dose confirmation',
        isAwaitingControllerConfirmation: true,
      ),
    );
    harness.emit(_state(RobotFaceMode.missed, statusLabel: 'Dose missed'));
    harness.emit(
      _state(RobotFaceMode.offline, statusLabel: 'Controller offline'),
    );
    harness.emit(_state(RobotFaceMode.error, statusLabel: 'Dose error logged'));
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

  test('voice playback does not write dose-state side effects', () async {
    final harness = _VoiceCoordinatorHarness();
    addTearDown(harness.dispose);

    harness.emit(
      _state(
        RobotFaceMode.waitingForConfirmation,
        statusLabel: 'Awaiting dose confirmation',
        isAwaitingControllerConfirmation: true,
      ),
    );
    await pumpEventQueue();

    expect(harness.voiceGateway.playedPhrases, [
      DoseyVoicePhrase.checkRightDose,
    ]);
    expect(harness.voiceGateway.sideEffectsSeen, isFalse);
  });

  test('playback failures stay best-effort', () async {
    final zoneErrors = <Object>[];

    await runZonedGuarded(
      () async {
        final harness = _VoiceCoordinatorHarness(
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
  String? statusLabel,
  bool isAwaitingControllerConfirmation = false,
}) {
  return RobotFaceState(
    mode: mode,
    nextEventLabel: '9:00 · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: mode == RobotFaceMode.doseApproaching ? 0.5 : 1,
    isInAwakeWindow: true,
    statusLabel: statusLabel,
    isAwaitingControllerConfirmation: isAwaitingControllerConfirmation,
  );
}

class _VoiceCoordinatorHarness {
  _VoiceCoordinatorHarness({
    this.role = AppDeviceRole.androidRobot,
    this.settings = const RobotFaceSettings(),
    this.platform = AppDevicePlatform.android,
    _InspectableVoicePlaybackGateway? voiceGateway,
  }) {
    final gateway = voiceGateway ?? _FakeVoicePlaybackGateway();
    this.voiceGateway = gateway;
    coordinator = RobotFaceVoiceCoordinator(
      stateStream: states.stream,
      settingsStream: Stream<RobotFaceSettings>.value(settings),
      roleStream: Stream<AppDeviceRole>.value(role),
      voicePlayer: DoseyVoicePlayer(playbackGateway: gateway),
      platform: () => platform,
    );
  }

  final AppDeviceRole role;
  final RobotFaceSettings settings;
  final AppDevicePlatform platform;
  final states = StreamController<RobotFaceState>.broadcast();
  late final _InspectableVoicePlaybackGateway voiceGateway;
  late final RobotFaceVoiceCoordinator coordinator;

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
}

class _FakeVoicePlaybackGateway implements _InspectableVoicePlaybackGateway {
  @override
  final List<DoseyVoicePhrase> playedPhrases = <DoseyVoicePhrase>[];
  @override
  bool sideEffectsSeen = false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath) async {
    playedPhrases.add(
      FixedPhraseCatalog.phrases
          .singleWhere((phrase) => phrase.assetPath == assetPath)
          .phrase,
    );
  }
}

class _ThrowingVoicePlaybackGateway
    implements _InspectableVoicePlaybackGateway {
  @override
  List<DoseyVoicePhrase> get playedPhrases => const <DoseyVoicePhrase>[];

  @override
  bool get sideEffectsSeen => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath) {
    throw StateError('Playback failed for $assetPath');
  }
}
