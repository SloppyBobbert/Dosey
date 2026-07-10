import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(gateway.requestDispense(doseId: 'morning'), throwsStateError);

    await gateway.connect();
    final snapshot = await gateway.watchController().first;
    expect(snapshot.connectionState, ControllerConnectionState.connected);
    expect(snapshot.canRequestDispense, isTrue);

    await gateway.requestDispense(doseId: 'morning');

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  test(
    'simulated controller rejects dispense without Robot Mode access',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final gateway = SimulatedControllerGateway();
      addTearDown(gateway.close);

      await gateway.connect();

      expect(gateway.requestDispense(doseId: 'morning'), throwsStateError);

      expect(await database.select(database.doseLogEvents).get(), isEmpty);
    },
  );

  test('simulated controller rejects dispense outside Robot Mode', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final gateway = SimulatedControllerGateway(canHostRobot: () async => false);
    addTearDown(gateway.close);

    await gateway.connect();

    expect(gateway.requestDispense(doseId: 'morning'), throwsStateError);

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });
}
