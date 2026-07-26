enum ControllerDiagnosticSection {
  system,
  safety,
  sensors,
  inputs,
  movement,
  actuators,
  capabilities,
  reliability,
  uncatalogued,
}

enum ControllerDiagnosticStatus { ok, informational, attention, unavailable }

abstract interface class ControllerDiagnosticsGateway {
  Future<ControllerDiagnosticReport> readControllerDiagnostics();
}

class ControllerDiagnosticReading {
  const ControllerDiagnosticReading({
    required this.id,
    required this.section,
    required this.label,
    required this.value,
    required this.status,
    required this.rawCode,
  });

  final String id;
  final ControllerDiagnosticSection section;
  final String label;
  final String value;
  final ControllerDiagnosticStatus status;
  final String rawCode;
}

class ControllerDiagnosticReportSection {
  const ControllerDiagnosticReportSection({
    required this.section,
    required this.readings,
  });

  final ControllerDiagnosticSection section;
  final List<ControllerDiagnosticReading> readings;
}

class ControllerDiagnosticReport {
  const ControllerDiagnosticReport({
    required this.readings,
    required this.rawCodes,
  });

  final List<ControllerDiagnosticReading> readings;
  final List<String> rawCodes;

  ControllerDiagnosticReading? reading(String id) {
    for (final reading in readings) {
      if (reading.id == id) return reading;
    }
    return null;
  }

  List<ControllerDiagnosticReportSection> get sections {
    return [
      for (final section in ControllerDiagnosticSection.values)
        if (readings.any((reading) => reading.section == section))
          ControllerDiagnosticReportSection(
            section: section,
            readings: [
              for (final reading in readings)
                if (reading.section == section) reading,
            ],
          ),
    ];
  }
}

typedef ControllerDiagnosticMatcher = bool Function(String code);
typedef ControllerDiagnosticValue = String Function(String code);
typedef ControllerDiagnosticStatusResolver =
    ControllerDiagnosticStatus Function(String code);

class ControllerDiagnosticDefinition {
  const ControllerDiagnosticDefinition({
    required this.id,
    required this.section,
    required this.label,
    required this.matches,
    required this.value,
    required this.status,
  });

  final String id;
  final ControllerDiagnosticSection section;
  final String label;
  final ControllerDiagnosticMatcher matches;
  final ControllerDiagnosticValue value;
  final ControllerDiagnosticStatusResolver status;
}

class ControllerDiagnosticsRegistry {
  const ControllerDiagnosticsRegistry(this.definitions);

  static final standard = ControllerDiagnosticsRegistry(_standardDefinitions);

  final List<ControllerDiagnosticDefinition> definitions;

  ControllerDiagnosticReport parse(Iterable<String> responseCodes) {
    final codes = responseCodes.toList(growable: false);
    final start = codes.indexOf('DIAGNOSTICS_BEGIN');
    final end = codes.indexOf('DIAGNOSTICS_DONE');
    if (start < 0 || end <= start) {
      throw const FormatException('Incomplete controller diagnostics report.');
    }

    final reportCodes = codes.sublist(start + 1, end);
    final readings = <ControllerDiagnosticReading>[];
    for (final code in reportCodes) {
      ControllerDiagnosticDefinition? definition;
      for (final candidate in definitions) {
        if (candidate.matches(code)) {
          definition = candidate;
          break;
        }
      }
      readings.add(
        definition == null
            ? ControllerDiagnosticReading(
                id: 'unknown:$code',
                section: ControllerDiagnosticSection.uncatalogued,
                label: 'Uncatalogued controller field',
                value: code,
                status: ControllerDiagnosticStatus.informational,
                rawCode: code,
              )
            : ControllerDiagnosticReading(
                id: definition.id,
                section: definition.section,
                label: definition.label,
                value: definition.value(code),
                status: definition.status(code),
                rawCode: code,
              ),
      );
    }
    return ControllerDiagnosticReport(
      readings: readings,
      rawCodes: reportCodes,
    );
  }
}

ControllerDiagnosticDefinition _exact({
  required String id,
  required ControllerDiagnosticSection section,
  required String label,
  required String code,
  required String value,
  ControllerDiagnosticStatus status = ControllerDiagnosticStatus.informational,
}) {
  return ControllerDiagnosticDefinition(
    id: id,
    section: section,
    label: label,
    matches: (candidate) => candidate == code,
    value: (_) => value,
    status: (_) => status,
  );
}

