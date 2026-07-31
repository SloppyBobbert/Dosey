import 'dart:collection';

enum BackupFormatErrorKind {
  malformed,
  unsupportedVersion,
  unsupportedSchema,
  tooLarge,
  invalidData,
}

class BackupFormatException implements Exception {
  const BackupFormatException(
    this.message, {
    this.kind = BackupFormatErrorKind.malformed,
  });

  final String message;
  final BackupFormatErrorKind kind;

  @override
  String toString() => 'BackupFormatException: $message';
}

class BackupValidationIssue {
  const BackupValidationIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class BackupSummary {
  BackupSummary(Map<String, int> counts)
    : counts = UnmodifiableMapView(Map<String, int>.from(counts));

  final Map<String, int> counts;

  int get totalRecords => counts.values.fold(0, (sum, count) => sum + count);
}

class BackupDocument {
  BackupDocument({
    required Map<String, List<Map<String, Object?>>> data,
    int formatVersion = currentFormatVersion,
    int sourceSchemaVersion = BackupDocument.currentSourceSchemaVersion,
  }) : formatVersion = _currentFormatVersionOrThrow(formatVersion),
       sourceSchemaVersion = _currentSchemaVersionOrThrow(sourceSchemaVersion),
       data = UnmodifiableMapView(
         Map<String, List<Map<String, Object?>>>.fromEntries(
           sectionNames.map(
             (section) => MapEntry(
               section,
               List<Map<String, Object?>>.unmodifiable(
                 (data[section] ?? const <Map<String, Object?>>[]).map(
                   (row) => UnmodifiableMapView(Map<String, Object?>.from(row)),
                 ),
               ),
             ),
           ),
         ),
       );

  factory BackupDocument.empty() => BackupDocument(data: emptyData());

  static const formatName = 'dosey-local-backup';
  static const currentFormatVersion = 2;
  static const currentSourceSchemaVersion = 17;
  static const v1SourceSchemaVersion = 14;
  static const sectionNames = <String>[
    'settings',
    'scheduleProfiles',
    'prescriptions',
    'prescriptionRefills',
    'reminderSchedules',
    'carouselSlots',
    'carouselLoadSessions',
    'carouselLoadSlotSnapshots',
    'carouselStates',
    'medicationShortageAlerts',
    'doseLogEvents',
    'controllerCommandSessions',
    'controllerCommandEvents',
    'adminAuditEvents',
    'phoneDoseActionEvents',
    'syncOutboxMutations',
  ];

  static const v1SectionNames = <String>[
    'settings',
    'scheduleProfiles',
    'prescriptions',
    'prescriptionRefills',
    'reminderSchedules',
    'carouselSlots',
    'carouselLoadSessions',
    'carouselLoadSlotSnapshots',
    'carouselStates',
    'medicationShortageAlerts',
    'doseLogEvents',
    'controllerCommandSessions',
    'controllerCommandEvents',
    'adminAuditEvents',
  ];

  final int formatVersion;
  final int sourceSchemaVersion;
  final Map<String, List<Map<String, Object?>>> data;

  static int _currentFormatVersionOrThrow(int version) {
    if (version != currentFormatVersion) {
      throw const BackupFormatException(
        'Backup documents must use the current format version.',
        kind: BackupFormatErrorKind.invalidData,
      );
    }
    return version;
  }

  static int _currentSchemaVersionOrThrow(int version) {
    if (version != currentSourceSchemaVersion) {
      throw const BackupFormatException(
        'Backup documents must use the current source schema version.',
        kind: BackupFormatErrorKind.invalidData,
      );
    }
    return version;
  }

  BackupSummary get summary => BackupSummary({
    for (final section in sectionNames) section: data[section]!.length,
  });

  static Map<String, List<Map<String, Object?>>> emptyData() => {
    for (final section in sectionNames) section: <Map<String, Object?>>[],
  };
}
