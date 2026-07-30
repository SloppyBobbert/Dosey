import 'dart:convert';

import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

const medicationSyncContractVersion = 1;

// BEGIN GENERATED CANONICAL TIMEZONES
final Set<String> medicationSyncCanonicalTimezones = Set.unmodifiable(<String>{
  'Africa/Abidjan',
  'Africa/Algiers',
  'Africa/Bissau',
  'Africa/Cairo',
  'Africa/Casablanca',
  'Africa/Ceuta',
  'Africa/El_Aaiun',
  'Africa/Johannesburg',
  'Africa/Juba',
  'Africa/Khartoum',
  'Africa/Lagos',
  'Africa/Maputo',
  'Africa/Monrovia',
  'Africa/Nairobi',
  'Africa/Ndjamena',
  'Africa/Sao_Tome',
  'Africa/Tripoli',
  'Africa/Tunis',
  'Africa/Windhoek',
  'America/Adak',
  'America/Anchorage',
  'America/Araguaina',
  'America/Argentina/Buenos_Aires',
  'America/Argentina/Catamarca',
  'America/Argentina/Cordoba',
  'America/Argentina/Jujuy',
  'America/Argentina/La_Rioja',
  'America/Argentina/Mendoza',
  'America/Argentina/Rio_Gallegos',
  'America/Argentina/Salta',
  'America/Argentina/San_Juan',
  'America/Argentina/San_Luis',
  'America/Argentina/Tucuman',
  'America/Argentina/Ushuaia',
  'America/Asuncion',
  'America/Bahia',
  'America/Bahia_Banderas',
  'America/Barbados',
  'America/Belem',
  'America/Belize',
  'America/Boa_Vista',
  'America/Bogota',
  'America/Boise',
  'America/Cambridge_Bay',
  'America/Campo_Grande',
  'America/Cancun',
  'America/Caracas',
  'America/Cayenne',
  'America/Chicago',
  'America/Chihuahua',
  'America/Ciudad_Juarez',
  'America/Costa_Rica',
  'America/Coyhaique',
  'America/Cuiaba',
  'America/Danmarkshavn',
  'America/Dawson',
  'America/Dawson_Creek',
  'America/Denver',
  'America/Detroit',
  'America/Edmonton',
  'America/Eirunepe',
  'America/El_Salvador',
  'America/Fort_Nelson',
  'America/Fortaleza',
  'America/Glace_Bay',
  'America/Goose_Bay',
  'America/Grand_Turk',
  'America/Guatemala',
  'America/Guayaquil',
  'America/Guyana',
  'America/Halifax',
  'America/Havana',
  'America/Hermosillo',
  'America/Indiana/Indianapolis',
  'America/Indiana/Knox',
  'America/Indiana/Marengo',
  'America/Indiana/Petersburg',
  'America/Indiana/Tell_City',
  'America/Indiana/Vevay',
  'America/Indiana/Vincennes',
  'America/Indiana/Winamac',
  'America/Inuvik',
  'America/Iqaluit',
  'America/Jamaica',
  'America/Juneau',
  'America/Kentucky/Louisville',
  'America/Kentucky/Monticello',
  'America/La_Paz',
  'America/Lima',
  'America/Los_Angeles',
  'America/Maceio',
  'America/Managua',
  'America/Manaus',
  'America/Martinique',
  'America/Matamoros',
  'America/Mazatlan',
  'America/Menominee',
  'America/Merida',
  'America/Metlakatla',
  'America/Mexico_City',
  'America/Miquelon',
  'America/Moncton',
  'America/Monterrey',
  'America/Montevideo',
  'America/New_York',
  'America/Nome',
  'America/Noronha',
  'America/North_Dakota/Beulah',
  'America/North_Dakota/Center',
  'America/North_Dakota/New_Salem',
  'America/Nuuk',
  'America/Ojinaga',
  'America/Panama',
  'America/Paramaribo',
  'America/Phoenix',
  'America/Port-au-Prince',
  'America/Porto_Velho',
  'America/Puerto_Rico',
  'America/Punta_Arenas',
  'America/Rankin_Inlet',
  'America/Recife',
  'America/Regina',
  'America/Resolute',
  'America/Rio_Branco',
  'America/Santarem',
  'America/Santiago',
  'America/Santo_Domingo',
  'America/Sao_Paulo',
  'America/Scoresbysund',
  'America/Sitka',
  'America/St_Johns',
  'America/Swift_Current',
  'America/Tegucigalpa',
  'America/Thule',
  'America/Tijuana',
  'America/Toronto',
  'America/Vancouver',
  'America/Whitehorse',
  'America/Winnipeg',
  'America/Yakutat',
  'Antarctica/Casey',
  'Antarctica/Davis',
  'Antarctica/Macquarie',
  'Antarctica/Mawson',
  'Antarctica/Palmer',
  'Antarctica/Rothera',
  'Antarctica/Troll',
  'Antarctica/Vostok',
  'Asia/Almaty',
  'Asia/Amman',
  'Asia/Anadyr',
  'Asia/Aqtau',
  'Asia/Aqtobe',
  'Asia/Ashgabat',
  'Asia/Atyrau',
  'Asia/Baghdad',
  'Asia/Baku',
  'Asia/Bangkok',
  'Asia/Barnaul',
  'Asia/Beirut',
  'Asia/Bishkek',
  'Asia/Chita',
  'Asia/Colombo',
  'Asia/Damascus',
  'Asia/Dhaka',
  'Asia/Dili',
  'Asia/Dubai',
  'Asia/Dushanbe',
  'Asia/Famagusta',
  'Asia/Gaza',
  'Asia/Hebron',
  'Asia/Ho_Chi_Minh',
  'Asia/Hong_Kong',
  'Asia/Hovd',
  'Asia/Irkutsk',
  'Asia/Jakarta',
  'Asia/Jayapura',
  'Asia/Jerusalem',
  'Asia/Kabul',
  'Asia/Kamchatka',
  'Asia/Karachi',
  'Asia/Kathmandu',
  'Asia/Khandyga',
  'Asia/Kolkata',
  'Asia/Krasnoyarsk',
  'Asia/Kuching',
  'Asia/Macau',
  'Asia/Magadan',
  'Asia/Makassar',
  'Asia/Manila',
  'Asia/Nicosia',
  'Asia/Novokuznetsk',
  'Asia/Novosibirsk',
  'Asia/Omsk',
  'Asia/Oral',
  'Asia/Pontianak',
  'Asia/Pyongyang',
  'Asia/Qatar',
  'Asia/Qostanay',
  'Asia/Qyzylorda',
  'Asia/Riyadh',
  'Asia/Sakhalin',
  'Asia/Samarkand',
  'Asia/Seoul',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Asia/Srednekolymsk',
  'Asia/Taipei',
  'Asia/Tashkent',
  'Asia/Tbilisi',
  'Asia/Tehran',
  'Asia/Thimphu',
  'Asia/Tokyo',
  'Asia/Tomsk',
  'Asia/Ulaanbaatar',
  'Asia/Urumqi',
  'Asia/Ust-Nera',
  'Asia/Vladivostok',
  'Asia/Yakutsk',
  'Asia/Yangon',
  'Asia/Yekaterinburg',
  'Asia/Yerevan',
  'Atlantic/Azores',
  'Atlantic/Bermuda',
  'Atlantic/Canary',
  'Atlantic/Cape_Verde',
  'Atlantic/Faroe',
  'Atlantic/Madeira',
  'Atlantic/South_Georgia',
  'Atlantic/Stanley',
  'Australia/Adelaide',
  'Australia/Brisbane',
  'Australia/Broken_Hill',
  'Australia/Darwin',
  'Australia/Eucla',
  'Australia/Hobart',
  'Australia/Lindeman',
  'Australia/Lord_Howe',
  'Australia/Melbourne',
  'Australia/Perth',
  'Australia/Sydney',
  'Etc/GMT',
  'Etc/GMT+1',
  'Etc/GMT+10',
  'Etc/GMT+11',
  'Etc/GMT+12',
  'Etc/GMT+2',
  'Etc/GMT+3',
  'Etc/GMT+4',
  'Etc/GMT+5',
  'Etc/GMT+6',
  'Etc/GMT+7',
  'Etc/GMT+8',
  'Etc/GMT+9',
  'Etc/GMT-1',
  'Etc/GMT-10',
  'Etc/GMT-11',
  'Etc/GMT-12',
  'Etc/GMT-13',
  'Etc/GMT-14',
  'Etc/GMT-2',
  'Etc/GMT-3',
  'Etc/GMT-4',
  'Etc/GMT-5',
  'Etc/GMT-6',
  'Etc/GMT-7',
  'Etc/GMT-8',
  'Etc/GMT-9',
  'Etc/UTC',
  'Europe/Andorra',
  'Europe/Astrakhan',
  'Europe/Athens',
  'Europe/Belgrade',
  'Europe/Berlin',
  'Europe/Brussels',
  'Europe/Bucharest',
  'Europe/Budapest',
  'Europe/Chisinau',
  'Europe/Dublin',
  'Europe/Gibraltar',
  'Europe/Helsinki',
  'Europe/Istanbul',
  'Europe/Kaliningrad',
  'Europe/Kirov',
  'Europe/Kyiv',
  'Europe/Lisbon',
  'Europe/London',
  'Europe/Madrid',
  'Europe/Malta',
  'Europe/Minsk',
  'Europe/Moscow',
  'Europe/Paris',
  'Europe/Prague',
  'Europe/Riga',
  'Europe/Rome',
  'Europe/Samara',
  'Europe/Saratov',
  'Europe/Simferopol',
  'Europe/Sofia',
  'Europe/Tallinn',
  'Europe/Tirane',
  'Europe/Ulyanovsk',
  'Europe/Vienna',
  'Europe/Vilnius',
  'Europe/Volgograd',
  'Europe/Warsaw',
  'Europe/Zurich',
  'Factory',
  'Indian/Chagos',
  'Indian/Maldives',
  'Indian/Mauritius',
  'Pacific/Apia',
  'Pacific/Auckland',
  'Pacific/Bougainville',
  'Pacific/Chatham',
  'Pacific/Easter',
  'Pacific/Efate',
  'Pacific/Fakaofo',
  'Pacific/Fiji',
  'Pacific/Galapagos',
  'Pacific/Gambier',
  'Pacific/Guadalcanal',
  'Pacific/Guam',
  'Pacific/Honolulu',
  'Pacific/Kanton',
  'Pacific/Kiritimati',
  'Pacific/Kosrae',
  'Pacific/Kwajalein',
  'Pacific/Marquesas',
  'Pacific/Nauru',
  'Pacific/Niue',
  'Pacific/Norfolk',
  'Pacific/Noumea',
  'Pacific/Pago_Pago',
  'Pacific/Palau',
  'Pacific/Pitcairn',
  'Pacific/Port_Moresby',
  'Pacific/Rarotonga',
  'Pacific/Tahiti',
  'Pacific/Tarawa',
  'Pacific/Tongatapu',
  'UTC',
});
// END GENERATED CANONICAL TIMEZONES