ControllerDiagnosticDefinition _prefix({
  required String id,
  required ControllerDiagnosticSection section,
  required String label,
  required String prefix,
  required String Function(String suffix) value,
  ControllerDiagnosticStatus status = ControllerDiagnosticStatus.informational,
}) {
  return ControllerDiagnosticDefinition(
    id: id,
    section: section,
    label: label,
    matches: (code) => code.startsWith(prefix),
    value: (code) => value(code.substring(prefix.length)),
    status: (_) => status,
  );
}

final List<ControllerDiagnosticDefinition> _standardDefinitions = [
  _exact(
    id: 'firmware',
    section: ControllerDiagnosticSection.system,
    label: 'Firmware',
    code: 'FIRMWARE_DOSEY_CONTROLLER',
    value: 'Dosey controller',
  ),
  _exact(
    id: 'protocol',
    section: ControllerDiagnosticSection.system,
    label: 'Protocol',
    code: 'PROTOCOL_D1',
    value: 'D1',
  ),
  _exact(
    id: 'board',
    section: ControllerDiagnosticSection.system,
    label: 'Board profile',
    code: 'BOARD_XIAO_ESP32_C6_GROVE_BASE',
    value: 'XIAO ESP32-C6 + Grove Base',
  ),
  _prefix(
    id: 'build',
    section: ControllerDiagnosticSection.system,
    label: 'Build',
    prefix: 'BUILD_',
    value: (suffix) => suffix == 'DEBUG' ? 'Debug' : 'Baseline',
  ),
  _prefix(
    id: 'movementTimeout',
    section: ControllerDiagnosticSection.safety,
    label: 'Movement timeout',
    prefix: 'MOVEMENT_TIMEOUT_MS_',
    value: (suffix) => '$suffix ms',
    status: ControllerDiagnosticStatus.ok,
  ),
  _prefix(
    id: 'servoPulse',
    section: ControllerDiagnosticSection.safety,
    label: 'Servo pulse range',
    prefix: 'SERVO_PULSE_US_',
    value: (suffix) => '${suffix.replaceAll('_', '-')} us',
  ),
  _prefix(
    id: 'servoAngles',
    section: ControllerDiagnosticSection.safety,
    label: 'Servo test angles',
    prefix: 'SERVO_ANGLES_DEG_',
    value: (suffix) => '${suffix.replaceAll('_', '-')} degrees',
  ),
  _exact(
    id: 'dispenseNext',
    section: ControllerDiagnosticSection.safety,
    label: 'DISPENSE_NEXT',
    code: 'DISPENSE_NEXT_DISABLED',
    value: 'Disabled',
    status: ControllerDiagnosticStatus.ok,
  ),
  _exact(
    id: 'groveProfile',
    section: ControllerDiagnosticSection.system,
    label: 'Servo port profile',
    code: 'GROVE_BASE_D8_SERVO_PROFILE',
    value: 'Grove Base D8/A8',
  ),
  _prefix(
    id: 'pirRaw',
    section: ControllerDiagnosticSection.sensors,
    label: 'PIR signal',
    prefix: 'PIR_RAW_',
    value: (suffix) => '$suffix (raw ${suffix == '1' ? 'HIGH' : 'LOW'})',
  ),
  _prefix(
    id: 'lightRaw',
    section: ControllerDiagnosticSection.sensors,
    label: 'Light sensor',
    prefix: 'LIGHT_RAW_',
    value: (suffix) => '$suffix ADC',
  ),
  for (final entry in const [
    ('button1A', 'Button 1A', 'BUTTON_1A_RAW_'),
    ('button1B', 'Button 1B', 'BUTTON_1B_RAW_'),
    ('button2A', 'Button 2A', 'BUTTON_2A_RAW_'),
    ('button2B', 'Button 2B', 'BUTTON_2B_RAW_'),
  ])
    _prefix(
      id: entry.$1,
      section: ControllerDiagnosticSection.inputs,
      label: entry.$2,
      prefix: entry.$3,
      value: (suffix) => '$suffix (raw ${suffix == '1' ? 'HIGH' : 'LOW'})',
    ),
  ControllerDiagnosticDefinition(
    id: 'dht20Presence',
    section: ControllerDiagnosticSection.sensors,
    label: 'DHT20',
    matches: (code) => code == 'DHT20_PRESENT' || code == 'DHT20_NOT_FOUND',
    value: (code) => code == 'DHT20_PRESENT' ? 'Detected' : 'Not found',
    status: (code) => code == 'DHT20_PRESENT'
        ? ControllerDiagnosticStatus.ok
        : ControllerDiagnosticStatus.attention,
  ),
  ControllerDiagnosticDefinition(
    id: 'pirWake',
    section: ControllerDiagnosticSection.sensors,
    label: 'PIR wake events',
    matches: (code) =>
        code == 'PIR_WAKE_ENABLED' || code == 'PIR_WAKE_DISABLED',
    value: (code) => code == 'PIR_WAKE_ENABLED' ? 'Enabled' : 'Disabled',
    status: (code) => code == 'PIR_WAKE_ENABLED'
        ? ControllerDiagnosticStatus.ok
        : ControllerDiagnosticStatus.unavailable,
  ),
  ControllerDiagnosticDefinition(
    id: 'servo',
    section: ControllerDiagnosticSection.actuators,
    label: 'Servo path',
    matches: (code) => code == 'SERVO_ENABLED' || code == 'SERVO_DISABLED',
    value: (code) => code == 'SERVO_ENABLED' ? 'Configured' : 'Disabled',
    status: (code) => code == 'SERVO_ENABLED'
        ? ControllerDiagnosticStatus.ok
        : ControllerDiagnosticStatus.unavailable,
  ),
  ControllerDiagnosticDefinition(
    id: 'movement',
    section: ControllerDiagnosticSection.movement,
    label: 'Movement state',
    matches: (code) => code == 'MOVEMENT_IDLE' || code == 'MOVEMENT_ACTIVE',
    value: (code) => code == 'MOVEMENT_IDLE' ? 'Idle' : 'Active',
    status: (code) => code == 'MOVEMENT_IDLE'
        ? ControllerDiagnosticStatus.ok
        : ControllerDiagnosticStatus.attention,
  ),
  _exact(
    id: 'dht20Readings',
    section: ControllerDiagnosticSection.capabilities,
    label: 'DHT20 values',
    code: 'DHT20_READING_AWAITING_VALIDATION',
    value: 'Awaiting supervised validation',
    status: ControllerDiagnosticStatus.attention,
  ),
  _exact(
    id: 'buttonEvents',
    section: ControllerDiagnosticSection.capabilities,
    label: 'Button events',
    code: 'BUTTON_EVENTS_AWAITING_VALIDATION',
    value: 'Awaiting supervised validation',
    status: ControllerDiagnosticStatus.attention,
  ),
  _exact(
    id: 'pirCalibration',
    section: ControllerDiagnosticSection.capabilities,
    label: 'PIR active level',
    code: 'PIR_CALIBRATION_REQUIRED',
    value: 'Calibration required',
    status: ControllerDiagnosticStatus.attention,
  ),
  ControllerDiagnosticDefinition(
    id: 'buzzerTest',
    section: ControllerDiagnosticSection.capabilities,
    label: 'Buzzer test',
    matches: (code) =>
        code == 'BUZZER_TEST_AVAILABLE' || code == 'BUZZER_TEST_DISABLED',
    value: (code) => code == 'BUZZER_TEST_AVAILABLE'
        ? 'Available with supervision'
        : 'Disabled',
    status: (code) => code == 'BUZZER_TEST_AVAILABLE'
        ? ControllerDiagnosticStatus.attention
        : ControllerDiagnosticStatus.unavailable,
  ),
  _exact(
    id: 'ledTest',
    section: ControllerDiagnosticSection.capabilities,
    label: 'Onboard LED test',
    code: 'LED_TEST_AVAILABLE',
    value: 'Available',
    status: ControllerDiagnosticStatus.ok,
  ),
  _exact(
    id: 'reliabilitySession',
    section: ControllerDiagnosticSection.reliability,
    label: 'Reliability session',
    code: 'RELIABILITY_SESSION_NOT_STARTED',
    value: 'Not started',
    status: ControllerDiagnosticStatus.attention,
  ),
];
