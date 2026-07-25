import 'dart:async';

import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'happy path exposes each stage and never treats movement as taken',
    () async {
      final fixture = await _ScenarioFixture.create();
      addTearDown(fixture.close);
      await fixture.service.select(DemoScenarioId.happyPath);

      await fixture.service.next();
      expect(fixture.clock.now(), DateTime.utc(2040, 1, 2, 8, 25));
      await fixture.service.next();
      expect(fixture.clock.now(), DateTime.utc(2040, 1, 2, 8, 30));

      await fixture.service.next();
      expect(await fixture.latestEventTypes(), [
        ControllerCommandEventType.commandSent,
      ]);
      await fixture.service.next();
      expect(await fixture.latestEventTypes(), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
      ]);
      await fixture.service.next();
      expect(await fixture.latestEventTypes(), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
        ControllerCommandEventType.moveStarted,
      ]);
      await fixture.service.next();
      expect(await fixture.latestEventTypes(), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
        ControllerCommandEventType.moveStarted,
        ControllerCommandEventType.servoDone,
      ]);

      var prescription = await fixture.demoPrescription();
      expect(prescription.loadedDoses, 1);
      expect(prescription.usedDoses, 0);
      expect(
        (await fixture.doseEvents()).single.kind,
        DoseLogEventKind.controllerDispenseSucceeded,
      );

      await fixture.service.next();
      expect((await fixture.doseEvents()).map((event) => event.kind), [
        DoseLogEventKind.controllerDispenseSucceeded,
        DoseLogEventKind.doseVisibleConfirmed,
      ]);
      prescription = await fixture.demoPrescription();
      expect(prescription.loadedDoses, 1);
      expect(prescription.usedDoses, 0);

      await fixture.service.next();
      prescription = await fixture.demoPrescription();
      expect(prescription.availableDoses, 13);
      expect(prescription.loadedDoses, 0);
      expect(prescription.usedDoses, 1);
      expect(fixture.service.state.isComplete, isTrue);
    },
  );

  for (final testCase
      in <
        ({
          DemoScenarioId scenario,
          String slotStatus,
          ControllerCommandFailureReason failure,
        })
      >[
        (
          scenario: DemoScenarioId.nack,
          slotStatus: 'loaded',
          failure: ControllerCommandFailureReason.nack,
        ),
        (
          scenario: DemoScenarioId.preAcceptanceTimeout,
          slotStatus: 'needs_review',
          failure: ControllerCommandFailureReason.timeout,
        ),
        (
          scenario: DemoScenarioId.jam,
          slotStatus: 'needs_review',
          failure: ControllerCommandFailureReason.jam,
        ),
        (
          scenario: DemoScenarioId.disconnectAfterAcceptance,
          slotStatus: 'needs_review',
          failure: ControllerCommandFailureReason.disconnect,
        ),
      ]) {
    test('${testCase.scenario.name} preserves the safe slot state', () async {
      final fixture = await _ScenarioFixture.create();
      addTearDown(fixture.close);
      await fixture.service.select(testCase.scenario);

      await fixture.service.next();

      final slot =
          (await fixture.database
                  .select(fixture.database.carouselLoadSlotSnapshots)
                  .get())
              .single;
      final session =
          (await fixture.database
                  .select(fixture.database.controllerCommandSessions)
                  .get())
              .single;
      expect(slot.status, testCase.slotStatus);
      expect(session.failureReason, testCase.failure.name);
      expect(await fixture.doseEvents(), isEmpty);
    });
  }

  test(
    'missed recognition is seen-only and leaves inventory unchanged',
    () async {
      final fixture = await _ScenarioFixture.create();
      addTearDown(fixture.close);
      await fixture.service.select(DemoScenarioId.missedRecognized);

      await fixture.service.next();
      await fixture.service.next();

      expect((await fixture.doseEvents()).map((event) => event.kind), [
        DoseLogEventKind.doseMissed,
        DoseLogEventKind.doseMissedRecognized,
      ]);
      final prescription = await fixture.demoPrescription();
      expect(prescription.availableDoses, 13);
      expect(prescription.loadedDoses, 1);
      expect(prescription.usedDoses, 0);
      expect(prescription.reviewDoses, 0);
    },
  );

  test(
    'offline scenario records missed heartbeat, failed retry, and recovery',
    () async {
      final fixture = await _ScenarioFixture.create();
      addTearDown(fixture.close);
      await fixture.service.select(DemoScenarioId.offlineReconnect);

      await fixture.service.next();
      await fixture.service.next();
      expect(fixture.service.state.lastMessage, 'Reconnect attempt failed');
      await fixture.service.next();

      final history = await fixture.repository.watchRecentHistory().first;
      expect(
        history[1].events.map((event) => event.eventType),
        containsAll([
          ControllerCommandEventType.heartbeatMissed,
          ControllerCommandEventType.offline,
        ]),
      );
      expect(
        history[0].events.map((event) => event.eventType),
        containsAll([
          ControllerCommandEventType.heartbeatOk,
          ControllerCommandEventType.reconnected,
        ]),
      );
    },
  );

  test('serialization scenario rejects a second physical command', () async {
    final fixture = await _ScenarioFixture.create();
    addTearDown(fixture.close);
    await fixture.service.select(DemoScenarioId.globalSerialization);

    await fixture.service.next();
    expect(fixture.service.state.lastMessage, contains('already in progress'));
    await fixture.service.next();

    expect(
      await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get(),
      hasLength(1),
    );
    expect(await fixture.doseEvents(), hasLength(1));
  });

  test(
    'play can pause between steps and restart restores the baseline',
    () async {
      final playbackGate = Completer<void>();
      var delayCalls = 0;
      final fixture = await _ScenarioFixture.create(
        playbackDelay: (_) {
          delayCalls += 1;
          return playbackGate.future;
        },
      );
      addTearDown(fixture.close);
      await fixture.service.select(DemoScenarioId.happyPath);

      final playback = fixture.service.play();
      await fixture.service.states.firstWhere(
        (state) => state.completedSteps == 1,
      );
      fixture.service.pause();
      playbackGate.complete();
      await playback;
      expect(delayCalls, 1);
      expect(fixture.service.state.completedSteps, 1);

      await fixture.service.restart();

      expect(fixture.service.state.completedSteps, 0);
      expect(fixture.clock.now(), _ScenarioFixture.seedTime);
      expect(await fixture.doseEvents(), isEmpty);
      expect(
        await fixture.database
            .select(fixture.database.controllerCommandSessions)
            .get(),
        isEmpty,
      );
    },
  );

  test('select pauses autoplay before resetting the scenario', () async {
    final playbackGate = Completer<void>();
    final fixture = await _ScenarioFixture.create(
      playbackDelay: (_) => playbackGate.future,
    );
    addTearDown(fixture.close);

    final playback = fixture.service.play();
    await fixture.service.states.firstWhere(
      (state) => state.completedSteps == 1,
    );

    final selection = fixture.service.select(DemoScenarioId.missedRecognized);

    expect(fixture.service.state.isPlaying, isFalse);
    playbackGate.complete();
    await Future.wait([playback, selection]);
    expect(fixture.service.state.scenario.id, DemoScenarioId.missedRecognized);
    expect(fixture.service.state.completedSteps, 0);
  });

  test('failed reset blocks steps until a later reset succeeds', () async {
    final fixture = await _ScenarioFixture.create();
    addTearDown(fixture.close);
    await fixture.service.next();
    expect(fixture.service.state.completedSteps, 1);
    await fixture.database.customStatement('''
      CREATE TRIGGER fail_demo_seed
      BEFORE INSERT ON app_settings
      BEGIN
        SELECT RAISE(ABORT, 'seed failed');
      END;
    ''');

    await expectLater(
      fixture.service.select(DemoScenarioId.missedRecognized),
      throwsA(anything),
    );
    await expectLater(fixture.service.next(), throwsStateError);
    expect(fixture.service.state.completedSteps, 1);

    await fixture.database.customStatement('DROP TRIGGER fail_demo_seed');
    await fixture.service.restart();
    expect(fixture.service.state.completedSteps, 0);
    expect(fixture.clock.now(), _ScenarioFixture.seedTime);
    await fixture.service.next();
    expect(fixture.service.state.completedSteps, 1);
  });

  test('presentation starts on a reset happy path and stops cleanly', () async {
    final fixture = await _ScenarioFixture.create();
    addTearDown(fixture.close);
    await fixture.service.select(DemoScenarioId.jam);
    await fixture.service.next();

    await fixture.service.startPresentation();

    expect(fixture.service.state.scenario.id, DemoScenarioId.happyPath);
    expect(fixture.service.state.completedSteps, 0);
    expect(fixture.service.state.isPlaying, isFalse);
    expect(fixture.service.state.isPresenting, isTrue);
    expect(await fixture.doseEvents(), isEmpty);

    fixture.service.stopPresentation();

    expect(fixture.service.state.isPresenting, isFalse);
    expect(fixture.service.state.isPlaying, isFalse);
  });

  test('presentation autoplay uses an audience-readable delay', () async {
    final delays = <Duration>[];
    final playbackGate = Completer<void>();
    final fixture = await _ScenarioFixture.create(
      playbackDelay: (duration) {
        delays.add(duration);
        return playbackGate.future;
      },
    );
    addTearDown(fixture.close);
    await fixture.service.startPresentation();

    final playback = fixture.service.play();
    await fixture.service.states.firstWhere(
      (state) => state.completedSteps == 1,
    );
    fixture.service.pause();
    playbackGate.complete();
    await playback;

    expect(delays, [const Duration(seconds: 2)]);
    expect(fixture.service.state.isPresenting, isTrue);
  });

  test('restart invalidates a step that was already running', () async {
    final fixture = await _ScenarioFixture.create();
    addTearDown(fixture.close);
    await fixture.service.select(DemoScenarioId.happyPath);
    await fixture.service.next();
    await fixture.service.next();
    await fixture.service.next();
    final emittedSteps = <int>[];
    final subscription = fixture.service.states.listen(
      (state) => emittedSteps.add(state.completedSteps),
    );
    addTearDown(subscription.cancel);

    final runningStep = fixture.service.next();
    final restart = fixture.service.restart();
    await Future.wait([runningStep, restart]);
    await Future<void>.delayed(Duration.zero);

    expect(emittedSteps, everyElement(0));
    expect(fixture.service.state.scenario.id, DemoScenarioId.happyPath);
    expect(fixture.service.state.completedSteps, 0);
    expect(fixture.clock.now(), _ScenarioFixture.seedTime);
    expect(await fixture.doseEvents(), isEmpty);
  });
}

