import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/controller/ble_controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispense test reports accepted and movement stages', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();
    final stages = <ControllerDispenseStage>[];

    final request = gateway.requestStagedDispense(
      doseId: 'manual-test',
      movement: ControllerMovementCommand.dispenseTest,
      onStage: (stage) async => stages.add(stage),
    );
    final id = _commandId(transport.writes.single);
    transport.emit('D1 EVT $id COMMAND_RECEIVED\n');
    transport.emit('D1 EVT $id MOVEMENT_STARTED\n');
    transport.emit('D1 EVT $id SERVO_DONE\n');
    await request;

    expect(stages, [
      ControllerDispenseStage.accepted,
      ControllerDispenseStage.movementStarted,
    ]);
    expect(_commandName(transport.writes.single), 'DISPENSE_TEST');
  });

  test('scheduled dispense remains a distinct disabled command', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    final request = gateway.requestDispense(doseId: 'dose-1');
    final id = _commandId(transport.writes.single);
    transport.emit('D1 NACK $id COMMAND_DISABLED\n');

    await expectLater(
      request,
      throwsA(isA<ControllerCommandRejectedException>()),
    );
    expect(_commandName(transport.writes.single), 'DISPENSE_NEXT');
  });

  test('disconnect after receipt is an interrupted command', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    final request = gateway.requestStagedDispense(
      doseId: 'manual-test',
      movement: ControllerMovementCommand.servoTest,
      onStage: (_) async {},
    );
    final id = _commandId(transport.writes.single);
    transport.emit('D1 EVT $id COMMAND_RECEIVED\n');
    await Future<void>.delayed(Duration.zero);
    await transport.disconnect();

    await expectLater(
      request,
      throwsA(isA<ControllerCommandInterruptedException>()),
    );
  });

  test('disconnect before receipt is a definite offline failure', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    final request = gateway.requestStagedDispense(
      doseId: 'manual-test',
      movement: ControllerMovementCommand.servoTest,
      onStage: (_) async {},
    );
    final expectation = expectLater(
      request,
      throwsA(isA<ControllerTransportOfflineException>()),
    );
    await transport.disconnect();
    await Future<void>.delayed(Duration.zero);

    await expectation;
  });

  test('movement timeout after receipt stays unresolved', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    final request = gateway.requestStagedDispense(
      doseId: 'manual-test',
      movement: ControllerMovementCommand.servoTest,
      onStage: (_) async {},
    );
    final id = _commandId(transport.writes.single);
    transport.emit('D1 EVT $id COMMAND_RECEIVED\n');
    transport.emit('D1 ERROR $id MOVEMENT_TIMEOUT\n');

    await expectLater(
      request,
      throwsA(isA<ControllerCommandTimeoutException>()),
    );
  });

  test('diagnostic command returns exact response transcript', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    final request = gateway.runBenchCommand(ControllerBenchCommand.status);
    final id = _commandId(transport.writes.single);
    transport.emit('D1 EVT $id COMMAND_RECEIVED\n');
    transport.emit('D1 EVT $id MOVEMENT_STARTED\n');
    transport.emit('D1 EVT $id STATUS_OK\n');
    transport.emit('D1 EVT $id SERVO_UNCONFIGURED\n');
    transport.emit('D1 EVT $id PIR_UNCONFIGURED\n');
    transport.emit('D1 EVT $id MOVEMENT_IDLE\n');

    expect(
      await request,
      'MOVEMENT_STARTED, STATUS_OK, SERVO_UNCONFIGURED, PIR_UNCONFIGURED, MOVEMENT_IDLE',
    );
  });

  test('readiness commands complete on their terminal events', () async {
    final transport = _FakeDoseyBleGateway();
    final gateway = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      commandTimeout: const Duration(seconds: 1),
    );
    addTearDown(gateway.close);
    await gateway.connect();

    for (final scenario in [
      (ControllerBenchCommand.deviceInfo, 'BUILD_BASELINE'),
      (ControllerBenchCommand.configStatus, 'UART_RESERVED_SERVO_D6_PROFILE'),
      (ControllerBenchCommand.safetyStatus, 'DISPENSE_NEXT_DISABLED'),
      (ControllerBenchCommand.debugOn, 'DEBUG_ON'),
      (ControllerBenchCommand.debugOff, 'DEBUG_OFF'),
    ]) {
      final request = gateway.runBenchCommand(scenario.$1);
      final id = _commandId(transport.writes.last);
      transport.emit('D1 EVT $id COMMAND_RECEIVED\n');
      transport.emit('D1 EVT $id ${scenario.$2}\n');
      expect(await request, scenario.$2);
    }
  });

  test(
    'stage callback failures fail the command and preserve decoding',
    () async {
      final transport = _FakeDoseyBleGateway();
      final gateway = BleControllerGateway(
        transport: transport,
        canHostRobot: () => true,
        commandTimeout: const Duration(seconds: 1),
      );
      addTearDown(gateway.close);
      await gateway.connect();

      final request = gateway.requestStagedDispense(
        doseId: 'manual-test',
        movement: ControllerMovementCommand.servoTest,
        onStage: (_) async => throw StateError('stage persistence failed'),
      );
      final expectation = expectLater(request, throwsStateError);
      final movementId = _commandId(transport.writes.single);
      transport.emit('D1 EVT $movementId COMMAND_RECEIVED\n');
      await expectation;

      final heartbeat = gateway.runBenchCommand(
        ControllerBenchCommand.heartbeat,
      );
      final heartbeatId = _commandId(transport.writes.last);
      transport.emit('D1 EVT $heartbeatId COMMAND_RECEIVED\n');
      transport.emit('D1 EVT $heartbeatId HEARTBEAT_OK\n');
      expect(await heartbeat, 'HEARTBEAT_OK');
    },
  );

  test(
    'connect stops before scanning when Bluetooth access is denied',
    () async {
      final transport = _FakeDoseyBleGateway();
      final gateway = BleControllerGateway(
        transport: transport,
        canHostRobot: () => true,
        prepareBleAccess: () async => false,
      );
      addTearDown(gateway.close);

      await expectLater(
        gateway.connect(),
        throwsA(isA<ControllerCommandPreconditionException>()),
      );
      expect(transport.connectCount, 0);
    },
  );
}

