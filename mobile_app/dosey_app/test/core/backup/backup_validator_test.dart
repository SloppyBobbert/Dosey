import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:dosey_app/core/backup/backup_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = BackupValidator();

  BackupDocument validDocument() {
    final data = BackupDocument.emptyData();
    data['scheduleProfiles'] = [
      {
        'id': 'profile-1',
        'name': 'Default',
        'isActive': true,
        'createdAt': 1000000,
        'updatedAt': 1000000,
      },
    ];
    data['carouselStates'] = [
      {
        'profileId': 'profile-1',
        'activeLoadSessionId': null,
        'currentPosition': 0,
        'updatedAt': 1000000,
      },
    ];
    return BackupDocument(data: data);
  }

  test('accepts a valid minimal database', () {
    expect(validator.validate(validDocument()), isEmpty);
  });

  test('rejects unknown fields with a stable path', () {
    final data = validDocument().mutableData()
      ..['scheduleProfiles']![0]['extra'] = true;
    final issues = validator.validate(BackupDocument(data: data));
    expect(issues.first.path, r'$.data.scheduleProfiles[0]');
  });

  test('rejects inventory equality violations', () {
    final data = validDocument().mutableData();
    data['prescriptions'] = [
      {
        'id': 'rx-1',
        'name': 'Test',
        'pillType': 'pill',
        'remainingDoses': 4,
        'guidedPillIcon': 'roundPill',
        'availableDoses': 1,
        'loadedDoses': 1,
        'usedDoses': 9,
        'reviewDoses': 1,
        'defaultRefillQuantity': 30,
        'defaultDoseCountPerDose': 1,
        'doseInstructions': '',
        'refillThreshold': 3,
        'createdAt': 1,
        'updatedAt': 1,
      },
    ];
    final issues = validator.validate(BackupDocument(data: data));
    expect(
      issues.map((issue) => issue.path),
      contains(r'$.data.prescriptions[0].remainingDoses'),
    );
  });

  test('rejects movement events marked as taken', () {
    final data = validDocument().mutableData();
    data['doseLogEvents'] = [
      {
        'id': 'dose-1',
        'kind': 'controllerDispenseSucceeded',
        'doseId': 'scheduled-1',
        'occurredAt': 1,
        'marksDoseTaken': true,
      },
    ];
    final issues = validator.validate(BackupDocument(data: data));
    expect(
      issues.map((issue) => issue.path),
      contains(r'$.data.doseLogEvents[0].marksDoseTaken'),
    );
  });

  test('rejects missing required references', () {
    final data = validDocument().mutableData();
    data['reminderSchedules'] = [
      {
        'id': 'schedule-1',
        'label': 'Morning',
        'prescriptionId': null,
        'profileId': 'missing',
        'hour': 8,
        'minute': 0,
        'isEnabled': true,
        'createdAt': 1,
        'updatedAt': 1,
      },
    ];
    final issues = validator.validate(BackupDocument(data: data));
    expect(
      issues.map((issue) => issue.path),
      contains(r'$.data.reminderSchedules[0].profileId'),
    );
  });

  test('rejects wrong primitive types and unknown enum values', () {
    final data = validDocument().mutableData();
    data['scheduleProfiles']![0]['isActive'] = 1;
    data['prescriptions'] = [_prescription()..['pillType'] = 'powder'];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.scheduleProfiles[0].isActive'));
    expect(paths, contains(r'$.data.prescriptions[0].pillType'));
  });

  test('rejects timestamps that SQLite cannot preserve exactly', () {
    final data = validDocument().mutableData();
    data['scheduleProfiles']![0]['updatedAt'] = 1000001;

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.scheduleProfiles[0].updatedAt'));
  });

  test('rejects out-of-range positions and malformed embedded JSON', () {
    final data = validDocument().mutableData();
    data['carouselLoadSessions'] = [_loadSession()..['positionAfter'] = 15];
    data['carouselLoadSlotSnapshots'] = [
      _loadSnapshot()..['scheduleIdsJson'] = '{bad json',
    ];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.carouselLoadSessions[0].positionAfter'));
    expect(
      paths,
      contains(r'$.data.carouselLoadSlotSnapshots[0].scheduleIdsJson'),
    );
  });

  test('rejects duplicate snapshot positions within a load session', () {
    final data = validDocument().mutableData();
    data['carouselLoadSessions'] = [_loadSession()];
    data['carouselLoadSlotSnapshots'] = [
      _loadSnapshot(),
      _loadSnapshot()..['id'] = 'snapshot-2',
    ];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.carouselLoadSlotSnapshots[1].slotNumber'));
  });

  test('rejects unknown settings and orphaned deferred-delete markers', () {
    final data = validDocument().mutableData();
    data['settings'] = [
      {'key': 'unknown_setting', 'value': 'x', 'updatedAt': 1000000},
      {
        'key': 'deferred_deleted_prescription:missing',
        'value': 'true',
        'updatedAt': 1000000,
      },
    ];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.settings[0].key'));
    expect(paths, contains(r'$.data.settings[1].key'));
  });

  test('rejects whitespace-only and duplicate primary IDs', () {
    final data = validDocument().mutableData();
    data['scheduleProfiles'] = [
      data['scheduleProfiles']!.single,
      Map<String, Object?>.from(data['scheduleProfiles']!.single),
      {...data['scheduleProfiles']!.single, 'id': '   ', 'isActive': false},
    ];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.scheduleProfiles[1].id'));
    expect(paths, contains(r'$.data.scheduleProfiles[2].id'));
  });

  test('requires one active profile and one carousel state per profile', () {
    final noState = validDocument().mutableData()..['carouselStates'] = [];
    final noActive = validDocument().mutableData();
    noActive['scheduleProfiles']!.single['isActive'] = false;

    expect(
      validator
          .validate(BackupDocument(data: noState))
          .map((issue) => issue.path),
      contains(r'$.data.carouselStates'),
    );
    expect(
      validator
          .validate(BackupDocument(data: noActive))
          .map((issue) => issue.path),
      contains(r'$.data.scheduleProfiles'),
    );
  });

  test('requires controller event sequences to be contiguous from one', () {
    final data = validDocument().mutableData();
    data['controllerCommandSessions'] = [_commandSession()];
    data['controllerCommandEvents'] = [_commandEvent()..['sequence'] = 2];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.controllerCommandEvents'));
  });

  test('rejects new-table uniqueness and scope invariants', () {
    final data = validDocument().mutableData()
      ..['phoneDoseActionEvents'] = [_action(), _action(id: 'action-2')]
      ..['syncOutboxMutations'] = [
        _outbox('mutation-1'),
        _outbox('mutation-2'),
      ];

    final paths = validator
        .validate(BackupDocument(data: data))
        .map((issue) => issue.path);

    expect(paths, contains(r'$.data.phoneDoseActionEvents[1].idempotencyKey'));
    expect(paths, contains(r'$.data.phoneDoseActionEvents[1].occurrenceId'));
    expect(paths, contains(r'$.data.syncOutboxMutations[1].idempotencyKey'));
  });

  test('accepts distinct terminal pairs containing delimiter characters', () {
    final data = validDocument().mutableData()
      ..['phoneDoseActionEvents'] = [
        _action(
          deviceId: 'a|b',
          occurrenceId: 'c',
          idempotencyKey: 'action-key-1',
        ),
        _action(
          id: 'action-2',
          deviceId: 'a',
          occurrenceId: 'b|c',
          idempotencyKey: 'action-key-2',
        ),
      ];

    expect(validator.validate(BackupDocument(data: data)), isEmpty);
  });

  test('validates phone action local dates strictly', () {
    for (final localDate in [
      '2026-2-03',
      '2026-02-30',
      '2025-02-29',
      '0000-01-01',
    ]) {
      final data = validDocument().mutableData()
        ..['phoneDoseActionEvents'] = [_action(localDate: localDate)];

      expect(
        validator
            .validate(BackupDocument(data: data))
            .map((issue) => issue.path),
        contains(r'$.data.phoneDoseActionEvents[0].localDate'),
      );
    }
    final leapDay = validDocument().mutableData()
      ..['phoneDoseActionEvents'] = [_action(localDate: '2024-02-29')];
    expect(validator.validate(BackupDocument(data: leapDay)), isEmpty);
  });
}