enum HouseholdRoleContract {
  owner('owner'),
  member('member');

  const HouseholdRoleContract(this.wireValue);
  final String wireValue;
}

enum PillTypeContract {
  pill('pill'),
  capsule('capsule'),
  tablet('tablet');

  const PillTypeContract(this.wireValue);
  final String wireValue;
}

enum DoseEventKindContract {
  takenConfirmed('taken_confirmed'),
  skipped('skipped'),
  snoozed('snoozed'),
  helpRequested('help_requested');

  const DoseEventKindContract(this.wireValue);
  final String wireValue;
}

enum EntityTypeContract {
  medication('medication'),
  schedule('schedule'),
  doseEvent('dose_event');

  const EntityTypeContract(this.wireValue);
  final String wireValue;
}

enum MutationOperationContract {
  upsert('upsert'),
  delete('delete'),
  append('append');

  const MutationOperationContract(this.wireValue);
  final String wireValue;
}

enum MutationOutcomeContract {
  applied('applied'),
  duplicate('duplicate'),
  conflict('conflict'),
  rejected('rejected');

  const MutationOutcomeContract(this.wireValue);
  final String wireValue;
}

class MedicationSyncContractException implements FormatException {
  const MedicationSyncContractException(this.code, this.path, this.message);

  final String code;
  final String path;

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'MedicationSyncContractException: $path: $message';
}

class MedicationContract {
  const MedicationContract({
    required this.id,
    required this.householdId,
    required this.name,
    required this.pillType,
    required this.instructions,
    required this.revision,
    required this.deletedAt,
    required this.updatedAt,
  });

  factory MedicationContract.fromJson(Map<String, Object?> json) =>
      _parseMedication(json, r'$');

  final String id;
  final String householdId;
  final String name;
  final PillTypeContract pillType;
  final String? instructions;
  final int revision;
  final String? deletedAt;
  final String updatedAt;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'id': id,
    'householdId': householdId,
    'name': name,
    'pillType': pillType.wireValue,
    'instructions': instructions,
    'revision': revision,
    'deletedAt': deletedAt,
    'updatedAt': updatedAt,
  }, _parseMedication);
}

class MedicationScheduleContract {
  const MedicationScheduleContract({
    required this.id,
    required this.householdId,
    required this.medicationId,
    required this.label,
    required this.hour,
    required this.minute,
    required this.timezoneId,
    required this.enabled,
    required this.revision,
    required this.deletedAt,
    required this.updatedAt,
  });