class _ScenarioFixture {
  _ScenarioFixture({
    required this.database,
    required this.clock,
    required this.gateway,
    required this.repository,
    required this.service,
  });

  static final seedTime = DateTime.utc(2040, 1, 2, 8);

  final DoseyDatabase database;
  final ControllableAppClock clock;
  final SimulatedControllerGateway gateway;
  final LocalControllerCommandRepository repository;
  final DemoScenarioService service;

  static Future<_ScenarioFixture> create({
    DemoPlaybackDelay? playbackDelay,
  }) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(seedTime);
    final stageGate = DemoStageGate();
    final idGenerator = DemoCommandSessionIdGenerator();
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      delay: stageGate.wait,
    );
    final commandRepository = LocalControllerCommandRepository(
      database,
      sessionIdGenerator: idGenerator.call,
    );
    final doseLog = DriftDoseLogRepository(database);
    final carouselSlots = LocalCarouselSlotRepository(database);
    final guidedLoads = LocalGuidedCarouselLoadRepository(database);
    final prescriptions = LocalPrescriptionRepository(database);
    final lifecycle = ControllerLifecycleService(
      controller: gateway,
      commandRepository: commandRepository,
      doseLog: doseLog,
      carouselSlots: carouselSlots,
      guidedCarouselLoads: guidedLoads,
      database: database,
      now: clock.now,
    );
    final bench = ControllerBenchService(
      controller: gateway,
      lifecycle: lifecycle,
      commandRepository: commandRepository,
      now: clock.now,
    );
    final doseActions = DoseActionService(
      database: database,
      carouselSlots: carouselSlots,
      guidedCarouselLoads: guidedLoads,
      prescriptions: prescriptions,
      doseLog: doseLog,
    );
    final service = DemoScenarioService(
      data: DemoDataRepository(
        database,
        seedTime: seedTime,
        deviceRole: AppDeviceRole.androidRobot,
      ),
      database: database,
      clock: clock,
      controller: gateway,
      stageGate: stageGate,
      idGenerator: idGenerator,
      lifecycle: lifecycle,
      bench: bench,
      commandRepository: commandRepository,
      doseActions: doseActions,
      reconciliation: MissedDoseReconciliationService(
        reminders: LocalReminderRepository(database),
        doseLog: doseLog,
        carouselSlots: carouselSlots,
        database: database,
        now: clock.now,
      ),
      playbackDelay: playbackDelay,
    );
    return _ScenarioFixture(
      database: database,
      clock: clock,
      gateway: gateway,
      repository: commandRepository,
      service: service,
    );
  }

  Future<List<ControllerCommandEventType>> latestEventTypes() async {
    final history = await repository.watchRecentHistory().first;
    return history.single.events.map((event) => event.eventType).toList();
  }

  Future<List<DoseLogEvent>> doseEvents() {
    return DriftDoseLogRepository(database).watchEvents().first;
  }

  Future<PrescriptionRow> demoPrescription() {
    return (database.select(database.prescriptions)
          ..where((row) => row.id.equals(DemoDataRepository.prescriptionId)))
        .getSingle();
  }

  Future<void> close() async {
    await service.close();
    await gateway.close();
    await clock.close();
    await database.close();
  }
}
