import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/controller_reliability_fixture.dart';

void main() {
  group('pre-acceptance reliability', () {
    final cases =
        <
          (
            SimulatedDispenseOutcome,
            Matcher,
            ControllerCommandSessionState,
            CarouselSlotStatus,
          )
        >[
          (
            SimulatedDispenseOutcome.disconnectBeforeAcceptance,
            isA<ControllerTransportOfflineException>(),
            ControllerCommandSessionState.failed,
            CarouselSlotStatus.loaded,
          ),
          (
            SimulatedDispenseOutcome.timeoutBeforeAcceptance,
            isA<ControllerCommandPreAcceptanceTimeoutException>(),
            ControllerCommandSessionState.timedOut,
            CarouselSlotStatus.needsReview,
          ),
        ];

    for (final scenario in cases) {
      test('${scenario.$1.name} preserves conservative state', () async {
        final fixture = await ControllerReliabilityFixture.create();
        addTearDown(fixture.close);
        await fixture.connect();
        fixture.simulator.queueNextDispenseOutcome(scenario.$1);

        await expectLater(fixture.dispense(), throwsA(scenario.$2));

        final history = await fixture.commandHistory();
        expect(history.single.session.state, scenario.$3);
        expect(history.single.session.acceptedAt, isNull);
        expect(await fixture.slotStatus(), scenario.$4);
        expect(await fixture.doseEvents(), isEmpty);
        expect(await fixture.availableDoses(), 1);
      });
    }
  });

  group('ambiguous accepted movement', () {
    final cases =
        <
          (
            SimulatedDispenseOutcome,
            Matcher,
            ControllerCommandSessionState,
            ControllerCommandFailureReason,
            ControllerCommandEventType,
          )
        >[
          (
            SimulatedDispenseOutcome.timeoutAfterAcceptance,
            isA<ControllerCommandTimeoutException>(),
            ControllerCommandSessionState.timedOut,
            ControllerCommandFailureReason.timeout,
            ControllerCommandEventType.controllerError,
          ),
          (
            SimulatedDispenseOutcome.disconnectAfterAcceptance,
            isA<ControllerCommandInterruptedException>(),
            ControllerCommandSessionState.interrupted,
            ControllerCommandFailureReason.disconnect,
            ControllerCommandEventType.offline,
          ),
          (
            SimulatedDispenseOutcome.jamAfterAcceptance,
            isA<ControllerCommandJamException>(),
            ControllerCommandSessionState.failed,
            ControllerCommandFailureReason.jam,
            ControllerCommandEventType.controllerError,
          ),
        ];

    for (final scenario in cases) {
      test('${scenario.$1.name} quarantines the loaded slot', () async {
        final fixture = await ControllerReliabilityFixture.create();
        addTearDown(fixture.close);
        await fixture.connect();
        fixture.simulator.queueNextDispenseOutcome(scenario.$1);

        await expectLater(fixture.dispense(), throwsA(scenario.$2));

        final history = await fixture.commandHistory();
        expect(history.single.session.state, scenario.$3);
        expect(history.single.session.failureReason, scenario.$4);
        expect(history.single.session.acceptedAt, isNotNull);
        expect(history.single.events.map((event) => event.eventType), [
          ControllerCommandEventType.commandSent,
          ControllerCommandEventType.ack,
          ControllerCommandEventType.moveStarted,
          scenario.$5,
        ]);
        expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
        expect(await fixture.doseEvents(), isEmpty);
        expect(await fixture.availableDoses(), 1);
      });
    }
  });

  test(
    'movement, visibility, and taken confirmation remain distinct',
    () async {
      final fixture = await ControllerReliabilityFixture.create();
      addTearDown(fixture.close);
      await fixture.connect();
      final readyState = await fixture.robotState();
      expect(readyState.nextEventLabel, '09:00 · Morning meds');
      expect(readyState.mode, RobotFaceMode.doseReady);

      await fixture.dispense();
      await fixture.settle();

      final history = await fixture.commandHistory();
      expect(history.single.events.map((event) => event.eventType), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
        ControllerCommandEventType.moveStarted,
        ControllerCommandEventType.servoDone,
      ]);
      expect(await fixture.slotStatus(), CarouselSlotStatus.dispensed);
      expect(await fixture.availableDoses(), 1);
      expect(await fixture.doseEvents(), [
        isA<DoseLogEvent>()
            .having(
              (event) => event.kind,
              'kind',
              DoseLogEventKind.controllerDispenseSucceeded,
            )
            .having((event) => event.marksDoseTaken, 'marksDoseTaken', isFalse),
      ]);
      expect(
        (await fixture.robotState()).mode,
        RobotFaceMode.waitingForConfirmation,
      );

      await fixture.recordVisible();
      await fixture.settle();
      expect(
        (await fixture.robotState()).mode,
        RobotFaceMode.waitingForConfirmation,
      );
      expect(
        (await fixture.doseEvents()).where((event) => event.marksDoseTaken),
        isEmpty,
      );

      await fixture.recordTaken();
      await fixture.settle();
      final confirmedEvents = await fixture.doseEvents();
      expect(
        confirmedEvents.where((event) => event.marksDoseTaken),
        hasLength(1),
      );
      expect(confirmedEvents.first.kind, DoseLogEventKind.doseTakenConfirmed);
      expect(
        (await fixture.robotStateWithMode(RobotFaceMode.happyConfirmed)).mode,
        RobotFaceMode.happyConfirmed,
      );
    },
  );

  test(
    'failed reconnect remains offline until heartbeat verification',
    () async {
      final fixture = await ControllerReliabilityFixture.create();
      addTearDown(fixture.close);
      await fixture.connect();
      fixture.simulator
        ..queueNextDispenseOutcome(
          SimulatedDispenseOutcome.disconnectAfterAcceptance,
        )
        ..queueNextConnectOutcome(SimulatedConnectOutcome.failure);

      await expectLater(
        fixture.dispense(),
        throwsA(isA<ControllerCommandInterruptedException>()),
      );
      await fixture.elapse(const Duration(seconds: 2));
      expect(
        fixture.latestController.healthState,
        isNot(ControllerHealthState.online),
      );

      await fixture.elapse(const Duration(seconds: 5));
      expect(
        fixture.latestController.healthState,
        ControllerHealthState.online,
      );
      expect(fixture.latestController.lastSuccessfulHeartbeatAt, fixture.now);
      expect(
        await fixture.healthEventTypes(),
        containsAllInOrder([
          ControllerHealthEventType.offline,
          ControllerHealthEventType.reconnecting,
          ControllerHealthEventType.recovered,
        ]),
      );
    },
  );

  test('diagnostics failures persist failed command history', () async {
    final fixture = await ControllerReliabilityFixture.create();
    addTearDown(fixture.close);
    await fixture.connect();

    for (final scenario in [
      (
        SimulatedDiagnosticsScenario.commandFailure,
        isA<ControllerCommandRejectedException>(),
      ),
      (SimulatedDiagnosticsScenario.incompleteReport, isA<FormatException>()),
    ]) {
      fixture.simulator.queueNextDiagnosticsScenario(scenario.$1);
      await expectLater(fixture.bench.runDiagnostics(), throwsA(scenario.$2));
    }

    final history = await fixture.commandHistory();
    expect(history, hasLength(2));
    for (final entry in history) {
      expect(entry.session.commandType, ControllerCommandType.diagnostics);
      expect(entry.session.state, ControllerCommandSessionState.failed);
      expect(entry.events.map((event) => event.eventType), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.controllerError,
      ]);
    }
  });

  test('heartbeat deadline waits for an active dispense command', () async {
    final fixture = await ControllerReliabilityFixture.create(
      gateDispenseStages: true,
    );
    addTearDown(fixture.close);
    await fixture.connect();

    final dispense = fixture.dispense();
    await fixture.dispenseGate.waitUntilBlocked();
    await fixture.elapse(const Duration(seconds: 10));

    expect(fixture.latestController.healthState, ControllerHealthState.online);
    expect(
      await fixture.healthEventTypes(),
      isNot(contains(ControllerHealthEventType.heartbeatMissed)),
    );

    await fixture.releaseDispenseStagesUntilComplete(dispense);
    await dispense;
    await fixture.elapse(Duration.zero);

    expect(fixture.latestController.lastSuccessfulHeartbeatAt, fixture.now);
    expect(
      await fixture.healthEventTypes(),
      isNot(contains(ControllerHealthEventType.heartbeatMissed)),
    );
  });
}
