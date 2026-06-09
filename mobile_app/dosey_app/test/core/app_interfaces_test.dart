import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
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
}