  factory MedicationScheduleContract.fromJson(Map<String, Object?> json) =>
      _parseSchedule(json, r'$');

  final String id;
  final String householdId;
  final String medicationId;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool enabled;
  final int revision;
  final String? deletedAt;
  final String updatedAt;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'id': id,
    'householdId': householdId,
    'medicationId': medicationId,
    'label': label,
    'hour': hour,
    'minute': minute,
    'timezoneId': timezoneId,
    'enabled': enabled,
    'revision': revision,
    'deletedAt': deletedAt,
    'updatedAt': updatedAt,
  }, _parseSchedule);
}

class OccurrenceRefContract {
  const OccurrenceRefContract({
    required this.occurrenceId,
    required this.scheduleId,
    required this.scheduleRevision,
    required this.scheduledAt,
    required this.localDate,
    required this.timezoneId,
  });

  factory OccurrenceRefContract.fromJson(Map<String, Object?> json) =>
      _parseOccurrenceRef(json, r'$');

  final String occurrenceId;
  final String scheduleId;
  final int scheduleRevision;
  final String scheduledAt;
  final String localDate;
  final String timezoneId;

  Map<String, Object?> toJson() {
    final canonicalScheduledAt = _canonicalUtcTimestamp(
      scheduledAt,
      r'$.scheduledAt',
    );
    final json = <String, Object?>{
      'contractVersion': medicationSyncContractVersion,
      'occurrenceId': occurrenceId,
      'scheduleId': scheduleId,
      'scheduleRevision': scheduleRevision,
      'scheduledAt': canonicalScheduledAt,
      'localDate': localDate,
      'timezoneId': timezoneId,
    };
    _parseOccurrenceRef(json, r'$');
    return json;
  }
}

class DoseEventContract {
  const DoseEventContract({
    required this.id,
    required this.householdId,
    required this.medicationId,
    required this.occurrence,
    required this.kind,
    required this.occurredAt,
    required this.actorAccountId,
  });

  factory DoseEventContract.fromJson(Map<String, Object?> json) =>
      _parseDoseEvent(json, r'$');

  final String id;
  final String householdId;
  final String medicationId;
  final OccurrenceRefContract occurrence;
  final DoseEventKindContract kind;
  final String occurredAt;
  final String actorAccountId;

  bool get marksDoseTaken => kind == DoseEventKindContract.takenConfirmed;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'id': id,
    'householdId': householdId,
    'medicationId': medicationId,
    'occurrence': occurrence.toJson(),
    'kind': kind.wireValue,
    'occurredAt': _canonicalUtcTimestamp(occurredAt, r'$.occurredAt'),
    'actorAccountId': actorAccountId,
  }, _parseDoseEvent);
}

sealed class MutationPayloadContract {
  const MutationPayloadContract();
  Map<String, Object?> toJson();
}

class MedicationMutationPayloadContract extends MutationPayloadContract {
  const MedicationMutationPayloadContract({
    required this.name,
    required this.pillType,
    required this.instructions,
  });

  final String name;
  final PillTypeContract pillType;
  final String? instructions;

  @override
  Map<String, Object?> toJson() => _validatedJson({
    'name': name,
    'pillType': pillType.wireValue,
    'instructions': instructions,
  }, _parseMedicationPayload);
}

class ScheduleMutationPayloadContract extends MutationPayloadContract {
  const ScheduleMutationPayloadContract({
    required this.medicationId,
    required this.label,
    required this.hour,
    required this.minute,
    required this.timezoneId,
    required this.enabled,
  });

  final String medicationId;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool enabled;

  @override
  Map<String, Object?> toJson() => _validatedJson({
    'medicationId': medicationId,
    'label': label,
    'hour': hour,
    'minute': minute,
    'timezoneId': timezoneId,
    'enabled': enabled,
  }, _parseSchedulePayload);
}

class DoseEventMutationPayloadContract extends MutationPayloadContract {
  const DoseEventMutationPayloadContract({
    required this.medicationId,
    required this.occurrence,
    required this.kind,
    required this.occurredAt,
  });

  final String medicationId;
  final OccurrenceRefContract occurrence;
  final DoseEventKindContract kind;
  final String occurredAt;

  @override
  Map<String, Object?> toJson() => _validatedJson({
    'medicationId': medicationId,
    'occurrence': occurrence.toJson(),
    'kind': kind.wireValue,
    'occurredAt': _canonicalUtcTimestamp(occurredAt, r'$.occurredAt'),
  }, _parseDoseEventPayload);
}

class MutationContract {
  const MutationContract({
    required this.mutationId,
    required this.deviceId,
    required this.idempotencyKey,
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.baseRevision,
    required this.payload,
  });

  factory MutationContract.fromJson(Map<String, Object?> json) =>
      _parseMutation(json, r'$');

  final String mutationId;
  final String deviceId;
  final String idempotencyKey;
  final EntityTypeContract entityType;
  final MutationOperationContract operation;
  final String entityId;
  final int? baseRevision;
  final MutationPayloadContract? payload;

  Map<String, Object?> toJson() => {
    ..._validatedMutationJson({
      'contractVersion': medicationSyncContractVersion,
      'mutationId': mutationId,
      'deviceId': deviceId,
      'idempotencyKey': idempotencyKey,
      'entityType': entityType.wireValue,
      'operation': operation.wireValue,
      'entityId': entityId,
      'baseRevision': baseRevision,
      'payload': payload?.toJson(),
    }),
  };
}

class ConflictContract {
  const ConflictContract({
    required this.entityType,
    required this.entityId,
    required this.expectedRevision,
    required this.actualRevision,
    required this.authoritativeRecord,
  });

  factory ConflictContract.fromJson(Map<String, Object?> json) =>
      _parseConflict(json, r'$');

  final EntityTypeContract entityType;
  final String entityId;
  final int expectedRevision;
  final int actualRevision;
  final Object authoritativeRecord;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'entityType': entityType.wireValue,
    'entityId': entityId,
    'expectedRevision': expectedRevision,
    'actualRevision': actualRevision,
    'authoritativeRecord': switch (authoritativeRecord) {
      MedicationContract record => record.toJson(),
      MedicationScheduleContract record => record.toJson(),
      _ => throw StateError('Unsupported authoritative record.'),
    },
  }, _parseConflict);
}

class MutationAckContract {
  const MutationAckContract({
    required this.mutationId,
    required this.outcome,
    required this.revision,
    required this.cursor,
    required this.errorCode,
    required this.conflict,
  });

  factory MutationAckContract.fromJson(Map<String, Object?> json) =>
      _parseMutationAck(json, r'$');

  final String mutationId;
  final MutationOutcomeContract outcome;
  final int? revision;
  final String? cursor;
  final String? errorCode;
  final ConflictContract? conflict;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'mutationId': mutationId,
    'outcome': outcome.wireValue,
    'revision': revision,
    'cursor': cursor,
    'errorCode': errorCode,
    'conflict': conflict?.toJson(),
  }, _parseMutationAck);
}

