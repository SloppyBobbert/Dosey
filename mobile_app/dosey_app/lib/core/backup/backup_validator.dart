import 'dart:convert';

import 'backup_document.dart';

const portableSettingKeys = <String>{
  'household_display_name',
  'profile_display_name',
  'relationship_label',
  'robot_face_voice_enabled',
  'robot_face_voice_variety_enabled',
  'robot_face_voice_volume_preset',
  'robot_face_voice_quiet_hours_enabled',
  'robot_face_voice_quiet_hours_start_minutes',
  'robot_face_voice_quiet_hours_end_minutes',
  'robot_face_voice_safety_during_quiet_hours_enabled',
  'robot_face_reminder_voice_enabled',
  'robot_face_dispense_narration_enabled',
  'robot_face_safety_confirmation_voice_enabled',
  'robot_face_missed_dose_voice_enabled',
  'robot_face_controller_alert_voice_enabled',
  'robot_face_idle_chatter_voice_enabled',
  'robot_face_idle_chatter_cooldown_minutes',
  'robot_face_reminder_repeat_cooldown_minutes',
  'robot_face_reminder_repeat_policy',
};

const deferredDeletedPrescriptionPrefix = 'deferred_deleted_prescription:';

bool isPortableSettingKey(String key) =>
    portableSettingKeys.contains(key) ||
    (key.startsWith(deferredDeletedPrescriptionPrefix) &&
        key.length > deferredDeletedPrescriptionPrefix.length);

enum _FieldType {
  string,
  nullableString,
  integer,
  boolean,
  timestamp,
  nullableTimestamp,
}

class BackupValidator {
  const BackupValidator();

