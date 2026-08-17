import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'caregiver_snapshot.dart';
import 'caregiver_snapshot_controller.dart';

class MedicationSyncFunctionResponse {
  const MedicationSyncFunctionResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract interface class AppwriteMedicationSyncFunctionsApi {
  Future<String> currentAccountId();

  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  });
}

class AppwriteMedicationSyncFunctionsApiAdapter
    implements AppwriteMedicationSyncFunctionsApi {
  AppwriteMedicationSyncFunctionsApiAdapter(this._functions, this._account);

  final Functions _functions;
  final Account _account;

  @override
  Future<String> currentAccountId() async => (await _account.get()).$id;

  @override
  Future<MedicationSyncFunctionResponse> execute({
    required String functionId,
    required String body,
  }) async {
    final execution = await _functions.createExecution(
      functionId: functionId,
      body: body,
      xasync: false,
      method: appwrite_enums.ExecutionMethod.pOST,
    );
    return MedicationSyncFunctionResponse(
      statusCode: execution.responseStatusCode,
      body: execution.responseBody,
    );
  }
}

class AppwriteCaregiverSyncGateway implements CaregiverSyncGateway {
  AppwriteCaregiverSyncGateway(
    this._api, {
    required this.pushFunctionId,
    required this.pullFunctionId,
    required this.deviceId,
    required this._newId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppwriteMedicationSyncFunctionsApi _api;
  final String pushFunctionId;
  final String pullFunctionId;
  final String deviceId;
  final String Function() _newId;
  final DateTime Function() _now;
  final Map<({String accountId, String robotId}), _CacheState> _caches = {};
  final Map<({String accountId, String robotId}), int> _generations = {};

  @override
  Future<CaregiverPullResult> pull(
    String robotId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  }) async {
    final accountId = await _currentAccountId();
    final cacheKey = (accountId: accountId, robotId: robotId);
    final generation = (_generations[cacheKey] ?? 0) + 1;
    _generations[cacheKey] = generation;
    var pageCursor = cursor;
    var pageCheckpoint = checkpoint;
    final previous = _caches[cacheKey];
    final canContinue =
        previous?.cursor == cursor && previous?.checkpoint == checkpoint;
    final cache = _RobotCache.copyOf(canContinue ? previous?.cache : null);

    while (true) {
      final request = MedicationSyncPullRequest(
        robotId: robotId,
        cursor: pageCursor,
        checkpoint: pageCheckpoint,
        limit: limit,
      );
      final response = await _execute(
        pullFunctionId,
        request.toJson(),
        expectedAccountId: accountId,
      );
      final page = _parsePullPage(response);
      if (page.robotId != robotId ||
          page.cursor != pageCursor ||
          (pageCheckpoint != null && page.checkpoint != pageCheckpoint)) {
        throw const CaregiverSyncException(
          'Medication data returned an invalid response.',
        );
      }
      _applyPage(cache, page);
      pageCursor = page.nextCursor;
      pageCheckpoint = page.checkpoint;
      if (!page.hasMore) break;
    }
    if (_generations[cacheKey] == generation) {
      _caches[cacheKey] = _CacheState(
        cache: cache,
        cursor: pageCursor,
        checkpoint: pageCheckpoint,
      );
    }

    return CaregiverPullResult(
      snapshot: CaregiverSnapshot(
        householdId: robotId,
        revision: pageCursor,
        generatedAt: _now(),
        medications: cache.medications.values.toList(growable: false),
        schedules: cache.schedules.values.toList(growable: false),
        events: cache.events.values.toList(growable: false),
      ),
      cursor: pageCursor,
      checkpoint: pageCheckpoint,
    );
  }

  @override
  Future<void> push(String robotId, List<CaregiverMutation> operations) async {
    if (operations.isEmpty) return;
    final accountId = await _currentAccountId();
    final contracts = <MutationContract>[];
    try {
      for (final operation in operations) {
        contracts.add(_mutation(accountId, robotId, operation));
      }
      final mutationIds = contracts.map((value) => value.mutationId).toSet();
      final idempotencyKeys = contracts
          .map((value) => value.idempotencyKey)
          .toSet();
      if (mutationIds.length != contracts.length ||
          idempotencyKeys.length != contracts.length) {
        throw StateError('Duplicate mutation identity.');
      }
    } on Object {
      throw const CaregiverSyncException('Medication change is invalid.');
    }
    final request = MedicationSyncPushRequest(
      robotId: robotId,
      operations: contracts,
    );
    final response = await _execute(
      pushFunctionId,
      request.toJson(),
      expectedAccountId: accountId,
    );
    final parsed = _parsePushResponse(response);
    final expectedIds = contracts.map((value) => value.mutationId).toSet();
    final receivedIds = parsed.acknowledgements
        .map((value) => value.mutationId)
        .toSet();
    if (parsed.robotId != robotId ||
        parsed.acknowledgements.length != contracts.length ||
        receivedIds.length != parsed.acknowledgements.length ||
        expectedIds.length != contracts.length ||
        !receivedIds.containsAll(expectedIds) ||
        !expectedIds.containsAll(receivedIds)) {
      throw const CaregiverSyncException(
        'Medication data returned an invalid response.',
      );
    }
    for (final acknowledgement in parsed.acknowledgements) {
      switch (acknowledgement.outcome) {
        case MutationOutcomeContract.applied:
        case MutationOutcomeContract.duplicate:
          break;
        case MutationOutcomeContract.conflict:
          throw const CaregiverConflictException();
        case MutationOutcomeContract.rejected:
          throw CaregiverSyncException(
            'The server rejected a medication change '
            '(${acknowledgement.errorCode}).',
          );
      }
    }
  }

  Future<MedicationSyncFunctionResponse> _execute(
    String functionId,
    Map<String, Object?> body, {
    required String expectedAccountId,
  }) async {
    final encodedBody = jsonEncode(body);
    var authenticationRevalidated = false;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      MedicationSyncFunctionResponse response;
      try {
        response = await _api.execute(
          functionId: functionId,
          body: encodedBody,
        );
      } on AppwriteException catch (error) {
        if (error.code == 401 && !authenticationRevalidated) {
          authenticationRevalidated = true;
          await _revalidateAuthentication(expectedAccountId);
          continue;
        }
        if ((error.code == null || error.code == 429 || error.code! >= 500) &&
            attempt < 2) {
          continue;
        }
        throw CaregiverSyncException(_statusMessage(error.code ?? 500));
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _revalidateAuthentication(expectedAccountId);
        return response;
      }
      if (response.statusCode == 401 && !authenticationRevalidated) {
        authenticationRevalidated = true;
        await _revalidateAuthentication(expectedAccountId);
        continue;
      }
      if ((response.statusCode == 429 || response.statusCode >= 500) &&
          attempt < 2) {
        continue;
      }
      throw CaregiverSyncException(_statusMessage(response.statusCode));
    }
    throw const CaregiverSyncException('Medication data is unavailable.');
  }