class PullChangeContract {
  const PullChangeContract({
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.record,
  });

  final String cursor;
  final EntityTypeContract entityType;
  final String entityId;
  final MutationOperationContract operation;
  final Object record;

  Map<String, Object?> toJson() => _validatedJson({
    'cursor': cursor,
    'entityType': entityType.wireValue,
    'entityId': entityId,
    'operation': operation.wireValue,
    'record': switch (record) {
      MedicationContract value => value.toJson(),
      MedicationScheduleContract value => value.toJson(),
      DoseEventContract value => value.toJson(),
      _ => throw StateError('Unsupported pull record.'),
    },
  }, _parsePullChange);
}

class PullPageContract {
  const PullPageContract({
    required this.robotId,
    required this.cursor,
    required this.checkpoint,
    required this.nextCursor,
    required this.hasMore,
    required this.changes,
  });

  factory PullPageContract.fromJson(Map<String, Object?> json) =>
      _parsePullPage(json, r'$');

  final String robotId;
  final String? cursor;
  final String checkpoint;
  final String nextCursor;
  final bool hasMore;
  final List<PullChangeContract> changes;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'robotId': robotId,
    'cursor': cursor,
    'checkpoint': checkpoint,
    'nextCursor': nextCursor,
    'hasMore': hasMore,
    'changes': changes.map((change) => change.toJson()).toList(growable: false),
  }, _parsePullPage);
}

class MedicationSyncPushRequest {
  const MedicationSyncPushRequest({
    required this.robotId,
    required this.operations,
  });

  factory MedicationSyncPushRequest.fromJson(Map<String, Object?> json) =>
      _parsePushRequest(json, r'$');

  final String robotId;
  final List<MutationContract> operations;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'robotId': robotId,
    'operations': operations
        .map((operation) => operation.toJson())
        .toList(growable: false),
  }, _parsePushRequest);
}

class MedicationSyncPushResponse {
  const MedicationSyncPushResponse({
    required this.robotId,
    required this.acknowledgements,
  });

  factory MedicationSyncPushResponse.fromJson(Map<String, Object?> json) =>
      _parsePushResponse(json, r'$');

  final String robotId;
  final List<MutationAckContract> acknowledgements;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'robotId': robotId,
    'acknowledgements': acknowledgements
        .map((ack) => ack.toJson())
        .toList(growable: false),
  }, _parsePushResponse);
}

class MedicationSyncPullRequest {
  const MedicationSyncPullRequest({
    required this.robotId,
    required this.cursor,
    required this.checkpoint,
    required this.limit,
  });

  factory MedicationSyncPullRequest.fromJson(Map<String, Object?> json) =>
      _parsePullRequest(json, r'$');

  final String robotId;
  final String? cursor;
  final String? checkpoint;
  final int limit;

  Map<String, Object?> toJson() => _validatedJson({
    'contractVersion': medicationSyncContractVersion,
    'robotId': robotId,
    'cursor': cursor,
    'checkpoint': checkpoint,
    'limit': limit,
  }, _parsePullRequest);
}

Map<String, Object?> _validatedJson(
  Map<String, Object?> json,
  Object? Function(Object?, String) parser,
) {
  parser(json, r'$');
  return json;
}

Never _fail(String code, String path, String message) {
  throw MedicationSyncContractException(code, path, message);
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) _fail('INVALID_TYPE', path, 'Expected an object.');
  try {
    return value.cast<String, Object?>();
  } on Object {
    _fail('INVALID_TYPE', path, 'Expected an object with string keys.');
  }
}

void _exactKeys(Map<String, Object?> value, List<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      _fail('UNKNOWN_FIELD', '$path.$key', 'Unknown field.');
    }
  }
  for (final key in allowed) {
    if (!value.containsKey(key)) {
      _fail('MISSING_FIELD', '$path.$key', 'Required field.');
    }
  }
}

void _version(Object? value, String path) {
  if (value != medicationSyncContractVersion) {
    _fail('UNSUPPORTED_CONTRACT_VERSION', path, 'Expected contract version 1.');
  }
}

String _string(Object? value, String path, {int maximum = 1024}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.trim() != value) {
    _fail(
      'INVALID_STRING',
      path,
      'Expected a non-empty string up to $maximum characters.',
    );
  }
  return value;
}

String _id(Object? value, String path) => _string(value, path, maximum: 128);

String _occurrenceId(Object? value, String path) =>
    _string(value, path, maximum: 256);

int _integer(Object? value, String path, {required int minimum, int? maximum}) {
  if (value is! int ||
      value > 9007199254740991 ||
      value < minimum ||
      (maximum != null && value > maximum)) {
    _fail(
      'INVALID_INTEGER',
      path,
      'Expected an integer from $minimum${maximum == null ? '' : ' to $maximum'}.',
    );
  }
  return value;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) _fail('INVALID_TYPE', path, 'Expected a boolean.');
  return value;
}

T _enum<T>(
  Object? value,
  List<T> values,
  String Function(T) wire,
  String path,
) {
  for (final candidate in values) {
    if (wire(candidate) == value) return candidate;
  }
  _fail('INVALID_ENUM', path, 'Unsupported enum value.');
}

final _utcPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?Z$',
);

String _utcTimestamp(Object? value, String path) {
  if (value is! String) {
    _fail('INVALID_TIMESTAMP', path, 'Expected a UTC timestamp.');
  }
  final match = _utcPattern.firstMatch(value);
  if (match == null) {
    _fail(
      'INVALID_TIMESTAMP',
      path,
      'Expected an RFC 3339 UTC timestamp ending in Z.',
    );
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final fraction = (match.group(7) ?? '0').padRight(3, '0');
  if (year < 1) {
    _fail(
      'INVALID_TIMESTAMP',
      path,
      'Timestamp year must be from 0001 to 9999.',
    );
  }
  final parsed = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    int.parse(fraction),
  );
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    _fail('INVALID_TIMESTAMP', path, 'Invalid UTC calendar date.');
  }
  return value;
}

String _canonicalUtcTimestamp(Object? value, String path) {
  final timestamp = _utcTimestamp(value, path);
  final instant = DateTime.parse(timestamp).toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return '${digits(instant.year, 4)}-${digits(instant.month, 2)}-'
      '${digits(instant.day, 2)}T${digits(instant.hour, 2)}:'
      '${digits(instant.minute, 2)}:${digits(instant.second, 2)}.'
      '${digits(instant.millisecond, 3)}Z';
}

String? _nullableTimestamp(Object? value, String path) =>
    value == null ? null : _utcTimestamp(value, path);

