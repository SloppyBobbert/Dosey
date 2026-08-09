import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = BackupCodec();

  test('v2 encoding and decoding use source schema 18', () {
    final document = BackupDocument(data: _validV2Data());

    final first = codec.encode(document);
    final second = codec.encode(document);
    final json = jsonDecode(utf8.decode(first)) as Map<String, Object?>;

    expect(first, second);
    expect(json['formatVersion'], 2);
    expect(json['sourceSchemaVersion'], 18);
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
    expect(codec.decode(first).sourceSchemaVersion, 18);
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

  test('decode accepts only supported format and schema metadata pairs', () {
    for (final entry in <(int, int, BackupFormatErrorKind?)>[
      (1, 14, null),
      (2, 17, null),
      (2, 18, null),
      (1, 17, BackupFormatErrorKind.unsupportedSchema),
      (1, 18, BackupFormatErrorKind.unsupportedSchema),
      (2, 14, BackupFormatErrorKind.unsupportedSchema),
      (3, 18, BackupFormatErrorKind.unsupportedVersion),
      (2, 16, BackupFormatErrorKind.unsupportedSchema),
    ]) {
      final (version, schema, errorKind) = entry;
      final fixture = version == 1 ? 'schema14.json' : 'schema18.json';
      final payload = _fixturePayload(fixture)
        ..['formatVersion'] = version
        ..['sourceSchemaVersion'] = schema;
      BackupDocument decode() =>
          codec.decode(Uint8List.fromList(utf8.encode(jsonEncode(payload))));
      if (errorKind == null) {
        expect(decode, returnsNormally);
      } else {
        expect(
          decode,
          throwsA(
            isA<BackupFormatException>().having(
              (error) => error.kind,
              'kind',
              errorKind,
            ),
          ),
        );
      }
    }
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

  test(
    'decode rejects malformed replay-eligible outbox fields before normalization',
    () {
      final malformedRows =
          <(int, String, void Function(Map<String, Object?>))>[
            (
              BackupDocument.v2LegacySourceSchemaVersion,
              'schema17.json',
              (row) => row['attemptCount'] = -1,
            ),
            (
              BackupDocument.currentSourceSchemaVersion,
              'schema18.json',
              (row) => row['nextAttemptAt'] = 'not-a-timestamp',
            ),
          ];

      for (final (schema, fixture, mutate) in malformedRows) {
        final payload = _fixturePayload(fixture)
          ..['sourceSchemaVersion'] = schema;
        final row =
            ((payload['data'] as Map<String, Object?>)['syncOutboxMutations']
                        as List)
                    .first
                as Map<String, Object?>;
        mutate(row);

        expect(
          () => codec.decode(
            Uint8List.fromList(utf8.encode(jsonEncode(payload))),
          ),
          throwsA(
            isA<BackupFormatException>().having(
              (error) => error.kind,
              'kind',
              BackupFormatErrorKind.invalidData,
            ),
          ),
        );
      }
    },
  );

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

  for (final fixture in ['schema14.json', 'schema17.json', 'schema18.json']) {
    test('fixture $fixture decodes with only documented normalization', () {
      final expected = _normalizedFixtureData(fixture);
      final document = codec.decode(_fixtureBytes(fixture));

      expect(document.formatVersion, BackupDocument.currentFormatVersion);
      expect(
        document.sourceSchemaVersion,
        BackupDocument.currentSourceSchemaVersion,
      );
      expect(document.data, expected);
    });
  }

  test('schema 17 fixture anchors replay normalization literally', () {
    final document = codec.decode(_fixtureBytes('schema17.json'));
    final rows = {
      for (final row in document.data['syncOutboxMutations']!)
        row['mutationId']: row,
    };

    for (final entry
        in <
          (String, String, String?, String?, String, String, String, String?)
        >[
          (
            'local-pending',
            'local_only',
            null,
            null,
            'action-local-pending',
            'outbox-key-1',
            'pending',
            null,
          ),
          (
            'local-flight',
            'local_only',
            null,
            null,
            'action-local-flight',
            'outbox-key-2',
            'pending',
            null,
          ),
          (
            'bound-pending',
            'bound',
            'account-fixture',
            'robot-fixture',
            'action-bound-pending',
            'outbox-key-3',
            'permanent_failure',
            'restore_review_required',
          ),
          (
            'bound-flight',
            'bound',
            'account-fixture',
            'robot-fixture',
            'action-bound-flight',
            'outbox-key-4',
            'permanent_failure',
            'restore_review_required',
          ),
        ]) {
      final (
        mutationId,
        scopeState,
        actorAccountId,
        robotId,
        entityId,
        idempotencyKey,
        state,
        lastErrorCode,
      ) = entry;
      final row = rows[mutationId]!;
      expect(row['mutationId'], mutationId);
      expect(row['scopeState'], scopeState);
      expect(row['actorAccountId'], actorAccountId);
      expect(row['robotId'], robotId);
      expect(row['entityId'], entityId);
      expect(row['idempotencyKey'], idempotencyKey);
      expect(row['state'], state);
      expect(row['attemptCount'], 0);
      expect(row['nextAttemptAt'], isNull);
      expect(row['lastAttemptAt'], isNull);
      expect(row['lastErrorCode'], lastErrorCode);
    }
  });

  test(
    'decode rejects malformed source replay payloads before normalization',
    () {
      final payload =
          jsonDecode(utf8.decode(_fixtureBytes('schema18.json')))
              as Map<String, Object?>;
      final data = payload['data'] as Map<String, Object?>;
      final outbox = (data['syncOutboxMutations'] as List).single as Map;
      outbox['payloadJson'] = '{not json';

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
    },
  );

  test('schema 17 and 18 reject invalid source replay contracts', () {
    for (final fixture in ['schema17.json', 'schema18.json']) {
      for (final mutate in <void Function(Map<String, Object?>)>[
        (row) => row['payloadJson'] = '{not json',
        (row) => row['entityType'] = 'unsupported',
        (row) => row['operation'] = 'upsert',
        (row) => row['payloadJson'] = _payload(kind: 'taken_confirmed'),
        (row) => row['payloadJson'] = _payload(kind: 'skipped'),
        (row) => row['payloadJson'] = _payload(
          occurrenceId: 'not-the-occurrence-tuple',
        ),
        (row) => row['entityId'] = 'missing-action',
        (row) => row['idempotencyKey'] = 'mismatched-action-key',
      ]) {
        final payload = _fixturePayload(fixture);
        final row =
            ((payload['data'] as Map<String, Object?>)['syncOutboxMutations']
                        as List)
                    .first
                as Map<String, Object?>;
        mutate(row);
        expect(
          () => codec.decode(
            Uint8List.fromList(utf8.encode(jsonEncode(payload))),
          ),
          throwsA(isA<BackupFormatException>()),
        );
      }
    }
  });

  test('malformed nullable replay fields return invalid data', () {
    for (final mutate in <void Function(Map<String, Object?>)>[
      (row) => row['actorAccountId'] = 1,
      (row) => row['nextAttemptAt'] = 1 << 62,
    ]) {
      final payload = _fixturePayload('schema18.json');
      final row =
          ((payload['data'] as Map<String, Object?>)['syncOutboxMutations']
                      as List)
                  .single
              as Map<String, Object?>;
      mutate(row);

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

Uint8List _fixtureBytes(String name) => Uint8List.fromList(
  File('test/core/backup/fixtures/$name').readAsBytesSync(),
);

Map<String, Object?> _fixturePayload(String name) =>
    jsonDecode(utf8.decode(_fixtureBytes(name))) as Map<String, Object?>;

Map<String, List<Map<String, Object?>>> _normalizedFixtureData(String name) {
  final payload = _fixturePayload(name);
  final rawData = payload['data'] as Map<String, Object?>;
  final data = BackupDocument.emptyData();
  for (final section in BackupDocument.sectionNames) {
    final rows = rawData[section] as List? ?? const [];
    data[section] = rows
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
  }
  if (payload['formatVersion'] == 1) {
    data['reminderSchedules'] = [
      for (final row in data['reminderSchedules']!) {...row, 'revision': 1},
    ];
  }
  for (final row in data['syncOutboxMutations']!) {
    if (row['state'] != 'pending' && row['state'] != 'in_flight') continue;
    final bound = row['scopeState'] == 'bound';
    row['state'] = bound ? 'permanent_failure' : 'pending';
    row['attemptCount'] = 0;
    row['nextAttemptAt'] = null;
    row['lastAttemptAt'] = null;
    row['lastErrorCode'] = bound
        ? BackupCodec.restoredOutboxReviewErrorCode
        : null;
  }
  return data;
}

String _payload({
  String kind = 'snoozed',
  String occurrenceId = 'schedule-1:1:1970-01-01T00:00:01.000Z',
}) => jsonEncode({
  'medicationId': 'rx-1',
  'profileId': 'profile-1',
  'kind': kind,
  'occurredAt': '1970-01-01T00:00:01.000Z',
  'occurrence': {
    'occurrenceId': occurrenceId,
    'scheduleId': 'schedule-1',
    'scheduleRevision': 1,
    'scheduledAtUtc': '1970-01-01T00:00:01.000Z',
    'localDate': '1970-01-01',
    'timezoneId': 'UTC',
  },
});

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
