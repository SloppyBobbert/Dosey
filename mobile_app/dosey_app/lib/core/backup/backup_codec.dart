import 'dart:convert';
import 'dart:typed_data';

import 'backup_document.dart';
import 'backup_validator.dart';

class BackupCodec {
  const BackupCodec({this.validator = const BackupValidator()});

  final BackupValidator validator;

  static const maxBytes = 25 * 1024 * 1024;

  Uint8List encode(BackupDocument document) {
    final canonicalData = <String, Object?>{};
    for (final section in BackupDocument.sectionNames) {
      final rows = document.data[section]!
          .map(Map<String, Object?>.from)
          .toList();
      rows.sort((left, right) => _compareRows(section, left, right));
      canonicalData[section] = rows.map(_canonicalizeRow).toList();
    }
    final payload = <String, Object?>{
      'format': BackupDocument.formatName,
      'formatVersion': document.formatVersion,
      'sourceSchemaVersion': document.sourceSchemaVersion,
      'data': canonicalData,
    };
    final bytes = Uint8List.fromList(utf8.encode('${jsonEncode(payload)}\n'));
    if (bytes.length > maxBytes) {
      throw const BackupFormatException(
        'Backup exceeds the 25 MiB limit.',
        kind: BackupFormatErrorKind.tooLarge,
      );
    }
    return bytes;
  }

  BackupDocument decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const BackupFormatException(
        'Backup exceeds the 25 MiB limit.',
        kind: BackupFormatErrorKind.tooLarge,
      );
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on Object {
      throw const BackupFormatException('Backup is not valid UTF-8 JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException('Backup root must be an object.');
    }
    _exactKeys(decoded, const {
      'format',
      'formatVersion',
      'sourceSchemaVersion',
      'data',
    }, r'$');
    if (decoded['format'] != BackupDocument.formatName) {
      throw const BackupFormatException('Unrecognized backup format.');
    }
    final version = decoded['formatVersion'];
    if (version is! int) {
      throw const BackupFormatException('formatVersion must be an integer.');
    }
    if (version != BackupDocument.currentFormatVersion) {
      throw const BackupFormatException(
        'This backup format version is not supported.',
        kind: BackupFormatErrorKind.unsupportedVersion,
      );
    }
    final schema = decoded['sourceSchemaVersion'];
    if (schema is! int) {
      throw const BackupFormatException(
        'sourceSchemaVersion must be an integer.',
      );
    }
    if (schema != BackupDocument.currentSourceSchemaVersion) {
      throw const BackupFormatException(
        'This backup database schema is not supported.',
        kind: BackupFormatErrorKind.unsupportedSchema,
      );
    }
    final rawData = decoded['data'];
    if (rawData is! Map<String, Object?>) {
      throw const BackupFormatException('data must be an object.');
    }
    _exactKeys(rawData, BackupDocument.sectionNames.toSet(), r'$.data');
    final data = BackupDocument.emptyData();
    for (final section in BackupDocument.sectionNames) {
      final rawRows = rawData[section];
      if (rawRows is! List) {
        throw BackupFormatException('data.$section must be an array.');
      }
      data[section] = <Map<String, Object?>>[
        for (var index = 0; index < rawRows.length; index++)
          if (rawRows[index] is Map<String, Object?>)
            Map<String, Object?>.from(rawRows[index] as Map<String, Object?>)
          else
            throw BackupFormatException(
              'data.$section[$index] must be an object.',
            ),
      ];
    }
    final document = BackupDocument(
      data: data,
      formatVersion: version,
      sourceSchemaVersion: schema,
    );
    validator.validateOrThrow(document);
    return document;
  }

  static void _exactKeys(
    Map<String, Object?> value,
    Set<String> expected,
    String path,
  ) {
    if (value.keys.toSet().length != expected.length ||
        !value.keys.toSet().containsAll(expected)) {
      throw BackupFormatException('$path has missing or unknown fields.');
    }
  }

  static int _compareRows(
    String section,
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final keys = switch (section) {
      'settings' => const ['key'],
      'carouselStates' => const ['profileId'],
      'controllerCommandEvents' => const ['sessionId', 'sequence', 'id'],
      _ => const ['id'],
    };
    for (final key in keys) {
      final a = left[key];
      final b = right[key];
      final comparison = a is int && b is int
          ? a.compareTo(b)
          : (a?.toString() ?? '').compareTo(b?.toString() ?? '');
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static Map<String, Object?> _canonicalizeRow(Map<String, Object?> row) {
    final keys = row.keys.toList()..sort();
    return {for (final key in keys) key: row[key]};
  }
}