String _localDate(Object? value, String path) {
  if (value is! String) {
    _fail('INVALID_LOCAL_DATE', path, 'Expected YYYY-MM-DD.');
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) _fail('INVALID_LOCAL_DATE', path, 'Expected YYYY-MM-DD.');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (year < 1) {
    _fail(
      'INVALID_LOCAL_DATE',
      path,
      'Local date year must be from 0001 to 9999.',
    );
  }
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    _fail('INVALID_LOCAL_DATE', path, 'Invalid calendar date.');
  }
  return value;
}

String _timezone(Object? value, String path) {
  final identifier = _string(value, path, maximum: 128);
  if (!medicationSyncCanonicalTimezones.contains(identifier)) {
    _fail(
      'INVALID_TIMEZONE',
      path,
      'Expected a canonical IANA timezone identifier.',
    );
  }
  if (!timezone.timeZoneDatabase.isInitialized) {
    timezone_data.initializeTimeZones();
  }
  if (identifier != 'UTC' &&
      !timezone.timeZoneDatabase.locations.containsKey(identifier)) {
    _fail(
      'UNSUPPORTED_TIMEZONE_DATABASE',
      path,
      'Canonical timezone is unavailable in the bundled database.',
    );
  }
  return identifier;
}

String _localDateAt(String scheduledAt, String timezoneId) {
  final location = timezoneId == 'UTC'
      ? timezone.UTC
      : timezone.getLocation(timezoneId);
  final local = timezone.TZDateTime.from(DateTime.parse(scheduledAt), location);
  String digits(int number) => number.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${digits(local.month)}-'
      '${digits(local.day)}';
}

String? _nullableString(Object? value, String path, {int maximum = 1024}) =>
    value == null ? null : _string(value, path, maximum: maximum);

String _cursor(Object? value, String path) {
  final result = _string(value, path, maximum: 16);
  final parsed = BigInt.tryParse(result);
  if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(result) ||
      parsed == null ||
      parsed > BigInt.from(9007199254740991)) {
    _fail(
      'INVALID_CURSOR',
      path,
      'Expected a canonical non-negative decimal safe-integer string.',
    );
  }
  return result;
}

String? _nullableCursor(Object? value, String path) =>
    value == null ? null : _cursor(value, path);

HouseholdRoleContract _parseHouseholdRole(Object? value, String path) =>
    _enum(value, HouseholdRoleContract.values, (role) => role.wireValue, path);

MedicationContract _parseMedication(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'id',
    'householdId',
    'name',
    'pillType',
    'instructions',
    'revision',
    'deletedAt',
    'updatedAt',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  return MedicationContract(
    id: _id(data['id'], '$path.id'),
    householdId: _id(data['householdId'], '$path.householdId'),
    name: _string(data['name'], '$path.name', maximum: 200),
    pillType: _enum(
      data['pillType'],
      PillTypeContract.values,
      (type) => type.wireValue,
      '$path.pillType',
    ),
    instructions: _nullableString(
      data['instructions'],
      '$path.instructions',
      maximum: 2000,
    ),
    revision: _integer(data['revision'], '$path.revision', minimum: 1),
    deletedAt: _nullableTimestamp(data['deletedAt'], '$path.deletedAt'),
    updatedAt: _utcTimestamp(data['updatedAt'], '$path.updatedAt'),
  );
}

MedicationScheduleContract _parseSchedule(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'id',
    'householdId',
    'medicationId',
    'label',
    'hour',
    'minute',
    'timezoneId',
    'enabled',
    'revision',
    'deletedAt',
    'updatedAt',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  return MedicationScheduleContract(
    id: _id(data['id'], '$path.id'),
    householdId: _id(data['householdId'], '$path.householdId'),
    medicationId: _id(data['medicationId'], '$path.medicationId'),
    label: _string(data['label'], '$path.label', maximum: 200),
    hour: _integer(data['hour'], '$path.hour', minimum: 0, maximum: 23),
    minute: _integer(data['minute'], '$path.minute', minimum: 0, maximum: 59),
    timezoneId: _timezone(data['timezoneId'], '$path.timezoneId'),
    enabled: _boolean(data['enabled'], '$path.enabled'),
    revision: _integer(data['revision'], '$path.revision', minimum: 1),
    deletedAt: _nullableTimestamp(data['deletedAt'], '$path.deletedAt'),
    updatedAt: _utcTimestamp(data['updatedAt'], '$path.updatedAt'),
  );
}

OccurrenceRefContract _parseOccurrenceRef(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'occurrenceId',
    'scheduleId',
    'scheduleRevision',
    'scheduledAt',
    'localDate',
    'timezoneId',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final scheduleId = _id(data['scheduleId'], '$path.scheduleId');
  final scheduleRevision = _integer(
    data['scheduleRevision'],
    '$path.scheduleRevision',
    minimum: 1,
  );
  final scheduledAt = _canonicalUtcTimestamp(
    data['scheduledAt'],
    '$path.scheduledAt',
  );
  final occurrenceId = _occurrenceId(
    data['occurrenceId'],
    '$path.occurrenceId',
  );
  if (occurrenceId != '$scheduleId:$scheduleRevision:$scheduledAt') {
    _fail(
      'INVALID_OCCURRENCE_ID',
      '$path.occurrenceId',
      'Occurrence ID does not match its schedule revision and instant.',
    );
  }
  final timezoneId = _timezone(data['timezoneId'], '$path.timezoneId');
  final occurrenceLocalDate = _localDate(data['localDate'], '$path.localDate');
  if (occurrenceLocalDate != _localDateAt(scheduledAt, timezoneId)) {
    _fail(
      'OCCURRENCE_LOCAL_DATE_MISMATCH',
      '$path.localDate',
      'Local date does not match scheduled instant in its timezone.',
    );
  }
  return OccurrenceRefContract(
    occurrenceId: occurrenceId,
    scheduleId: scheduleId,
    scheduleRevision: scheduleRevision,
    scheduledAt: scheduledAt,
    localDate: occurrenceLocalDate,
    timezoneId: timezoneId,
  );
}

DoseEventContract _parseDoseEvent(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'id',
    'householdId',
    'medicationId',
    'occurrence',
    'kind',
    'occurredAt',
    'actorAccountId',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  return DoseEventContract(
    id: _id(data['id'], '$path.id'),
    householdId: _id(data['householdId'], '$path.householdId'),
    medicationId: _id(data['medicationId'], '$path.medicationId'),
    occurrence: _parseOccurrenceRef(data['occurrence'], '$path.occurrence'),
    kind: _enum(
      data['kind'],
      DoseEventKindContract.values,
      (kind) => kind.wireValue,
      '$path.kind',
    ),
    occurredAt: _canonicalUtcTimestamp(data['occurredAt'], '$path.occurredAt'),
    actorAccountId: _id(data['actorAccountId'], '$path.actorAccountId'),
  );
}