  Future<void> _revalidateAuthentication(String expectedAccountId) async {
    try {
      final currentAccountId = await _api.currentAccountId();
      if (currentAccountId != expectedAccountId) {
        throw const CaregiverSyncException(
          'Signed-in account changed. Refresh medication data.',
        );
      }
    } on CaregiverSyncException {
      rethrow;
    } on AppwriteException catch (error) {
      if (error.code != 401) {
        throw CaregiverSyncException(_statusMessage(error.code ?? 500));
      }
      throw const CaregiverSyncException(
        'Sign in again to view medication data.',
      );
    } on Object {
      throw const CaregiverSyncException('Medication data is unavailable.');
    }
  }

  Future<String> _currentAccountId() async {
    try {
      return await _api.currentAccountId();
    } on AppwriteException catch (error) {
      if (error.code == 401) {
        throw const CaregiverSyncException(
          'Sign in again to view medication data.',
        );
      }
      throw CaregiverSyncException(_statusMessage(error.code ?? 500));
    } on Object {
      throw const CaregiverSyncException('Medication data is unavailable.');
    }
  }

  PullPageContract _parsePullPage(MedicationSyncFunctionResponse response) {
    try {
      return PullPageContract.fromJson(_decode(response.body));
    } on Object {
      throw const CaregiverSyncException(
        'Medication data returned an invalid response.',
      );
    }
  }

  MedicationSyncPushResponse _parsePushResponse(
    MedicationSyncFunctionResponse response,
  ) {
    try {
      return MedicationSyncPushResponse.fromJson(_decode(response.body));
    } on Object {
      throw const CaregiverSyncException(
        'Medication data returned an invalid response.',
      );
    }
  }

  Map<String, Object?> _decode(String body) {
    final value = jsonDecode(body);
    if (value is! Map) throw const FormatException('Expected an object.');
    return value.cast<String, Object?>();
  }

