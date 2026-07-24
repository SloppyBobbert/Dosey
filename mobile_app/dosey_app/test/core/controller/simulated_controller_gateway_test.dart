import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulated controller reports accepted then movement started', () async {
    final stages = <ControllerDispenseStage>[];
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      delay: (_) async {},
    );
    addTearDown(gateway.close);
    await gateway.connect();

    await gateway.requestStagedDispense(
      doseId: 'morning',
      onStage: (stage) async => stages.add(stage),
    );

    expect(stages, [
      ControllerDispenseStage.accepted,
      ControllerDispenseStage.movementStarted,
    ]);
  });

  test('pre-accept timeout reports no accepted stage', () async {
    final stages = <ControllerDispenseStage>[];
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.timeoutBeforeAcceptance,
      delay: (_) async {},
    );
    addTearDown(gateway.close);
    await gateway.connect();

    await expectLater(
      gateway.requestStagedDispense(
        doseId: 'morning',
        onStage: (stage) async => stages.add(stage),
      ),
      throwsA(isA<ControllerCommandPreAcceptanceTimeoutException>()),
    );
    expect(stages, isEmpty);
  });

  test('jam occurs after accepted and movement started stages', () async {
    final stages = <ControllerDispenseStage>[];
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.jamAfterAcceptance,
      delay: (_) async {},
    );
    addTearDown(gateway.close);
    await gateway.connect();

    await expectLater(
      gateway.requestStagedDispense(
        doseId: 'morning',
        onStage: (stage) async => stages.add(stage),
      ),
      throwsA(isA<ControllerCommandJamException>()),
    );
    expect(stages, [
      ControllerDispenseStage.accepted,
      ControllerDispenseStage.movementStarted,
    ]);
  });

  test('simulated controller starts disconnected and unsafe', () async {
    final gateway = SimulatedControllerGateway();
    addTearDown(gateway.close);

    final snapshot = await gateway.watchController().first;

    expect(snapshot.connectionState, ControllerConnectionState.disconnected);
    expect(snapshot.canRequestDispense, isFalse);
  });

  test('simulated controller gates dispense on connection', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final gateway = SimulatedControllerGateway(canHostRobot: () => true);
    addTearDown(gateway.close);

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerCommandPreconditionException>()),
    );

    await gateway.connect();
    final snapshot = await gateway.watchController().first;
    expect(snapshot.connectionState, ControllerConnectionState.connected);
    expect(snapshot.canRequestDispense, isTrue);

    await gateway.requestDispense(doseId: 'morning');

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  test('simulated controller can reject before acceptance with nack', () async {
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.rejected,
    );
    addTearDown(gateway.close);

    await gateway.connect();

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerCommandRejectedException>()),
    );
  });

  test('simulated controller can fail after acceptance with timeout', () async {
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.timeoutAfterAcceptance,
    );
    addTearDown(gateway.close);

    await gateway.connect();

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerCommandTimeoutException>()),
    );
  });

  test('simulated controller can fail after acceptance with jam', () async {
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.jamAfterAcceptance,
    );
    addTearDown(gateway.close);

    await gateway.connect();

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerCommandJamException>()),
    );
  });

  test(
    'simulated controller can lose transport after ambiguous acceptance',
    () async {
      final gateway = SimulatedControllerGateway(
        canHostRobot: () => true,
        nextDispenseOutcome: SimulatedDispenseOutcome.disconnectAfterAcceptance,
      );
      addTearDown(gateway.close);

      await gateway.connect();

      expect(
        gateway.requestDispense(doseId: 'morning'),
        throwsA(isA<ControllerCommandInterruptedException>()),
      );
    },
  );

  test(
    'simulated controller rejects dispense without Robot Mode access',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final gateway = SimulatedControllerGateway();
      addTearDown(gateway.close);

      await gateway.connect();

      expect(
        gateway.requestDispense(doseId: 'morning'),
        throwsA(isA<ControllerCommandPreconditionException>()),
      );

      expect(await database.select(database.doseLogEvents).get(), isEmpty);
    },
  );

  test('simulated controller rejects dispense outside Robot Mode', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final gateway = SimulatedControllerGateway(canHostRobot: () async => false);
    addTearDown(gateway.close);

    await gateway.connect();

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerCommandPreconditionException>()),
    );

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  test(
    'simulated controller can fail before acceptance with offline',
    () async {
      final gateway = SimulatedControllerGateway(
        canHostRobot: () => true,
        nextDispenseOutcome: SimulatedDispenseOutcome.offlineBeforeAcceptance,
      );
      addTearDown(gateway.close);

      await gateway.connect();

      expect(
        gateway.requestDispense(doseId: 'morning'),
        throwsA(isA<ControllerTransportOfflineException>()),
      );
    },
  );

  test('simulated controller can disconnect before acceptance', () async {
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      nextDispenseOutcome: SimulatedDispenseOutcome.disconnectBeforeAcceptance,
    );
    addTearDown(gateway.close);

    await gateway.connect();

    expect(
      gateway.requestDispense(doseId: 'morning'),
      throwsA(isA<ControllerTransportOfflineException>()),
    );
  });
}