MedicationMutationPayloadContract _parseMedicationPayload(
  Object? value,
  String path,
) {
  final data = _object(value, path);
  _exactKeys(data, ['name', 'pillType', 'instructions'], path);
  return MedicationMutationPayloadContract(
    name: _string(data['name'], '$path.name', maximum: 200),
    pillType: _enum(
      data['pillType'],
      PillTypeContract.values,
      (type) => type.wireValue,
      '$path.pillType',
    ),
    instructions: _nullableString(
      data['instructions'],
      '$path.instructions',
      maximum: 2000,
    ),
  );
}

ScheduleMutationPayloadContract _parseSchedulePayload(
  Object? value,
  String path,
) {
  final data = _object(value, path);
  _exactKeys(data, [
    'medicationId',
    'label',
    'hour',
    'minute',
    'timezoneId',
    'enabled',
  ], path);
  return ScheduleMutationPayloadContract(
    medicationId: _id(data['medicationId'], '$path.medicationId'),
    label: _string(data['label'], '$path.label', maximum: 200),
    hour: _integer(data['hour'], '$path.hour', minimum: 0, maximum: 23),
    minute: _integer(data['minute'], '$path.minute', minimum: 0, maximum: 59),
    timezoneId: _timezone(data['timezoneId'], '$path.timezoneId'),
    enabled: _boolean(data['enabled'], '$path.enabled'),
  );
}

DoseEventMutationPayloadContract _parseDoseEventPayload(
  Object? value,
  String path,
) {
  final data = _object(value, path);
  _exactKeys(data, ['medicationId', 'occurrence', 'kind', 'occurredAt'], path);
  return DoseEventMutationPayloadContract(
    medicationId: _id(data['medicationId'], '$path.medicationId'),
    occurrence: _parseOccurrenceRef(data['occurrence'], '$path.occurrence'),
    kind: _enum(
      data['kind'],
      DoseEventKindContract.values,
      (kind) => kind.wireValue,
      '$path.kind',
    ),
    occurredAt: _canonicalUtcTimestamp(data['occurredAt'], '$path.occurredAt'),
  );
}

MutationContract _parseMutation(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'mutationId',
    'deviceId',
    'idempotencyKey',
    'entityType',
    'operation',
    'entityId',
    'baseRevision',
    'payload',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final entityType = _enum(
    data['entityType'],
    EntityTypeContract.values,
    (type) => type.wireValue,
    '$path.entityType',
  );
  final operation = _enum(
    data['operation'],
    MutationOperationContract.values,
    (value) => value.wireValue,
    '$path.operation',
  );
  final baseRevision = data['baseRevision'] == null
      ? null
      : _integer(data['baseRevision'], '$path.baseRevision', minimum: 1);
  MutationPayloadContract? payload;
  if (entityType == EntityTypeContract.medication &&
      operation == MutationOperationContract.upsert) {
    payload = _parseMedicationPayload(data['payload'], '$path.payload');
  } else if (entityType == EntityTypeContract.schedule &&
      operation == MutationOperationContract.upsert) {
    payload = _parseSchedulePayload(data['payload'], '$path.payload');
  } else if ((entityType == EntityTypeContract.medication ||
          entityType == EntityTypeContract.schedule) &&
      operation == MutationOperationContract.delete) {
    if (baseRevision == null) {
      _fail(
        'BASE_REVISION_REQUIRED',
        '$path.baseRevision',
        'Delete requires a positive base revision.',
      );
    }
    if (data['payload'] != null) {
      _fail(
        'INVALID_MUTATION_PAYLOAD',
        '$path.payload',
        'Delete payload must be null.',
      );
    }
  } else if (entityType == EntityTypeContract.doseEvent &&
      operation == MutationOperationContract.append) {
    if (baseRevision != null) {
      _fail(
        'INVALID_BASE_REVISION',
        '$path.baseRevision',
        'Dose event append does not use a revision.',
      );
    }
    payload = _parseDoseEventPayload(data['payload'], '$path.payload');
  } else {
    _fail(
      'INVALID_MUTATION_OPERATION',
      '$path.operation',
      'Operation does not match entity type.',
    );
  }
  return MutationContract(
    mutationId: _id(data['mutationId'], '$path.mutationId'),
    deviceId: _id(data['deviceId'], '$path.deviceId'),
    idempotencyKey: _id(data['idempotencyKey'], '$path.idempotencyKey'),
    entityType: entityType,
    operation: operation,
    entityId: _id(data['entityId'], '$path.entityId'),
    baseRevision: baseRevision,
    payload: payload,
  );
}

Map<String, Object?> _validatedMutationJson(Map<String, Object?> json) {
  _parseMutation(json, r'$');
  return json;
}

ConflictContract _parseConflict(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'entityType',
    'entityId',
    'expectedRevision',
    'actualRevision',
    'authoritativeRecord',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final entityType = _enum(
    data['entityType'],
    [EntityTypeContract.medication, EntityTypeContract.schedule],
    (type) => type.wireValue,
    '$path.entityType',
  );
  final entityId = _id(data['entityId'], '$path.entityId');
  final record = entityType == EntityTypeContract.medication
      ? _parseMedication(
          data['authoritativeRecord'],
          '$path.authoritativeRecord',
        )
      : _parseSchedule(
          data['authoritativeRecord'],
          '$path.authoritativeRecord',
        );
  final recordId = switch (record) {
    MedicationContract value => value.id,
    MedicationScheduleContract value => value.id,
    _ => throw StateError('Unsupported conflict record.'),
  };
  final recordRevision = switch (record) {
    MedicationContract value => value.revision,
    MedicationScheduleContract value => value.revision,
    _ => throw StateError('Unsupported conflict record.'),
  };
  final actualRevision = _integer(
    data['actualRevision'],
    '$path.actualRevision',
    minimum: 1,
  );
  final expectedRevision = _integer(
    data['expectedRevision'],
    '$path.expectedRevision',
    minimum: 1,
  );
  if (expectedRevision == actualRevision) {
    _fail(
      'INVALID_CONFLICT_REVISIONS',
      path,
      'Conflict revisions must differ.',
    );
  }
  if (recordId != entityId) {
    _fail(
      'ENTITY_ID_MISMATCH',
      '$path.authoritativeRecord.id',
      'Authoritative record ID does not match conflict entity ID.',
    );
  }
  if (recordRevision != actualRevision) {
    _fail(
      'REVISION_MISMATCH',
      '$path.authoritativeRecord.revision',
      'Authoritative revision does not match conflict revision.',
    );
  }
  return ConflictContract(
    entityType: entityType,
    entityId: entityId,
    expectedRevision: expectedRevision,
    actualRevision: actualRevision,
    authoritativeRecord: record,
  );
}