  void _applyPage(_RobotCache cache, PullPageContract page) {
    for (final change in page.changes) {
      switch (change.record) {
        case MedicationContract record:
          if (record.deletedAt != null ||
              change.operation == MutationOperationContract.delete) {
            cache.medications.remove(record.id);
          } else {
            cache.medications[record.id] = CaregiverMedication(
              id: record.id,
              name: record.name,
              instructions: record.instructions ?? '',
              pillType: _caregiverPillType(record.pillType),
              active: true,
              version: record.revision,
            );
          }
        case MedicationScheduleContract record:
          if (record.deletedAt != null ||
              change.operation == MutationOperationContract.delete) {
            cache.schedules.remove(record.id);
          } else {
            cache.schedules[record.id] = CaregiverSchedule(
              id: record.id,
              medicationId: record.medicationId,
              label: record.label,
              hour: record.hour,
              minute: record.minute,
              timezoneId: record.timezoneId,
              enabled: record.enabled,
              version: record.revision,
            );
          }
        case DoseEventContract record:
          cache.events[record.id] = CaregiverDoseEvent(
            id: record.id,
            occurrenceId: record.occurrence.occurrenceId,
            scheduleId: record.occurrence.scheduleId,
            scheduleRevision: record.occurrence.scheduleRevision,
            scheduledFor: DateTime.parse(record.occurrence.scheduledAt),
            timezoneId: record.occurrence.timezoneId,
            localDate: record.occurrence.localDate,
            occurredAt: DateTime.parse(record.occurredAt),
            action: _caregiverAction(record.kind),
          );
        default:
          throw const CaregiverSyncException(
            'Medication data returned an invalid response.',
          );
      }
    }
  }

  MutationContract _mutation(
    String accountId,
    String robotId,
    CaregiverMutation mutation,
  ) {
    final mutationId = _newId();
    final values = mutation.values;
    final identity = (
      mutationId: mutationId,
      deviceId: deviceId,
      idempotencyKey: '$deviceId:$mutationId',
    );
    return switch (mutation.kind) {
      CaregiverMutationKind.upsertMedication => MutationContract(
        mutationId: identity.mutationId,
        deviceId: identity.deviceId,
        idempotencyKey: identity.idempotencyKey,
        entityType: EntityTypeContract.medication,
        operation: MutationOperationContract.upsert,
        entityId: values['id']! as String,
        baseRevision: _baseRevision(values['version']),
        payload: MedicationMutationPayloadContract(
          name: values['name']! as String,
          pillType: _pillType(values['pillType']! as String),
          instructions: _nullableInstructions(
            values['instructions']! as String,
          ),
        ),
      ),
      CaregiverMutationKind.deleteMedication => MutationContract(
        mutationId: identity.mutationId,
        deviceId: identity.deviceId,
        idempotencyKey: identity.idempotencyKey,
        entityType: EntityTypeContract.medication,
        operation: MutationOperationContract.delete,
        entityId: values['id']! as String,
        baseRevision: values['version']! as int,
        payload: null,
      ),
      CaregiverMutationKind.upsertSchedule => MutationContract(
        mutationId: identity.mutationId,
        deviceId: identity.deviceId,
        idempotencyKey: identity.idempotencyKey,
        entityType: EntityTypeContract.schedule,
        operation: MutationOperationContract.upsert,
        entityId: values['id']! as String,
        baseRevision: _baseRevision(values['version']),
        payload: ScheduleMutationPayloadContract(
          medicationId: values['medicationId']! as String,
          label: values['label']! as String,
          hour: values['hour']! as int,
          minute: values['minute']! as int,
          timezoneId: values['timezoneId']! as String,
          enabled: values['enabled']! as bool,
        ),
      ),
      CaregiverMutationKind.deleteSchedule => MutationContract(
        mutationId: identity.mutationId,
        deviceId: identity.deviceId,
        idempotencyKey: identity.idempotencyKey,
        entityType: EntityTypeContract.schedule,
        operation: MutationOperationContract.delete,
        entityId: values['id']! as String,
        baseRevision: values['version']! as int,
        payload: null,
      ),
      CaregiverMutationKind.recordDose => _doseMutation(
        accountId,
        robotId,
        identity,
        values,
      ),
    };
  }