String _commandId(List<int> bytes) {
  return String.fromCharCodes(bytes).trim().split(' ')[2];
}

String _commandName(List<int> bytes) {
  return String.fromCharCodes(bytes).trim().split(' ')[3];
}

class _FakeDoseyBleGateway implements DoseyBleGateway {
  final _availability = StreamController<BleAvailabilitySnapshot>.broadcast();
  final _connection = StreamController<BleConnectionSnapshot>.broadcast();
  final _protocol = StreamController<List<int>>.broadcast();
  final writes = <List<int>>[];
  int connectCount = 0;

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() => _availability.stream;

  @override
  Stream<BleConnectionSnapshot> watchConnection() => _connection.stream;

  @override
  Stream<List<int>> watchProtocolBytes() => _protocol.stream;

  @override
  Future<void> connectToDosey() async {
    connectCount += 1;
    _connection.add(
      const BleConnectionSnapshot.connected(
        deviceId: 'dosey-1',
        deviceName: D1Protocol.deviceName,
      ),
    );
  }

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {}

  @override
  Future<void> disconnect() async {
    _connection.add(const BleConnectionSnapshot.disconnected());
  }

  @override
  Future<void> writeProtocolBytes(List<int> bytes) async {
    writes.add(List<int>.from(bytes));
  }

  void emit(String value) => _protocol.add(value.codeUnits);

  @override
  Future<void> close() async {
    await _availability.close();
    await _connection.close();
    await _protocol.close();
  }
}