MutationAckContract _parseMutationAck(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'mutationId',
    'outcome',
    'revision',
    'cursor',
    'errorCode',
    'conflict',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final outcome = _enum(
    data['outcome'],
    MutationOutcomeContract.values,
    (value) => value.wireValue,
    '$path.outcome',
  );
  final revision = data['revision'] == null
      ? null
      : _integer(data['revision'], '$path.revision', minimum: 1);
  final cursor = _nullableCursor(data['cursor'], '$path.cursor');
  final errorCode = _nullableString(data['errorCode'], '$path.errorCode');
  final conflict = data['conflict'] == null
      ? null
      : _parseConflict(data['conflict'], '$path.conflict');
  if ((outcome == MutationOutcomeContract.applied ||
          outcome == MutationOutcomeContract.duplicate) &&
      cursor == null) {
    _fail(
      'CURSOR_REQUIRED',
      '$path.cursor',
      'Applied and duplicate acknowledgements require a cursor.',
    );
  }
  if (outcome == MutationOutcomeContract.conflict && conflict == null) {
    _fail(
      'CONFLICT_REQUIRED',
      '$path.conflict',
      'Conflict acknowledgement requires conflict details.',
    );
  }
  if (outcome == MutationOutcomeContract.rejected && errorCode == null) {
    _fail(
      'ERROR_CODE_REQUIRED',
      '$path.errorCode',
      'Rejected acknowledgement requires an error code.',
    );
  }
  if (outcome != MutationOutcomeContract.conflict && conflict != null) {
    _fail(
      'UNEXPECTED_CONFLICT',
      '$path.conflict',
      'Conflict details are only valid for conflict outcome.',
    );
  }
  if ((outcome == MutationOutcomeContract.applied ||
          outcome == MutationOutcomeContract.duplicate) &&
      errorCode != null) {
    _fail(
      'UNEXPECTED_ERROR_CODE',
      '$path.errorCode',
      'Successful acknowledgements cannot include an error code.',
    );
  }
  if (outcome == MutationOutcomeContract.conflict &&
      (revision != null || cursor != null || errorCode != null)) {
    _fail(
      'CONTRADICTORY_ACK',
      path,
      'Conflict acknowledgement cannot include revision, cursor, or error code.',
    );
  }
  if (outcome == MutationOutcomeContract.rejected &&
      (revision != null || cursor != null)) {
    _fail(
      'CONTRADICTORY_ACK',
      path,
      'Rejected acknowledgement cannot include revision or cursor.',
    );
  }
  return MutationAckContract(
    mutationId: _id(data['mutationId'], '$path.mutationId'),
    outcome: outcome,
    revision: revision,
    cursor: cursor,
    errorCode: errorCode,
    conflict: conflict,
  );
}

PullChangeContract _parsePullChange(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'cursor',
    'entityType',
    'entityId',
    'operation',
    'record',
  ], path);
  final entityType = _enum(
    data['entityType'],
    EntityTypeContract.values,
    (type) => type.wireValue,
    '$path.entityType',
  );
  final operation = _enum(
    data['operation'],
    MutationOperationContract.values,
    (value) => value.wireValue,
    '$path.operation',
  );
  final Object record;
  if (entityType == EntityTypeContract.medication &&
      (operation == MutationOperationContract.upsert ||
          operation == MutationOperationContract.delete)) {
    record = _parseMedication(data['record'], '$path.record');
  } else if (entityType == EntityTypeContract.schedule &&
      (operation == MutationOperationContract.upsert ||
          operation == MutationOperationContract.delete)) {
    record = _parseSchedule(data['record'], '$path.record');
  } else if (entityType == EntityTypeContract.doseEvent &&
      operation == MutationOperationContract.append) {
    record = _parseDoseEvent(data['record'], '$path.record');
  } else {
    _fail(
      'INVALID_CHANGE_OPERATION',
      '$path.operation',
      'Operation does not match entity type.',
    );
  }
  final recordId = switch (record) {
    MedicationContract value => value.id,
    MedicationScheduleContract value => value.id,
    DoseEventContract value => value.id,
    _ => throw StateError('Unsupported pull record.'),
  };
  if (recordId != data['entityId']) {
    _fail(
      'ENTITY_ID_MISMATCH',
      '$path.record.id',
      'Record ID does not match change entity ID.',
    );
  }
  if (operation == MutationOperationContract.delete) {
    final deletedAt = switch (record) {
      MedicationContract value => value.deletedAt,
      MedicationScheduleContract value => value.deletedAt,
      _ => null,
    };
    if (deletedAt == null) {
      _fail(
        'TOMBSTONE_REQUIRED',
        '$path.record.deletedAt',
        'Delete change requires a tombstone.',
      );
    }
  }
  return PullChangeContract(
    cursor: _cursor(data['cursor'], '$path.cursor'),
    entityType: entityType,
    entityId: _id(data['entityId'], '$path.entityId'),
    operation: operation,
    record: record,
  );
}

PullPageContract _parsePullPage(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'robotId',
    'cursor',
    'checkpoint',
    'nextCursor',
    'hasMore',
    'changes',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final changes = data['changes'];
  if (changes is! List) {
    _fail('INVALID_TYPE', '$path.changes', 'Expected an array.');
  }
  final robotId = _id(data['robotId'], '$path.robotId');
  final parsedChanges = [
    for (var index = 0; index < changes.length; index += 1)
      _parsePullChange(changes[index], '$path.changes[$index]'),
  ];
  final pageCursor = _nullableCursor(data['cursor'], '$path.cursor');
  final checkpoint = _cursor(data['checkpoint'], '$path.checkpoint');
  final nextCursor = _cursor(data['nextCursor'], '$path.nextCursor');
  final pageCursorNumber = pageCursor == null
      ? BigInt.from(-1)
      : BigInt.parse(pageCursor);
  final checkpointNumber = BigInt.parse(checkpoint);
  final nextCursorNumber = BigInt.parse(nextCursor);
  if (pageCursorNumber > nextCursorNumber ||
      nextCursorNumber > checkpointNumber) {
    _fail(
      'INVALID_CURSOR_ORDER',
      path,
      'Expected cursor <= nextCursor <= checkpoint.',
    );
  }
  var priorChangeCursor = pageCursorNumber;
  for (var index = 0; index < parsedChanges.length; index += 1) {
    final record = parsedChanges[index].record;
    final householdId = switch (record) {
      MedicationContract value => value.householdId,
      MedicationScheduleContract value => value.householdId,
      DoseEventContract value => value.householdId,
      _ => throw StateError('Unsupported pull record.'),
    };
    if (householdId != robotId) {
      _fail(
        'ROBOT_SCOPE_MISMATCH',
        '$path.changes[$index].record.householdId',
        'Pull record does not belong to the page robot scope.',
      );
    }
    final changeCursor = BigInt.parse(parsedChanges[index].cursor);
    if (changeCursor <= priorChangeCursor || changeCursor > nextCursorNumber) {
      _fail(
        'INVALID_CURSOR_ORDER',
        '$path.changes[$index].cursor',
        'Change cursors must increase and not exceed nextCursor.',
      );
    }
    priorChangeCursor = changeCursor;
  }
  final hasMore = _boolean(data['hasMore'], '$path.hasMore');
  if (hasMore) {
    if (nextCursorNumber >= checkpointNumber) {
      _fail(
        'INVALID_HAS_MORE',
        '$path.hasMore',
        'hasMore requires nextCursor before checkpoint.',
      );
    }
    if (nextCursorNumber <= pageCursorNumber) {
      _fail(
        'PULL_PAGE_NO_PROGRESS',
        '$path.nextCursor',
        'A nonterminal page must advance its cursor.',
      );
    }
  } else if (nextCursorNumber != checkpointNumber) {
    _fail(
      'INCOMPLETE_PULL_PAGE',
      '$path.nextCursor',
      'A terminal page must reach its checkpoint.',
    );
  }
  return PullPageContract(
    robotId: robotId,
    cursor: pageCursor,
    checkpoint: checkpoint,
    nextCursor: nextCursor,
    hasMore: hasMore,
    changes: parsedChanges,
  );
}

