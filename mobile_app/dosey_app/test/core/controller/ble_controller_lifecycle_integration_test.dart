import 'dart:async';

import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ble_controller_lifecycle_fixture.dart';
import '../../support/fake_flutter_blue_plus_plugin.dart';

void main() {
  test(
    'native connection stays fail-closed until heartbeat verification',
    () async {
      final fixture = await BleControllerLifecycleFixture.create();
      addTearDown(fixture.close);

      final connection = fixture.connect();
      final heartbeat = await fixture.nextCommand(D1Command.heartbeat);
      expect(
        fixture.latestController.healthState,
        ControllerHealthState.verifying,
      );
      expect(fixture.latestController.canRequestDispense, isFalse);

      fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
      fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
      await connection;
      await fixture.settle();

      expect(
        fixture.latestController.healthState,
        ControllerHealthState.online,
      );
      expect(fixture.latestController.canRequestDispense, isTrue);
    },
  );

  test('missing controller remains offline and schedules recovery', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    fixture.plugin.scanResult = null;

    await expectLater(fixture.connect(), throwsStateError);

    expect(fixture.latestController.healthState, ControllerHealthState.offline);
    expect(fixture.latestController.canRequestDispense, isFalse);
    expect(fixture.scheduler.pendingTimerCount, 1);
    expect(fixture.plugin.connectCalls, isEmpty);
  });

  test('missing protocol characteristics remain fail-closed', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    fixture.plugin.protocolDiscovered = false;

    await expectLater(fixture.connect(), throwsStateError);

    expect(fixture.latestController.healthState, ControllerHealthState.offline);
    expect(fixture.latestController.canRequestDispense, isFalse);
    expect(fixture.scheduler.pendingTimerCount, 1);
    expect(fixture.plugin.disconnectCalls, [
      FakeFlutterBluePlusPlugin.deviceId,
    ]);
  });

  test('permission denial suppresses automatic BLE recovery', () async {
    final fixture = await BleControllerLifecycleFixture.create(
      prepareBleAccess: () async => false,
    );
    addTearDown(fixture.close);

    await expectLater(
      fixture.connect(),
      throwsA(isA<ControllerCommandPreconditionException>()),
    );
    await fixture.settle();

    expect(fixture.latestController.healthState, ControllerHealthState.error);
    expect(fixture.latestController.canRequestDispense, isFalse);
    expect(fixture.scheduler.pendingTimerCount, 0);
    expect(fixture.plugin.scanServiceUuids, isEmpty);
  });

  test(
    'failed initial heartbeat stays offline and schedules recovery',
    () async {
      final fixture = await BleControllerLifecycleFixture.create(
        commandTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.connect(),
        throwsA(isA<ControllerCommandPreAcceptanceTimeoutException>()),
      );

      expect(
        fixture.latestController.healthState,
        ControllerHealthState.offline,
      );
      expect(fixture.latestController.canRequestDispense, isFalse);
      expect(fixture.scheduler.pendingTimerCount, 1);
    },
  );

  test(
    'supervisor propagates native disconnect to an active command',
    () async {
      final fixture = await BleControllerLifecycleFixture.create();
      addTearDown(fixture.close);
      await _connectVerified(fixture);

      final request = fixture.supervisor.requestStagedDispense(
        doseId: 'direct-supervisor-test',
        onStage: (_) async {},
      );
      await fixture.nextCommand(D1Command.dispenseNext);
      final expectation = expectLater(
        request,
        throwsA(isA<ControllerTransportOfflineException>()),
      );
      fixture.plugin.emitDisconnected();

      await expectation;
    },
  );

  test(
    'production BLE success persists movement without inferring intake',
    () async {
      final fixture = await BleControllerLifecycleFixture.create();
      addTearDown(fixture.close);
      await _connectVerified(fixture);

      final request = fixture.dispense();
      final command = await fixture.nextCommand(D1Command.dispenseNext);
      fixture.emitRaw(
        'D1 EVT ${command.id} COMMAND_RECEIVED\n'
        'D1 EVT ${command.id} MOVEMENT_STARTED\n'
        'D1 EVT ${command.id} SERVO_DONE\n',
        chunkSizes: [7, 13, 5],
      );
      await request;

      final history = await fixture.commandHistory();
      expect(history.single.events.map((event) => event.eventType), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
        ControllerCommandEventType.moveStarted,
        ControllerCommandEventType.servoDone,
      ]);
      expect(
        history.single.session.state,
        ControllerCommandSessionState.succeeded,
      );
      expect(await fixture.slotStatus(), CarouselSlotStatus.dispensed);
      expect(await fixture.availableDoses(), 1);
      final events = await fixture.doseEvents();
      expect(events.single.kind, DoseLogEventKind.controllerDispenseSucceeded);
      expect(events.single.marksDoseTaken, isFalse);
    },
  );

  test('pre-acceptance NACK leaves the loaded dose untouched', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitNack(command, 'COMMAND_DISABLED');

    await expectLater(
      request,
      throwsA(isA<ControllerCommandRejectedException>()),
    );
    final history = await fixture.commandHistory();
    expect(history.single.session.state, ControllerCommandSessionState.failed);
    expect(
      history.single.session.failureReason,
      ControllerCommandFailureReason.nack,
    );
    expect(await fixture.slotStatus(), CarouselSlotStatus.loaded);
    expect(await fixture.doseEvents(), isEmpty);
  });

  test(
    'native disconnect before acceptance is definite offline failure',
    () async {
      final fixture = await BleControllerLifecycleFixture.create();
      addTearDown(fixture.close);
      await _connectVerified(fixture);

      final request = fixture.dispense();
      await fixture.nextCommand(D1Command.dispenseNext);
      final expectation = expectLater(
        request,
        throwsA(isA<ControllerTransportOfflineException>()),
      );
      fixture.plugin.emitDisconnected();

      await expectation;
      await fixture.settle();
      final history = await fixture.commandHistory();
      expect(history.single.session.acceptedAt, isNull);
      expect(
        history.single.session.failureReason,
        ControllerCommandFailureReason.offline,
      );
      expect(await fixture.slotStatus(), CarouselSlotStatus.loaded);
      expect(await fixture.doseEvents(), isEmpty);
      expect(
        fixture.latestController.healthState,
        ControllerHealthState.offline,
      );
    },
  );

  test('native disconnect after acceptance quarantines the slot', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitEvent(command, 'COMMAND_RECEIVED');
    fixture.emitEvent(command, 'MOVEMENT_STARTED');
    await fixture.settle();
    final expectation = expectLater(
      request,
      throwsA(isA<ControllerCommandInterruptedException>()),
    );
    fixture.plugin.emitDisconnected();

    await expectation;
    final history = await fixture.commandHistory();
    expect(history.single.session.acceptedAt, isNotNull);
    expect(
      history.single.session.failureReason,
      ControllerCommandFailureReason.disconnect,
    );
    expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
    expect(await fixture.doseEvents(), isEmpty);
  });

  test('silent timeout remains ambiguous and quarantines the slot', () async {
    final fixture = await BleControllerLifecycleFixture.create(
      commandTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    await fixture.nextCommand(D1Command.dispenseNext);

    await expectLater(
      request,
      throwsA(isA<ControllerCommandPreAcceptanceTimeoutException>()),
    );
    final history = await fixture.commandHistory();
    expect(history.single.session.acceptedAt, isNull);
    expect(
      history.single.session.state,
      ControllerCommandSessionState.timedOut,
    );
    expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
    expect(await fixture.doseEvents(), isEmpty);
  });

  test('firmware movement timeout quarantines accepted movement', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitEvent(command, 'COMMAND_RECEIVED');
    fixture.emitEvent(command, 'MOVEMENT_STARTED');
    fixture.emitError(command, 'MOVEMENT_TIMEOUT');

    await expectLater(
      request,
      throwsA(isA<ControllerCommandTimeoutException>()),
    );
    final history = await fixture.commandHistory();
    expect(history.single.session.acceptedAt, isNotNull);
    expect(
      history.single.session.state,
      ControllerCommandSessionState.timedOut,
    );
    expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
    expect(await fixture.doseEvents(), isEmpty);
  });

  test('unrelated command IDs cannot complete pending movement', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitRaw(
      'D1 EVT other COMMAND_RECEIVED\n'
      'D1 EVT other MOVEMENT_STARTED\n'
      'D1 EVT other SERVO_DONE\n',
    );
    await fixture.settle();
    expect(
      (await fixture.commandHistory()).single.events.map(
        (event) => event.eventType,
      ),
      [ControllerCommandEventType.commandSent],
    );

    fixture.emitEvent(command, 'COMMAND_RECEIVED');
    fixture.emitEvent(command, 'MOVEMENT_STARTED');
    fixture.emitEvent(command, 'SERVO_DONE');
    await request;
  });

  test('wake events remain independent of pending command IDs', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitRaw(
      'D1 EVT pir WAKE_FACE\n'
      'D1 EVT other COMMAND_RECEIVED\n'
      'D1 EVT other MOVEMENT_STARTED\n'
      'D1 EVT other SERVO_DONE\n',
    );
    await fixture.settle();

    expect(fixture.controllerEvents, [ControllerEvent.wakeFace]);
    expect(
      (await fixture.commandHistory()).single.events.map(
        (event) => event.eventType,
      ),
      [ControllerCommandEventType.commandSent],
    );
    fixture.emitEvent(command, 'COMMAND_RECEIVED');
    fixture.emitEvent(command, 'MOVEMENT_STARTED');
    fixture.emitEvent(command, 'SERVO_DONE');
    await request;
  });

  test('malformed active response fails closed and decoder recovers', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    await fixture.nextCommand(D1Command.dispenseNext);
    final expectation = expectLater(
      request,
      throwsA(isA<ControllerCommandInterruptedException>()),
    );
    fixture.emitRaw('not a D1 response\n');
    await expectation;

    expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
    expect(await fixture.doseEvents(), isEmpty);
    expect(fixture.latestController.healthState, ControllerHealthState.offline);
    expect(fixture.scheduler.pendingTimerCount, 1);
    await _reconnectVerified(fixture);
    expect(fixture.latestController.healthState, ControllerHealthState.online);
  });

  test('oversized active response fails closed and decoder recovers', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    await fixture.nextCommand(D1Command.dispenseNext);
    final expectation = expectLater(
      request,
      throwsA(isA<ControllerCommandInterruptedException>()),
    );
    fixture.emitRaw(
      '${List.filled(D1Protocol.maxLineLength + 1, 'x').join()}\n',
    );
    await expectation;

    expect(await fixture.slotStatus(), CarouselSlotStatus.needsReview);
    expect(fixture.scheduler.pendingTimerCount, 1);
    await _reconnectVerified(fixture);
    expect(fixture.latestController.healthState, ControllerHealthState.online);
  });

  test('reconnect remains fail-closed until a fresh heartbeat', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    fixture.plugin.emitDisconnected();
    await fixture.settle();
    expect(fixture.latestController.healthState, ControllerHealthState.offline);
    await fixture.elapse(const Duration(seconds: 2));
    final heartbeat = await fixture.nextCommand(D1Command.heartbeat);

    expect(
      fixture.latestController.healthState,
      ControllerHealthState.verifying,
    );
    expect(fixture.latestController.canRequestDispense, isFalse);
    fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
    fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
    await fixture.settle();
    expect(fixture.latestController.healthState, ControllerHealthState.online);
    expect(
      await fixture.healthEventTypes(),
      contains(ControllerHealthEventType.recovered),
    );
  });

  test('adapter unavailable suppresses retries until recovery', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    fixture.plugin.emitAdapter(PluginBleAdapterState.off);
    await fixture.settle();

    expect(fixture.latestController.healthState, ControllerHealthState.error);
    expect(
      fixture.latestController.errorKind,
      ControllerErrorKind.bluetoothUnavailable,
    );
    expect(fixture.scheduler.pendingTimerCount, 0);

    fixture.plugin.emitAdapter(PluginBleAdapterState.on);
    final heartbeat = await fixture.nextCommand(D1Command.heartbeat);
    expect(
      fixture.latestController.healthState,
      ControllerHealthState.verifying,
    );
    fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
    fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
    await fixture.settle();
    expect(fixture.latestController.healthState, ControllerHealthState.online);
  });

  test('monitoring pause cancels an in-flight scan result', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    final scanGate = Completer<void>();
    fixture.plugin.scanGate = scanGate;

    final connection = fixture.connect();
    await fixture.settle();
    expect(fixture.plugin.scanServiceUuids, hasLength(1));

    await fixture.supervisor.setMonitoringEligible(false);
    scanGate.complete();
    await connection;
    await fixture.settle();

    expect(fixture.plugin.cancelScanCalls, 1);
    expect(fixture.plugin.connectCalls, isEmpty);
    expect(
      fixture.latestController.healthState,
      ControllerHealthState.disconnected,
    );
    expect(
      fixture.plugin.writtenLines.where((line) => line.endsWith('HEARTBEAT')),
      isEmpty,
    );
  });

  test('monitoring pause cancels stale notification setup', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    final notificationGate = Completer<void>();
    fixture.plugin.notificationGate = notificationGate;

    final connection = fixture.connect();
    for (
      var attempt = 0;
      fixture.plugin.notificationCalls.isEmpty && attempt < 100;
      attempt += 1
    ) {
      await fixture.settle();
    }
    expect(fixture.plugin.notificationCalls, isNotEmpty);

    await fixture.supervisor.setMonitoringEligible(false);
    notificationGate.complete();
    await connection;
    await fixture.settle();

    expect(fixture.plugin.disconnectCalls, isNotEmpty);
    expect(
      fixture.latestController.healthState,
      ControllerHealthState.disconnected,
    );
    expect(
      fixture.plugin.writtenLines.where((line) => line.endsWith('HEARTBEAT')),
      isEmpty,
    );
  });

  test('heartbeat waits until active movement completes', () async {
    final fixture = await BleControllerLifecycleFixture.create();
    addTearDown(fixture.close);
    await _connectVerified(fixture);

    final request = fixture.dispense();
    final command = await fixture.nextCommand(D1Command.dispenseNext);
    fixture.emitEvent(command, 'COMMAND_RECEIVED');
    fixture.emitEvent(command, 'MOVEMENT_STARTED');
    await fixture.settle();
    final writesBeforeHeartbeat = fixture.plugin.writtenLines.length;
    await fixture.elapse(const Duration(seconds: 10));
    expect(fixture.plugin.writtenLines, hasLength(writesBeforeHeartbeat));

    fixture.emitEvent(command, 'SERVO_DONE');
    await request;
    await fixture.elapse(Duration.zero);
    final heartbeat = await fixture.nextCommand(D1Command.heartbeat);
    fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
    fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
    await fixture.settle();
    expect(
      await fixture.healthEventTypes(),
      isNot(contains(ControllerHealthEventType.heartbeatMissed)),
    );
  });
}

Future<void> _connectVerified(BleControllerLifecycleFixture fixture) async {
  final connection = fixture.connect();
  final heartbeat = await fixture.nextCommand(D1Command.heartbeat);
  fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
  fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
  await connection;
  await fixture.settle();
}

Future<void> _reconnectVerified(BleControllerLifecycleFixture fixture) async {
  await fixture.elapse(const Duration(seconds: 2));
  expect(fixture.plugin.connectCalls, hasLength(2));
  expect(fixture.latestController.healthState, ControllerHealthState.verifying);
  final heartbeat = await fixture.nextCommand(D1Command.heartbeat);
  fixture.emitEvent(heartbeat, 'COMMAND_RECEIVED');
  fixture.emitEvent(heartbeat, 'HEARTBEAT_OK');
  await fixture.settle();
}