Map<String, Object?> _action({
  String id = 'action-1',
  String deviceId = 'device-1',
  String occurrenceId = 'occurrence-1',
  String idempotencyKey = 'action-key',
  String localDate = '2026-01-01',
}) => {
  'id': id,
  'deviceId': deviceId,
  'occurrenceId': occurrenceId,
  'scheduleId': 'schedule-1',
  'scheduleRevision': 1,
  'scheduledAt': 1000000,
  'localDate': localDate,
  'timezoneId': 'UTC',
  'medicationId': 'rx-1',
  'kind': 'taken_confirmed',
  'occurredAt': 1000000,
  'marksDoseTaken': true,
  'idempotencyKey': idempotencyKey,
  'createdAt': 1000000,
};

Map<String, Object?> _outbox(String mutationId) => {
  'mutationId': mutationId,
  'deviceId': 'device-1',
  'actorAccountId': null,
  'robotId': null,
  'scopeState': 'local_only',
  'idempotencyKey': 'outbox-key',
  'entityType': 'action',
  'operation': 'upsert',
  'entityId': 'action-1',
  'baseRevision': null,
  'payloadJson': '{}',
  'state': 'pending',
  'attemptCount': 0,
  'nextAttemptAt': null,
  'lastAttemptAt': null,
  'lastErrorCode': null,
  'createdAt': 1000000,
  'updatedAt': 1000000,
};