  List<BackupValidationIssue> validate(BackupDocument document) {
    final issues = <BackupValidationIssue>[];
    for (final section in BackupDocument.sectionNames) {
      final rows = document.data[section]!;
      final spec = _specs[section]!;
      final primary = section == 'settings'
          ? 'key'
          : section == 'carouselStates'
          ? 'profileId'
          : 'id';
      final ids = <Object?>{};
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final path =
            r'$.data.'
            '$section[$index]';
        if (row.keys.toSet().length != spec.length ||
            !row.keys.toSet().containsAll(spec.keys)) {
          issues.add(
            BackupValidationIssue(
              path,
              'Fields do not exactly match the v1 format.',
            ),
          );
          continue;
        }
        for (final field in spec.entries) {
          _validateType(
            row[field.key],
            field.value,
            '$path.${field.key}',
            issues,
          );
        }
        final id = row[primary];
        if (id is String && id.trim().isEmpty) {
          issues.add(
            BackupValidationIssue('$path.$primary', 'ID must not be empty.'),
          );
        } else if (!ids.add(id)) {
          issues.add(
            BackupValidationIssue('$path.$primary', 'ID must be unique.'),
          );
        }
        _validateRow(section, row, path, issues);
      }
    }
    _validateRelationships(document, issues);
    return issues;
  }

  void validateOrThrow(BackupDocument document) {
    final issues = validate(document);
    if (issues.isNotEmpty) {
      throw BackupFormatException(
        issues.first.toString(),
        kind: BackupFormatErrorKind.invalidData,
      );
    }
  }

  static void _validateType(
    Object? value,
    _FieldType type,
    String path,
    List<BackupValidationIssue> issues,
  ) {
    final valid = switch (type) {
      _FieldType.string => value is String,
      _FieldType.nullableString => value == null || value is String,
      _FieldType.integer => value is int,
      _FieldType.boolean => value is bool,
      _FieldType.timestamp => _validTimestamp(value),
      _FieldType.nullableTimestamp => value == null || _validTimestamp(value),
    };
    if (!valid) {
      issues.add(BackupValidationIssue(path, 'Value has the wrong type.'));
    }
  }

  static bool _validTimestamp(Object? value) {
    if (value is! int || value % Duration.microsecondsPerSecond != 0) {
      return false;
    }
    try {
      DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
      return true;
    } on Object {
      return false;
    }
  }

  static void _validateRow(
    String section,
    Map<String, Object?> row,
    String path,
    List<BackupValidationIssue> issues,
  ) {
    void range(String field, int min, int max) {
      final value = row[field];
      if (value is int && (value < min || value > max)) {
        issues.add(
          BackupValidationIssue(
            '$path.$field',
            'Value must be from $min through $max.',
          ),
        );
      }
    }

    void oneOf(String field, Set<String> values, {bool nullable = false}) {
      final value = row[field];
      if (nullable && value == null) return;
      if (value is String && !values.contains(value)) {
        issues.add(
          BackupValidationIssue('$path.$field', 'Unknown enum value.'),
        );
      }
    }

    void nonnegative(String field, {bool positive = false}) {
      final value = row[field];
      if (value is int && (positive ? value <= 0 : value < 0)) {
        issues.add(
          BackupValidationIssue(
            '$path.$field',
            positive
                ? 'Value must be positive.'
                : 'Value must not be negative.',
          ),
        );
      }
    }

    void ordered(String first, String second) {
      final a = row[first];
      final b = row[second];
      if (a is int && b is int && a > b) {
        issues.add(
          BackupValidationIssue(
            '$path.$second',
            '$second must not precede $first.',
          ),
        );
      }
    }

    if (row.containsKey('createdAt') && row.containsKey('updatedAt')) {
      ordered('createdAt', 'updatedAt');
    }
    switch (section) {
      case 'settings':
        final key = row['key'];
        if (key is String && !isPortableSettingKey(key)) {
          issues.add(
            BackupValidationIssue('$path.key', 'Setting is not portable.'),
          );
        }
      case 'prescriptions':
        oneOf('pillType', {'pill', 'capsule', 'tablet'});
        oneOf('guidedPillIcon', {
          'tablet',
          'roundPill',
          'ovalTablet',
          'capsule',
          'softgel',
          'splitPill',
          'multiplePills',
        });
        for (final field in [
          'remainingDoses',
          'availableDoses',
          'loadedDoses',
          'usedDoses',
          'reviewDoses',
          'defaultRefillQuantity',
          'refillThreshold',
        ]) {
          nonnegative(field);
        }
        nonnegative('defaultDoseCountPerDose', positive: true);
        if (row['remainingDoses'] is int &&
            row['availableDoses'] is int &&
            row['loadedDoses'] is int &&
            row['reviewDoses'] is int &&
            row['remainingDoses'] !=
                (row['availableDoses'] as int) +
                    (row['loadedDoses'] as int) +
                    (row['reviewDoses'] as int)) {
          issues.add(
            BackupValidationIssue(
              '$path.remainingDoses',
              'Remaining doses must equal available, loaded, and review doses.',
            ),
          );
        }
      case 'prescriptionRefills':
        nonnegative('doseDelta', positive: true);
        nonnegative('remainingAfter');
      case 'reminderSchedules':
        range('hour', 0, 23);
        range('minute', 0, 59);
      case 'carouselSlots':
        range('slotNumber', 1, 14);
        oneOf('status', {'assigned', 'loaded', 'dispensed', 'needs_review'});
      case 'carouselLoadSessions':
        range('positionBefore', 0, 14);
        range('positionAfter', 0, 14);
        oneOf('mode', {'full_load', 'top_off'});
        oneOf('status', {
          'draft',
          'confirmed',
          'stale',
          'superseded',
          'cancelled',
        });
        for (final field in [
          'planCreatedAt',
          'startedAt',
          'confirmedAt',
          'staleAt',
          'supersededAt',
        ]) {
          final value = row[field];
          if (value is int &&
              row['createdAt'] is int &&
              value < (row['createdAt'] as int)) {
            issues.add(
              BackupValidationIssue(
                '$path.$field',
                'Lifecycle timestamp precedes creation.',
              ),
            );
          }
        }
      case 'carouselLoadSlotSnapshots':
        range('slotNumber', 1, 14);
        oneOf('status', {
          'loaded',
          'retained',
          'dispensed',
          'needs_review',
          'empty',
          'shortage',
        });
        final arrays =
            [
                  'scheduleIdsJson',
                  'prescriptionIdsJson',
                  'prescriptionNamesJson',
                  'pillIconsJson',
                  'doseInstructionsJson',
                ]
                .map(
                  (field) => _stringArray(row[field], '$path.$field', issues),
                )
                .toList();
        if (arrays.every((array) => array != null) &&
            arrays.map((array) => array!.length).toSet().length != 1) {
          issues.add(
            BackupValidationIssue(
              path,
              'Embedded parallel arrays must have equal lengths.',
            ),
          );
        }
        final icons = arrays[3];
        if (icons != null &&
            icons.any(
              (icon) => !{
                'tablet',
                'roundPill',
                'ovalTablet',
                'capsule',
                'softgel',
                'splitPill',
                'multiplePills',
              }.contains(icon),
            )) {
          issues.add(
            BackupValidationIssue('$path.pillIconsJson', 'Unknown pill icon.'),
          );
        }
      case 'carouselStates':
        range('currentPosition', 0, 14);
      case 'medicationShortageAlerts':
        range('slotNumber', 1, 14);
        oneOf('status', {'active', 'resolved', 'past_due'});
        oneOf('intendedAudience', {'household'});
        oneOf('localDeliveryState', {'pending', 'sent', 'failed'});
        oneOf('remoteDeliveryState', {'not_configured'});
        final ids = _stringArray(
          row['prescriptionIdsJson'],
          '$path.prescriptionIdsJson',
          issues,
        );
        final names = _stringArray(
          row['prescriptionNamesJson'],
          '$path.prescriptionNamesJson',
          issues,
        );
        if (ids != null && names != null && ids.length != names.length) {
          issues.add(
            BackupValidationIssue(
              path,
              'Embedded parallel arrays must have equal lengths.',
            ),
          );
        }
      case 'doseLogEvents':
        const takenKinds = {
          'doseTakenConfirmed',
          'doseAlreadyTaken',
          'doseTakenEarly',
          'doseTakenLate',
        };
        const kinds = {
          'controllerDispenseSucceeded',
          ...takenKinds,
          'doseVisibleConfirmed',
          'doseSnoozed',
          'caregiverHelpRequested',
          'doseSkipped',
          'doseMissed',
          'doseMissedRecognized',
          'error',
        };
        oneOf('kind', kinds);
        if (row['kind'] is String &&
            row['marksDoseTaken'] is bool &&
            (row['marksDoseTaken'] as bool) !=
                takenKinds.contains(row['kind'])) {
          issues.add(
            BackupValidationIssue(
              '$path.marksDoseTaken',
              'Taken flag does not match the event kind.',
            ),
          );
        }
      case 'controllerCommandSessions':
        oneOf('commandType', {
          'dispenseNext',
          'dispenseTest',
          'heartbeat',
          'status',
        });
        oneOf('state', {
          'pending',
          'accepted',
          'succeeded',
          'failed',
          'timedOut',
          'cancelled',
          'interrupted',
        });
        oneOf('failureReason', {
          'nack',
          'jam',
          'offline',
          'disconnect',
        }, nullable: true);
        ordered('createdAt', 'updatedAt');
        for (final field in ['acceptedAt', 'resolvedAt']) {
          final value = row[field];
          if (value is int &&
              row['createdAt'] is int &&
              value < (row['createdAt'] as int)) {
            issues.add(
              BackupValidationIssue(
                '$path.$field',
                'Lifecycle timestamp precedes creation.',
              ),
            );
          }
        }
      case 'controllerCommandEvents':
        nonnegative('sequence', positive: true);
        oneOf('eventType', {
          'commandSent',
          'ack',
          'nack',
          'moveStarted',
          'servoDone',
          'controllerError',
          'heartbeatOk',
          'heartbeatMissed',
          'offline',
          'reconnected',
        });
      case 'adminAuditEvents':
        oneOf('eventType', {
          'prescriptionSaved',
          'prescriptionDeleted',
          'prescriptionRefillAdded',
          'scheduleSaved',
          'scheduleDeleted',
          'scheduleProfileSaved',
          'activeScheduleProfileChanged',
          'carouselSlotAssigned',
          'carouselSlotLoaded',
          'carouselSlotNeedsReviewMarked',
          'pinEnabled',
          'pinChanged',
          'pinDisabled',
          'householdProfileUpdated',
          'householdCreated',
          'householdInvitationGenerated',
          'householdMemberRemoved',
          'householdLeft',
          'pairingCodeGenerated',
          'guidedLoadConfirmed',
          'guidedLoadPhysicallyUnloaded',
          'guidedLoadMarkedStale',
          'guidedLoadShortageCreated',
          'guidedLoadShortageRecognized',
          'guidedLoadShortageResolved',
          'guidedLoadShortagePastDue',
        });
        oneOf('targetType', {
          'prescription',
          'reminderSchedule',
          'scheduleProfile',
          'carouselSlot',
          'household',
          'robot',
          'pin',
          'carouselLoadSession',
          'medicationShortageAlert',
        });
        oneOf('actorType', {
          'localAdmin',
          'signedInUser',
          'caregiver',
          'system',
        });
        oneOf('sourceDeviceRole', {
          'android_robot',
          'android_personal',
          'ios_personal',
        });
        final details = row['detailsJson'];
        if (details is String) {
          try {
            if (jsonDecode(details) is! Map) throw const FormatException();
          } on Object {
            issues.add(
              BackupValidationIssue(
                '$path.detailsJson',
                'Value must contain a JSON object.',
              ),
            );
          }
        }
      default:
        break;
    }
  }

  static List<String>? _stringArray(
    Object? encoded,
    String path,
    List<BackupValidationIssue> issues,
  ) {
    if (encoded is! String) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List || decoded.any((value) => value is! String)) {
        throw const FormatException();
      }
      return decoded.cast<String>();
    } on Object {
      issues.add(
        BackupValidationIssue(path, 'Value must contain a JSON string array.'),
      );
      return null;
    }
  }

  static void _validateRelationships(
    BackupDocument document,
    List<BackupValidationIssue> issues,
  ) {
    final data = document.data;
    final profiles = {
      for (final row in data['scheduleProfiles']!) row['id']: row,
    };
    final prescriptions = {
      for (final row in data['prescriptions']!) row['id']: row,
    };
    final schedules = {
      for (final row in data['reminderSchedules']!) row['id']: row,
    };
    final sessions = {
      for (final row in data['carouselLoadSessions']!) row['id']: row,
    };
    if (profiles.values.where((row) => row['isActive'] == true).length != 1) {
      issues.add(
        const BackupValidationIssue(
          r'$.data.scheduleProfiles',
          'Exactly one schedule profile must be active.',
        ),
      );
    }
    void requireRef(
      String section,
      String field,
      Map<Object?, Object?> targets, {
      bool nullable = false,
    }) {
      for (var i = 0; i < data[section]!.length; i++) {
        final value = data[section]![i][field];
        if (nullable && value == null) continue;
        if (value is String && !targets.containsKey(value)) {
          issues.add(
            BackupValidationIssue(
              r'$.data.'
                  '$section[$i].$field',
              'Referenced record does not exist.',
            ),
          );
        }
      }
    }

    requireRef('reminderSchedules', 'profileId', profiles);
    requireRef(
      'reminderSchedules',
      'prescriptionId',
      prescriptions,
      nullable: true,
    );
    requireRef('prescriptionRefills', 'prescriptionId', prescriptions);
    requireRef('carouselSlots', 'profileId', profiles);
    requireRef('carouselSlots', 'prescriptionId', prescriptions);
    requireRef('carouselSlots', 'scheduleId', schedules);
    requireRef('carouselLoadSessions', 'profileId', profiles);
    requireRef('carouselLoadSlotSnapshots', 'sessionId', sessions);
    requireRef('carouselStates', 'profileId', profiles);
    requireRef(
      'carouselStates',
      'activeLoadSessionId',
      sessions,
      nullable: true,
    );
    requireRef('medicationShortageAlerts', 'profileId', profiles);
    final stateProfileIds = {
      for (final row in data['carouselStates']!) row['profileId'],
    };
    if (stateProfileIds.length != profiles.length ||
        !stateProfileIds.containsAll(profiles.keys)) {
      issues.add(
        const BackupValidationIssue(
          r'$.data.carouselStates',
          'Each schedule profile must have one carousel state.',
        ),
      );
    }
    final sessionSlots = <String>{};
    for (var i = 0; i < data['carouselLoadSlotSnapshots']!.length; i++) {
      final row = data['carouselLoadSlotSnapshots']![i];
      if (!sessionSlots.add('${row['sessionId']}|${row['slotNumber']}')) {
        issues.add(
          BackupValidationIssue(
            r'$.data.carouselLoadSlotSnapshots['
                '$i].slotNumber',
            'Session slot must be unique.',
          ),
        );
      }
    }
    final profileSlots = <String>{};
    final profileSchedules = <String>{};
    for (var i = 0; i < data['carouselSlots']!.length; i++) {
      final row = data['carouselSlots']![i];
      final path =
          r'$.data.carouselSlots['
          '$i]';
      if (!profileSlots.add('${row['profileId']}|${row['slotNumber']}')) {
        issues.add(
          BackupValidationIssue(
            '$path.slotNumber',
            'Profile slot must be unique.',
          ),
        );
      }
      if (!profileSchedules.add('${row['profileId']}|${row['scheduleId']}')) {
        issues.add(
          BackupValidationIssue(
            '$path.scheduleId',
            'Profile schedule must be unique.',
          ),
        );
      }
      final schedule = schedules[row['scheduleId']];
      if (schedule != null &&
          (schedule['isEnabled'] != true ||
              schedule['profileId'] != row['profileId'] ||
              schedule['prescriptionId'] != row['prescriptionId'])) {
        issues.add(
          BackupValidationIssue(
            path,
            'Slot and schedule assignment do not match.',
          ),
        );
      }
    }
    final eventSequences = <String>{};
    final sequencesBySession = <Object?, List<int>>{};
    final commandIds = {
      for (final row in data['controllerCommandSessions']!) row['id'],
    };
    for (var i = 0; i < data['controllerCommandEvents']!.length; i++) {
      final row = data['controllerCommandEvents']![i];
      final path =
          r'$.data.controllerCommandEvents['
          '$i]';
      if (!commandIds.contains(row['sessionId'])) {
        issues.add(
          BackupValidationIssue(
            '$path.sessionId',
            'Referenced command session does not exist.',
          ),
        );
      }
      if (!eventSequences.add('${row['sessionId']}|${row['sequence']}')) {
        issues.add(
          BackupValidationIssue(
            '$path.sequence',
            'Session sequence must be unique.',
          ),
        );
      }
      final sequence = row['sequence'];
      if (sequence is int) {
        sequencesBySession
            .putIfAbsent(row['sessionId'], () => [])
            .add(sequence);
      }
    }
    for (final sequences in sequencesBySession.values) {
      sequences.sort();
      if (sequences.indexed.any((entry) => entry.$2 != entry.$1 + 1)) {
        issues.add(
          const BackupValidationIssue(
            r'$.data.controllerCommandEvents',
            'Session event sequences must be contiguous from one.',
          ),
        );
      }
    }
    for (var i = 0; i < data['carouselStates']!.length; i++) {
      final row = data['carouselStates']![i];
      final session = sessions[row['activeLoadSessionId']];
      if (session != null && session['profileId'] != row['profileId']) {
        issues.add(
          BackupValidationIssue(
            r'$.data.carouselStates['
                '$i].activeLoadSessionId',
            'Active session belongs to another profile.',
          ),
        );
      }
    }
    for (var i = 0; i < data['carouselLoadSessions']!.length; i++) {
      final row = data['carouselLoadSessions']![i];
      final predecessor = sessions[row['predecessorSessionId']];
      if (row['predecessorSessionId'] == row['id'] ||
          (row['predecessorSessionId'] != null &&
              (predecessor == null ||
                  predecessor['profileId'] != row['profileId']))) {
        issues.add(
          BackupValidationIssue(
            r'$.data.carouselLoadSessions['
                '$i].predecessorSessionId',
            'Predecessor must be another session in the same profile.',
          ),
        );
      }
    }
    for (var i = 0; i < data['medicationShortageAlerts']!.length; i++) {
      final row = data['medicationShortageAlerts']![i];
      final session = sessions[row['loadSessionId']];
      if ((row['status'] == 'active' || row['status'] == 'past_due') &&
          (session == null || session['profileId'] != row['profileId'])) {
        issues.add(
          BackupValidationIssue(
            r'$.data.medicationShortageAlerts['
                '$i].loadSessionId',
            'Current shortage requires a session in the same profile.',
          ),
        );
      }
    }
    for (var i = 0; i < data['settings']!.length; i++) {
      final key = data['settings']![i]['key'];
      if (key is String && key.startsWith(deferredDeletedPrescriptionPrefix)) {
        final id = key.substring(deferredDeletedPrescriptionPrefix.length);
        if (!prescriptions.containsKey(id)) {
          issues.add(
            BackupValidationIssue(
              r'$.data.settings['
                  '$i].key',
              'Deferred marker prescription does not exist.',
            ),
          );
        }
      }
    }
    // Historical controller schedule and slot references may outlive those rows.
  }

  static const _specs = <String, Map<String, _FieldType>>{
    'settings': {
      'key': _FieldType.string,
      'value': _FieldType.string,
      'updatedAt': _FieldType.timestamp,
    },
    'scheduleProfiles': {
      'id': _FieldType.string,
      'name': _FieldType.string,
      'isActive': _FieldType.boolean,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'prescriptions': {
      'id': _FieldType.string,
      'name': _FieldType.string,
      'pillType': _FieldType.string,
      'remainingDoses': _FieldType.integer,
      'guidedPillIcon': _FieldType.string,
      'availableDoses': _FieldType.integer,
      'loadedDoses': _FieldType.integer,
      'usedDoses': _FieldType.integer,
      'reviewDoses': _FieldType.integer,
      'defaultRefillQuantity': _FieldType.integer,
      'defaultDoseCountPerDose': _FieldType.integer,
      'doseInstructions': _FieldType.string,
      'refillThreshold': _FieldType.integer,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'prescriptionRefills': {
      'id': _FieldType.string,
      'prescriptionId': _FieldType.string,
      'doseDelta': _FieldType.integer,
      'remainingAfter': _FieldType.integer,
      'occurredAt': _FieldType.timestamp,
      'note': _FieldType.nullableString,
    },
    'reminderSchedules': {
      'id': _FieldType.string,
      'label': _FieldType.string,
      'prescriptionId': _FieldType.nullableString,
      'profileId': _FieldType.string,
      'hour': _FieldType.integer,
      'minute': _FieldType.integer,
      'isEnabled': _FieldType.boolean,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'carouselSlots': {
      'id': _FieldType.string,
      'slotNumber': _FieldType.integer,
      'prescriptionId': _FieldType.string,
      'scheduleId': _FieldType.string,
      'profileId': _FieldType.string,
      'status': _FieldType.string,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'carouselLoadSessions': {
      'id': _FieldType.string,
      'profileId': _FieldType.string,
      'mode': _FieldType.string,
      'status': _FieldType.string,
      'predecessorSessionId': _FieldType.nullableString,
      'planCreatedAt': _FieldType.nullableTimestamp,
      'startedAt': _FieldType.nullableTimestamp,
      'confirmedAt': _FieldType.nullableTimestamp,
      'staleAt': _FieldType.nullableTimestamp,
      'staleReason': _FieldType.nullableString,
      'supersededAt': _FieldType.nullableTimestamp,
      'supersededReason': _FieldType.nullableString,
      'positionBefore': _FieldType.integer,
      'positionAfter': _FieldType.integer,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'carouselLoadSlotSnapshots': {
      'id': _FieldType.string,
      'sessionId': _FieldType.string,
      'slotNumber': _FieldType.integer,
      'status': _FieldType.string,
      'scheduledAt': _FieldType.nullableTimestamp,
      'bundleKey': _FieldType.nullableString,
      'scheduleIdsJson': _FieldType.string,
      'prescriptionIdsJson': _FieldType.string,
      'prescriptionNamesJson': _FieldType.string,
      'pillIconsJson': _FieldType.string,
      'doseInstructionsJson': _FieldType.string,
      'loadedAt': _FieldType.nullableTimestamp,
      'movedAt': _FieldType.nullableTimestamp,
      'resolvedAt': _FieldType.nullableTimestamp,
      'reviewReason': _FieldType.nullableString,
      'createdAt': _FieldType.timestamp,
    },
    'carouselStates': {
      'profileId': _FieldType.string,
      'activeLoadSessionId': _FieldType.nullableString,
      'currentPosition': _FieldType.integer,
      'updatedAt': _FieldType.timestamp,
    },
    'medicationShortageAlerts': {
      'id': _FieldType.string,
      'profileId': _FieldType.string,
      'loadSessionId': _FieldType.nullableString,
      'slotNumber': _FieldType.integer,
      'bundleKey': _FieldType.string,
      'scheduledAt': _FieldType.timestamp,
      'prescriptionIdsJson': _FieldType.string,
      'prescriptionNamesJson': _FieldType.string,
      'status': _FieldType.string,
      'recognizedAt': _FieldType.nullableTimestamp,
      'resolvedAt': _FieldType.nullableTimestamp,
      'resolution': _FieldType.nullableString,
      'intendedAudience': _FieldType.string,
      'localDeliveryState': _FieldType.string,
      'localNotificationSentAt': _FieldType.nullableTimestamp,
      'remoteDeliveryState': _FieldType.string,
      'createdAt': _FieldType.timestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'doseLogEvents': {
      'id': _FieldType.string,
      'kind': _FieldType.string,
      'doseId': _FieldType.string,
      'occurredAt': _FieldType.timestamp,
      'marksDoseTaken': _FieldType.boolean,
    },
    'controllerCommandSessions': {
      'id': _FieldType.string,
      'commandType': _FieldType.string,
      'doseId': _FieldType.nullableString,
      'scheduleId': _FieldType.nullableString,
      'slotId': _FieldType.nullableString,
      'state': _FieldType.string,
      'failureReason': _FieldType.nullableString,
      'createdAt': _FieldType.timestamp,
      'acceptedAt': _FieldType.nullableTimestamp,
      'resolvedAt': _FieldType.nullableTimestamp,
      'updatedAt': _FieldType.timestamp,
    },
    'controllerCommandEvents': {
      'id': _FieldType.string,
      'sessionId': _FieldType.string,
      'sequence': _FieldType.integer,
      'eventType': _FieldType.string,
      'occurredAt': _FieldType.timestamp,
      'details': _FieldType.nullableString,
    },
    'adminAuditEvents': {
      'id': _FieldType.string,
      'eventType': _FieldType.string,
      'targetType': _FieldType.string,
      'targetId': _FieldType.nullableString,
      'actorType': _FieldType.string,
      'actorUserId': _FieldType.nullableString,
      'actorLabel': _FieldType.string,
      'sourceDeviceRole': _FieldType.string,
      'summary': _FieldType.string,
      'detailsJson': _FieldType.nullableString,
      'cloudEventId': _FieldType.nullableString,
      'lastSyncedAt': _FieldType.nullableTimestamp,
      'occurredAt': _FieldType.timestamp,
    },
  };
}
