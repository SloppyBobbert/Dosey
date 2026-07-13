import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller snapshot starts disconnected and unsafe for dispense', () {
    const snapshot = ControllerSnapshot.disconnected();

    expect(snapshot.connectionState, ControllerConnectionState.disconnected);
    expect(snapshot.canRequestDispense, isFalse);
    expect(snapshot.statusLabel, 'Controller disconnected');
  });

  test('dose log event distinguishes dispense success from dose taken', () {
    final event = DoseLogEvent.controllerDispenseSucceeded(
      doseId: 'morning-dose',
      occurredAt: DateTime.utc(2026, 6, 8, 12),
    );

    expect(event.kind, DoseLogEventKind.controllerDispenseSucceeded);
    expect(event.marksDoseTaken, isFalse);
    expect(event.doseId, 'morning-dose');
  });

  test('dose taken confirmation is separate from controller dispense', () {
    final event = DoseLogEvent.doseTakenConfirmed(
      doseId: 'morning-dose',
      occurredAt: DateTime.utc(2026, 6, 8, 12, 5),
    );

    expect(event.kind, DoseLogEventKind.doseTakenConfirmed);
    expect(event.marksDoseTaken, isTrue);
    expect(event.doseId, 'morning-dose');
  });

  test('missed recognition stays non-terminal and does not mark taken', () {
    final event = DoseLogEvent.doseMissedRecognized(
      doseId: 'morning-dose',
      occurredAt: DateTime.utc(2026, 6, 8, 12, 10),
    );

    expect(event.kind, DoseLogEventKind.doseMissedRecognized);
    expect(event.marksDoseTaken, isFalse);
    expect(
      TodayNextDoseHelper.isTerminalDoseEventKind(
        DoseLogEventKind.doseMissedRecognized,
      ),
      isFalse,
    );
  });

  test('ble snapshots stay app-owned and protocol agnostic', () {
    const availability = BleAvailabilitySnapshot.available();
    const connection = BleConnectionSnapshot.connected(deviceId: 'dosey-1');

    expect(availability.isAvailable, isTrue);
    expect(connection.state, BleConnectionState.connected);
    expect(connection.deviceId, 'dosey-1');
    expect(connection.deviceName, isNull);
  });

  test('connectivity states distinguish offline wifi cellular and other', () {
    expect(ConnectivityState.values, [
      ConnectivityState.offline,
      ConnectivityState.wifi,
      ConnectivityState.cellular,
      ConnectivityState.other,
    ]);
  });
}
