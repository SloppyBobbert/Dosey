import 'package:dosey_app/core/controller/controller_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses framed diagnostics into typed sections and readings', () {
    final report = ControllerDiagnosticsRegistry.standard.parse(const [
      'GROVE_DIAGNOSTICS_OK',
      'DIAGNOSTICS_BEGIN',
      'FIRMWARE_DOSEY_CONTROLLER',
      'BOARD_XIAO_ESP32_C6_GROVE_BASE',
      'PIR_RAW_1',
      'LIGHT_RAW_2048',
      'DHT20_PRESENT',
      'MOVEMENT_IDLE',
      'PIR_CALIBRATION_REQUIRED',
      'DIAGNOSTICS_DONE',
    ]);

    expect(report.reading('firmware')?.value, 'Dosey controller');
    expect(report.reading('board')?.value, 'XIAO ESP32-C6 + Grove Base');
    expect(report.reading('pirRaw')?.value, '1 (raw HIGH)');
    expect(report.reading('lightRaw')?.value, '2048 ADC');
    expect(
      report.reading('dht20Presence')?.status,
      ControllerDiagnosticStatus.ok,
    );
    expect(report.reading('movement')?.value, 'Idle');
    expect(
      report.reading('pirCalibration')?.status,
      ControllerDiagnosticStatus.attention,
    );
    expect(
      report.sections.map((section) => section.section),
      containsAll([
        ControllerDiagnosticSection.system,
        ControllerDiagnosticSection.sensors,
        ControllerDiagnosticSection.movement,
        ControllerDiagnosticSection.capabilities,
      ]),
    );
  });

  test('keeps unknown in-frame codes visible for future firmware fields', () {
    final report = ControllerDiagnosticsRegistry.standard.parse(const [
      'DIAGNOSTICS_BEGIN',
      'FUTURE_SENSOR_RAW_42',
      'DIAGNOSTICS_DONE',
    ]);

    final reading = report.readings.single;
    expect(reading.id, 'unknown:FUTURE_SENSOR_RAW_42');
    expect(reading.label, 'Uncatalogued controller field');
    expect(reading.value, 'FUTURE_SENSOR_RAW_42');
    expect(reading.section, ControllerDiagnosticSection.uncatalogued);
  });

  test('rejects an incomplete diagnostics report', () {
    expect(
      () => ControllerDiagnosticsRegistry.standard.parse(const [
        'DIAGNOSTICS_BEGIN',
        'PIR_RAW_0',
      ]),
      throwsFormatException,
    );
  });
}