MedicationSyncPushRequest _parsePushRequest(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, ['contractVersion', 'robotId', 'operations'], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final operations = data['operations'];
  if (operations is! List) {
    _fail('INVALID_TYPE', '$path.operations', 'Expected an array.');
  }
  if (operations.length > 100) {
    _fail(
      'BATCH_TOO_LARGE',
      '$path.operations',
      'At most 100 operations are allowed.',
    );
  }
  return MedicationSyncPushRequest(
    robotId: _id(data['robotId'], '$path.robotId'),
    operations: [
      for (var index = 0; index < operations.length; index += 1)
        _parseMutation(operations[index], '$path.operations[$index]'),
    ],
  );
}

MedicationSyncPushResponse _parsePushResponse(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, ['contractVersion', 'robotId', 'acknowledgements'], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final acknowledgements = data['acknowledgements'];
  if (acknowledgements is! List) {
    _fail('INVALID_TYPE', '$path.acknowledgements', 'Expected an array.');
  }
  final robotId = _id(data['robotId'], '$path.robotId');
  final parsedAcknowledgements = [
    for (var index = 0; index < acknowledgements.length; index += 1)
      _parseMutationAck(
        acknowledgements[index],
        '$path.acknowledgements[$index]',
      ),
  ];
  for (var index = 0; index < parsedAcknowledgements.length; index += 1) {
    final record = parsedAcknowledgements[index].conflict?.authoritativeRecord;
    final householdId = switch (record) {
      MedicationContract value => value.householdId,
      MedicationScheduleContract value => value.householdId,
      null => null,
      _ => throw StateError('Unsupported conflict record.'),
    };
    if (householdId != null && householdId != robotId) {
      _fail(
        'ROBOT_SCOPE_MISMATCH',
        '$path.acknowledgements[$index].conflict.authoritativeRecord.householdId',
        'Conflict record does not belong to the response robot scope.',
      );
    }
  }
  return MedicationSyncPushResponse(
    robotId: robotId,
    acknowledgements: parsedAcknowledgements,
  );
}

MedicationSyncPullRequest _parsePullRequest(Object? value, String path) {
  final data = _object(value, path);
  _exactKeys(data, [
    'contractVersion',
    'robotId',
    'cursor',
    'checkpoint',
    'limit',
  ], path);
  _version(data['contractVersion'], '$path.contractVersion');
  final cursor = _nullableCursor(data['cursor'], '$path.cursor');
  final checkpoint = _nullableCursor(data['checkpoint'], '$path.checkpoint');
  if ((cursor == null) != (checkpoint == null)) {
    _fail(
      'INVALID_PAGINATION_STATE',
      path,
      'Cursor and checkpoint must either both be null or both be present.',
    );
  }
  if (cursor != null &&
      checkpoint != null &&
      BigInt.parse(cursor) > BigInt.parse(checkpoint)) {
    _fail('INVALID_CURSOR_ORDER', path, 'Cursor cannot exceed checkpoint.');
  }
  return MedicationSyncPullRequest(
    robotId: _id(data['robotId'], '$path.robotId'),
    cursor: cursor,
    checkpoint: checkpoint,
    limit: _integer(data['limit'], '$path.limit', minimum: 1, maximum: 100),
  );
}

Object parseMedicationSyncValue(String type, Object? value) => switch (type) {
  'householdRole' => _parseHouseholdRole(value, r'$'),
  'medication' => _parseMedication(value, r'$'),
  'schedule' => _parseSchedule(value, r'$'),
  'occurrenceRef' => _parseOccurrenceRef(value, r'$'),
  'doseEvent' => _parseDoseEvent(value, r'$'),
  'mutation' => _parseMutation(value, r'$'),
  'ack' => _parseMutationAck(value, r'$'),
  'conflict' => _parseConflict(value, r'$'),
  'pullPage' => _parsePullPage(value, r'$'),
  'pushRequest' => _parsePushRequest(value, r'$'),
  'pushResponse' => _parsePushResponse(value, r'$'),
  'pullRequest' => _parsePullRequest(value, r'$'),
  _ => _fail('UNKNOWN_FIXTURE_TYPE', r'$.type', 'Unknown fixture type: $type.'),
};

Map<String, Object?> normalizeMedicationSyncMutationJson(
  Map<String, Object?> value,
) => MutationContract.fromJson(value).toJson();

Object? _canonicalize(Object? value) {
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  if (value is Map) {
    final map = value.cast<String, Object?>();
    final keys = map.keys.toList()..sort();
    return {for (final key in keys) key: _canonicalize(map[key])};
  }
  return value;
}

void assertMatchingIdempotentReplay(
  String originalRobotId,
  MutationContract original,
  String replayRobotId,
  MutationContract replay,
) {
  final originalScope = _id(originalRobotId, r'$.originalRobotId');
  final replayScope = _id(replayRobotId, r'$.replayRobotId');
  if (originalScope != replayScope) {
    _fail(
      'IDEMPOTENCY_SCOPE_MISMATCH',
      r'$.robotId',
      'Mutations belong to different robot idempotency scopes.',
    );
  }
  if (original.idempotencyKey != replay.idempotencyKey) {
    _fail(
      'IDEMPOTENCY_KEY_MISMATCH',
      r'$.idempotencyKey',
      'Mutations use different idempotency keys.',
    );
  }
  if (jsonEncode(_canonicalize(original.toJson())) !=
      jsonEncode(_canonicalize(replay.toJson()))) {
    _fail(
      'IDEMPOTENCY_KEY_REUSED',
      r'$.idempotencyKey',
      'Idempotency key was reused with a changed mutation.',
    );
  }
}
