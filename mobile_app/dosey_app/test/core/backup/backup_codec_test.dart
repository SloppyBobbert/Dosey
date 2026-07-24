import 'dart:convert';
import 'dart:typed_data';

import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = BackupCodec();

  test('empty backup encoding is deterministic and has the v1 sections', () {
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
              'formatVersion': 2,
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