  MutationContract _doseMutation(
    String accountId,
    String robotId,
    ({String mutationId, String deviceId, String idempotencyKey}) identity,
    Map<String, Object?> values,
  ) {
    final reference = values['occurrence']! as CaregiverOccurrence;
    final scheduleId = reference.scheduleId;
    final schedule = _caches[(accountId: accountId, robotId: robotId)]
        ?.cache
        .schedules[scheduleId];
    final scheduledAt = _canonicalUtc(reference.scheduledFor.toIso8601String());
    if (schedule == null ||
        schedule.id != reference.scheduleId ||
        schedule.version != reference.scheduleRevision ||
        schedule.timezoneId != reference.timezoneId ||
        reference.localDate != _localDate(scheduledAt, schedule.timezoneId)) {
      throw StateError('Dose occurrence is no longer current.');
    }
    final occurredAt = _canonicalUtc(_now().toUtc().toIso8601String());
    final occurrence = OccurrenceRefContract(
      occurrenceId: reference.occurrenceId,
      scheduleId: reference.scheduleId,
      scheduleRevision: reference.scheduleRevision,
      scheduledAt: scheduledAt,
      localDate: reference.localDate,
      timezoneId: reference.timezoneId,
    );
    return MutationContract(
      mutationId: identity.mutationId,
      deviceId: identity.deviceId,
      idempotencyKey: identity.idempotencyKey,
      entityType: EntityTypeContract.doseEvent,
      operation: MutationOperationContract.append,
      entityId: _newId(),
      baseRevision: null,
      payload: DoseEventMutationPayloadContract(
        medicationId: schedule.medicationId,
        occurrence: occurrence,
        kind: _eventKind(values['action']! as String),
        occurredAt: occurredAt,
      ),
    );
  }

  int? _baseRevision(Object? value) {
    final revision = value! as int;
    return revision == 0 ? null : revision;
  }

  String? _nullableInstructions(String value) => value.isEmpty ? null : value;

  String _statusMessage(int statusCode) => switch (statusCode) {
    401 => 'Sign in again to view medication data.',
    403 => 'You do not have access to this household.',
    _ => 'Medication data is unavailable.',
  };
}

class _RobotCache {
  _RobotCache();

  _RobotCache.copyOf(_RobotCache? source) {
    if (source == null) return;
    medications.addAll(source.medications);
    schedules.addAll(source.schedules);
    events.addAll(source.events);
  }

  final Map<String, CaregiverMedication> medications = {};
  final Map<String, CaregiverSchedule> schedules = {};
  final Map<String, CaregiverDoseEvent> events = {};
}

class _CacheState {
  const _CacheState({
    required this.cache,
    required this.cursor,
    required this.checkpoint,
  });

  final _RobotCache cache;
  final String? cursor;
  final String? checkpoint;
}

CaregiverPillType _caregiverPillType(PillTypeContract type) => switch (type) {
  PillTypeContract.pill => CaregiverPillType.pill,
  PillTypeContract.capsule => CaregiverPillType.capsule,
  PillTypeContract.tablet => CaregiverPillType.tablet,
};

PillTypeContract _pillType(String type) => switch (type) {
  'pill' => PillTypeContract.pill,
  'capsule' => PillTypeContract.capsule,
  'tablet' => PillTypeContract.tablet,
  _ => throw ArgumentError.value(type, 'type'),
};

CaregiverDoseAction _caregiverAction(DoseEventKindContract kind) =>
    switch (kind) {
      DoseEventKindContract.takenConfirmed => CaregiverDoseAction.taken,
      DoseEventKindContract.skipped => CaregiverDoseAction.skipped,
      DoseEventKindContract.missed => throw const CaregiverSyncException(
        'This app cannot display missed dose outcomes yet.',
      ),
      DoseEventKindContract.snoozed => CaregiverDoseAction.snoozed,
      DoseEventKindContract.helpRequested => CaregiverDoseAction.helpRequested,
    };

DoseEventKindContract _eventKind(String action) => switch (action) {
  'taken' => DoseEventKindContract.takenConfirmed,
  'skipped' => DoseEventKindContract.skipped,
  'snoozed' => DoseEventKindContract.snoozed,
  'helpRequested' => DoseEventKindContract.helpRequested,
  _ => throw ArgumentError.value(action, 'action'),
};

String _canonicalUtc(String value) {
  final instant = DateTime.parse(value).toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return '${digits(instant.year, 4)}-${digits(instant.month, 2)}-'
      '${digits(instant.day, 2)}T${digits(instant.hour, 2)}:'
      '${digits(instant.minute, 2)}:${digits(instant.second, 2)}.'
      '${digits(instant.millisecond, 3)}Z';
}

String _localDate(String scheduledAt, String timezoneId) {
  if (!timezone.timeZoneDatabase.isInitialized) {
    timezone_data.initializeTimeZones();
  }
  final location = timezoneId == 'UTC'
      ? timezone.UTC
      : timezone.getLocation(timezoneId);
  final local = timezone.TZDateTime.from(DateTime.parse(scheduledAt), location);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}
