import 'dart:convert';
import 'dart:typed_data';

import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = BackupCodec();

  test('empty backup encoding is deterministic and has current sections', () {
    final document = BackupDocument.empty();

    final first = codec.encode(document);
    final second = codec.encode(document);
    final json = jsonDecode(utf8.decode(first)) as Map<String, Object?>;

    expect(first, second);
    expect(json.keys, <String>[
      'format',
      'formatVersion',
      'sourceSchemaVersion',
      'data',
    ]);
    expect(
      (json['data']! as Map<String, Object?>).keys,
      BackupDocument.sectionNames,
    );
  });

  test('rows use canonical section-specific ordering', () {
    final document = BackupDocument(
      data: BackupDocument.emptyData()
        ..['carouselStates'] = <Map<String, Object?>>[
          {'profileId': 'z'},
          {'profileId': 'a'},
        ]
        ..['controllerCommandEvents'] = <Map<String, Object?>>[
          {'id': 'b', 'sessionId': 's', 'sequence': 2},
          {'id': 'z', 'sessionId': 'a', 'sequence': 1},
          {'id': 'a', 'sessionId': 's', 'sequence': 2},
        ],
    );

    final decoded = jsonDecode(utf8.decode(codec.encode(document)));
    final data = decoded['data'] as Map<String, Object?>;
    expect((data['carouselStates'] as List).map((row) => row['profileId']), [
      'a',
      'z',
    ]);
    expect((data['controllerCommandEvents'] as List).map((row) => row['id']), [
      'z',
      'a',
      'b',
    ]);
  });

  test('row field order does not affect canonical bytes', () {
    final firstData = BackupDocument.emptyData()
      ..['settings'] = <Map<String, Object?>>[
        {'key': 'profile_display_name', 'value': 'Alex', 'updatedAt': 1000000},
      ];
    final secondData = BackupDocument.emptyData()
      ..['settings'] = <Map<String, Object?>>[
        {'updatedAt': 1000000, 'value': 'Alex', 'key': 'profile_display_name'},
      ];

    expect(
      codec.encode(BackupDocument(data: firstData)),
      codec.encode(BackupDocument(data: secondData)),
    );
  });

  test('outbox mutation order does not affect canonical bytes', () {
    final first = _validV2Data()
      ..['syncOutboxMutations'] = [
        _outbox('mutation-b'),
        _outbox('mutation-a'),
      ];
    final second = _validV2Data()
      ..['syncOutboxMutations'] = [
        _outbox('mutation-a'),
        _outbox('mutation-b'),
      ];

    expect(
      codec.encode(BackupDocument(data: first)),
      codec.encode(BackupDocument(data: second)),
    );
  });

  test('encode rejects documents with non-current metadata', () {
    expect(
      () => codec.encode(
        BackupDocument(
          data: BackupDocument.emptyData(),
          formatVersion: 1,
          sourceSchemaVersion: BackupDocument.v1SourceSchemaVersion,
        ),
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.invalidData,
        ),
      ),
    );
  });

  test('decode rejects malformed envelopes', () {
    expect(
      () => codec.decode(Uint8List.fromList(utf8.encode('{not json'))),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => codec.decode(Uint8List.fromList(utf8.encode('[]'))),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => codec.decode(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'format': BackupDocument.formatName,
              'formatVersion': BackupDocument.currentFormatVersion + 1,
              'sourceSchemaVersion': BackupDocument.currentSourceSchemaVersion,
              'data': BackupDocument.emptyData(),
            }),
          ),
        ),
      ),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.unsupportedVersion,
        ),
      ),
    );
  });

  test('decode rejects backups from any other source schema', () {
    final payload = {
      'format': BackupDocument.formatName,
      'formatVersion': BackupDocument.currentFormatVersion,
      'sourceSchemaVersion': BackupDocument.currentSourceSchemaVersion - 1,
      'data': BackupDocument.emptyData(),
    };

    expect(
      () => codec.decode(Uint8List.fromList(utf8.encode(jsonEncode(payload)))),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.unsupportedSchema,
        ),
      ),
    );
  });

  test('decode rejects new-table invariant violations as invalid data', () {
    final invalidRows = <Map<String, List<Map<String, Object?>>>>[
      {
        'phoneDoseActionEvents': [_action(), _action(id: 'action-2')],
      },
      {
        'phoneDoseActionEvents': [
          _action(),
          _action(id: 'action-2', idempotencyKey: 'action-key-2'),
        ],
      },
      {
        'phoneDoseActionEvents': [_action(marksDoseTaken: false)],
      },
      {
        'syncOutboxMutations': [_outbox('mutation-1'), _outbox('mutation-2')],
      },
      {
        'syncOutboxMutations': [_outbox('mutation-1', scopeState: 'invalid')],
      },
      {
        'syncOutboxMutations': [
          _outbox(
            'mutation-1',
            actorAccountId: ' ',
            robotId: 'robot-1',
            scopeState: 'bound',
          ),
        ],
      },
      {
        'syncOutboxMutations': [
          _outbox('mutation-1', actorAccountId: 'account-1'),
        ],
      },
    ];

    for (final changedSections in invalidRows) {
      final data = _validV2Data()..addAll(changedSections);
      final payload = {
        'format': BackupDocument.formatName,
        'formatVersion': BackupDocument.currentFormatVersion,
        'sourceSchemaVersion': BackupDocument.currentSourceSchemaVersion,
        'data': data,
      };
      expect(
        () =>
            codec.decode(Uint8List.fromList(utf8.encode(jsonEncode(payload)))),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.kind,
            'kind',
            BackupFormatErrorKind.invalidData,
          ),
        ),
      );
    }
  });

  test('decode rejects v2-only reminder fields in a v1 backup', () {
    final data = BackupDocument.emptyData()
      ..['scheduleProfiles'] = [
        {
          'id': 'profile-1',
          'name': 'Default',
          'isActive': true,
          'createdAt': 1000000,
          'updatedAt': 1000000,
        },
      ]
      ..['reminderSchedules'] = [
        {
          'id': 'schedule-1',
          'label': 'Morning',
          'prescriptionId': null,
          'profileId': 'profile-1',
          'hour': 8,
          'minute': 0,
          'revision': 1,
          'isEnabled': true,
          'createdAt': 1000000,
          'updatedAt': 1000000,
        },
      ]
      ..['carouselStates'] = [
        {
          'profileId': 'profile-1',
          'activeLoadSessionId': null,
          'currentPosition': 0,
          'updatedAt': 1000000,
        },
      ];
    final payload = {
      'format': BackupDocument.formatName,
      'formatVersion': 1,
      'sourceSchemaVersion': BackupDocument.v1SourceSchemaVersion,
      'data': {
        for (final section in BackupDocument.v1SectionNames)
          section: data[section],
      },
    };

    expect(
      () => codec.decode(Uint8List.fromList(utf8.encode(jsonEncode(payload)))),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.invalidData,
        ),
      ),
    );
  });

  test('decode normalizes a valid v1 backup to v2 once', () {
    final data = BackupDocument.emptyData()
      ..['scheduleProfiles'] = [
        {
          'id': 'profile-1',
          'name': 'Default',
          'isActive': true,
          'createdAt': 1000000,
          'updatedAt': 1000000,
        },
      ]
      ..['reminderSchedules'] = [
        {
          'id': 'schedule-1',
          'label': 'Morning',
          'prescriptionId': null,
          'profileId': 'profile-1',
          'hour': 8,
          'minute': 0,
          'isEnabled': true,
          'createdAt': 1000000,
          'updatedAt': 1000000,
        },
      ]
      ..['carouselStates'] = [
        {
          'profileId': 'profile-1',
          'activeLoadSessionId': null,
          'currentPosition': 0,
          'updatedAt': 1000000,
        },
      ];
    final payload = {
      'format': BackupDocument.formatName,
      'formatVersion': 1,
      'sourceSchemaVersion': BackupDocument.v1SourceSchemaVersion,
      'data': {
        for (final section in BackupDocument.v1SectionNames)
          section: data[section],
      },
    };

    final document = codec.decode(
      Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    );

    expect(document.formatVersion, BackupDocument.currentFormatVersion);
    expect(
      document.sourceSchemaVersion,
      BackupDocument.currentSourceSchemaVersion,
    );
    expect(document.data['reminderSchedules']!.single['revision'], 1);
    expect(document.data['phoneDoseActionEvents'], isEmpty);
    expect(document.data['syncOutboxMutations'], isEmpty);
  });

  test('decode rejects malformed UTF-8 and oversized input', () {
    expect(
      () => codec.decode(Uint8List.fromList([0xC3, 0x28])),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      () => codec.decode(Uint8List(BackupCodec.maxBytes + 1)),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.tooLarge,
        ),
      ),
    );
  });

  test('encode rejects backups that exceed the import limit', () {
    final characters = Uint8List(BackupCodec.maxBytes)
      ..fillRange(0, BackupCodec.maxBytes, 0x78);
    final data = BackupDocument.emptyData()
      ..['settings'] = [
        {
          'key': 'profile_display_name',
          'value': String.fromCharCodes(characters),
          'updatedAt': 1000000,
        },
      ];

    expect(
      () => codec.encode(BackupDocument(data: data)),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.kind,
          'kind',
          BackupFormatErrorKind.tooLarge,
        ),
      ),
    );
  });
}

Map<String, List<Map<String, Object?>>> _validV2Data() {
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
  return data;
}

Map<String, Object?> _action({
  String id = 'action-1',
  String idempotencyKey = 'action-key-1',
  bool marksDoseTaken = true,
}) => {
  'id': id,
  'deviceId': 'device-1',
  'occurrenceId': 'occurrence-1',
  'scheduleId': 'schedule-1',
  'scheduleRevision': 1,
  'scheduledAt': 1000000,
  'localDate': '2026-01-01',
  'timezoneId': 'UTC',
  'medicationId': 'rx-1',
  'kind': 'taken_confirmed',
  'occurredAt': 1000000,
  'marksDoseTaken': marksDoseTaken,
  'idempotencyKey': idempotencyKey,
  'createdAt': 1000000,
};

Map<String, Object?> _outbox(
  String mutationId, {
  String idempotencyKey = 'mutation-key',
  String scopeState = 'local_only',
  String? actorAccountId,
  String? robotId,
}) => {
  'mutationId': mutationId,
  'deviceId': 'device-1',
  'actorAccountId': actorAccountId,
  'robotId': robotId,
  'scopeState': scopeState,
  'idempotencyKey': idempotencyKey,
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