Map<String, Object?> _prescription() => {
  'id': 'rx-1',
  'name': 'Test',
  'pillType': 'pill',
  'remainingDoses': 3,
  'guidedPillIcon': 'roundPill',
  'availableDoses': 1,
  'loadedDoses': 1,
  'usedDoses': 9,
  'reviewDoses': 1,
  'defaultRefillQuantity': 30,
  'defaultDoseCountPerDose': 1,
  'doseInstructions': '',
  'refillThreshold': 3,
  'createdAt': 1000000,
  'updatedAt': 1000000,
};

Map<String, Object?> _loadSession() => {
  'id': 'session-1',
  'profileId': 'profile-1',
  'mode': 'full_load',
  'status': 'confirmed',
  'predecessorSessionId': null,
  'planCreatedAt': 1000000,
  'startedAt': 1000000,
  'confirmedAt': 1000000,
  'staleAt': null,
  'staleReason': null,
  'supersededAt': null,
  'supersededReason': null,
  'positionBefore': 0,
  'positionAfter': 1,
  'createdAt': 1000000,
  'updatedAt': 1000000,
};

Map<String, Object?> _loadSnapshot() => {
  'id': 'snapshot-1',
  'sessionId': 'session-1',
  'slotNumber': 1,
  'status': 'empty',
  'scheduledAt': null,
  'bundleKey': null,
  'scheduleIdsJson': '[]',
  'prescriptionIdsJson': '[]',
  'prescriptionNamesJson': '[]',
  'pillIconsJson': '[]',
  'doseInstructionsJson': '[]',
  'loadedAt': null,
  'movedAt': null,
  'resolvedAt': null,
  'reviewReason': null,
  'createdAt': 1000000,
};

Map<String, Object?> _commandSession() => {
  'id': 'command-1',
  'commandType': 'status',
  'doseId': null,
  'scheduleId': null,
  'slotId': null,
  'state': 'succeeded',
  'failureReason': null,
  'createdAt': 1000000,
  'acceptedAt': 1000000,
  'resolvedAt': 1000000,
  'updatedAt': 1000000,
};

Map<String, Object?> _commandEvent() => {
  'id': 'command-1:1',
  'sessionId': 'command-1',
  'sequence': 1,
  'eventType': 'commandSent',
  'occurredAt': 1000000,
  'details': null,
};

extension on BackupDocument {
  Map<String, List<Map<String, Object?>>> mutableData() => {
    for (final entry in data.entries)
      entry.key: entry.value.map(Map<String, Object?>.from).toList(),
  };
}
