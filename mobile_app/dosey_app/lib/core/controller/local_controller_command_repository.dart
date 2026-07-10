import 'dart:math';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

enum ControllerCommandType { dispenseNext, dispenseTest, heartbeat, status }

enum ControllerCommandSessionState {
  pending,
  accepted,
  succeeded,
  failed,
  timedOut,
  cancelled,
  interrupted,
}

enum ControllerCommandFailureReason { nack, jam, offline, disconnect }

enum ControllerCommandEventType {
  commandSent,
  ack,
  nack,
  moveStarted,
  servoDone,
  controllerError,
  heartbeatOk,
  heartbeatMissed,
  offline,
  reconnected,
}

class ControllerCommandSession {
  const ControllerCommandSession({
    required this.id,
    required this.commandType,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.doseId,
    this.scheduleId,
    this.slotId,
    this.failureReason,
    this.acceptedAt,
    this.resolvedAt,
  });

  final String id;
  final ControllerCommandType commandType;
  final String? doseId;
  final String? scheduleId;
  final String? slotId;
  final ControllerCommandSessionState state;
  final ControllerCommandFailureReason? failureReason;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? resolvedAt;
  final DateTime updatedAt;
}

class ControllerCommandEvent {
  const ControllerCommandEvent({
    required this.id,
    required this.sessionId,
    required this.sequence,
    required this.eventType,
    required this.occurredAt,
    this.details,
  });

  final String id;
  final String sessionId;
  final int sequence;
  final ControllerCommandEventType eventType;
  final DateTime occurredAt;
  final String? details;
}

class LocalControllerCommandRepository {
  LocalControllerCommandRepository(this._database, {Random? random})
    : _random = random ?? Random.secure();

  final DoseyDatabase _database;
  final Random _random;

  Future<ControllerCommandSession> createSession({
    required ControllerCommandType commandType,
    required DateTime now,
    String? doseId,
    String? scheduleId,
    String? slotId,
  }) async {
    final normalizedNow = now.toUtc();
    final id = _nextSessionId(commandType, normalizedNow);
    await _database
        .into(_database.controllerCommandSessions)
        .insert(
          ControllerCommandSessionsCompanion.insert(
            id: id,
            commandType: commandType.name,
            doseId: Value(doseId),
            scheduleId: Value(scheduleId),
            slotId: Value(slotId),
            state: ControllerCommandSessionState.pending.name,
            failureReason: const Value.absent(),
            createdAt: normalizedNow,
            acceptedAt: const Value.absent(),
            resolvedAt: const Value.absent(),
            updatedAt: normalizedNow,
          ),
        );
    return _requireSession(id);
  }

  Future<ControllerCommandSession> getSession(String sessionId) {
    return _requireSession(sessionId);
  }

  Future<ControllerCommandEvent> appendEvent(
    String sessionId,
    ControllerCommandEventType eventType, {
    required DateTime occurredAt,
    String? details,
  }) async {
    return _database.transaction(() async {
      await _requireSession(sessionId);
      final nextSequence = await _nextEventSequence(sessionId);
      final id = '$sessionId:$nextSequence';
      await _database
          .into(_database.controllerCommandEvents)
          .insert(
            ControllerCommandEventsCompanion.insert(
              id: id,
              sessionId: sessionId,
              sequence: nextSequence,
              eventType: eventType.name,
              occurredAt: occurredAt.toUtc(),
              details: Value(details),
            ),
          );
      return ControllerCommandEvent(
        id: id,
        sessionId: sessionId,
        sequence: nextSequence,
        eventType: eventType,
        occurredAt: occurredAt.toUtc(),
        details: details,
      );
    });
  }

  Future<void> updateSessionState(
    String sessionId,
    ControllerCommandSessionState state, {
    ControllerCommandFailureReason? failureReason,
    DateTime? acceptedAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) async {
    final normalizedUpdatedAt = (updatedAt ?? DateTime.now()).toUtc();
    final changed =
        await (_database.update(
          _database.controllerCommandSessions,
        )..where((session) => session.id.equals(sessionId))).write(
          ControllerCommandSessionsCompanion(
            state: Value(state.name),
            failureReason: Value(
              _failureReasonForState(state, failureReason)?.name,
            ),
            acceptedAt: acceptedAt == null
                ? const Value.absent()
                : Value(acceptedAt.toUtc()),
            resolvedAt: _resolvedAtValueForState(
              state,
              explicitResolvedAt: resolvedAt,
              updatedAt: normalizedUpdatedAt,
            ),
            updatedAt: Value(normalizedUpdatedAt),
          ),
        );
    if (changed == 0) {
      throw ArgumentError(
        'No controller command session was updated for id "$sessionId".',
      );
    }
  }

  Stream<List<ControllerCommandSession>> watchUnresolvedSessions() {
    final query = _unresolvedSessionsQuery();
    return query.watch().map((rows) => rows.map(_sessionFromRow).toList());
  }

  Future<List<ControllerCommandSession>> getUnresolvedSessions() async {
    final rows = await _unresolvedSessionsQuery().get();
    return rows.map(_sessionFromRow).toList();
  }

  Stream<ControllerCommandSession?> watchLatestRelevantSession() {
    final query = _latestSessionQuery();
    return query.watch().map(_latestRelevantSessionFromRows);
  }

  Future<ControllerCommandSession?> getLatestRelevantSession() async {
    final rows = await _latestSessionQuery().get();
    return _latestRelevantSessionFromRows(rows);
  }

  Future<List<ControllerCommandEvent>> getEventsForSession(
    String sessionId,
  ) async {
    final rows =
        await (_database.select(_database.controllerCommandEvents)
              ..where((event) => event.sessionId.equals(sessionId))
              ..orderBy([(event) => OrderingTerm.asc(event.sequence)]))
            .get();
    return rows.map(_eventFromRow).toList();
  }

  SimpleSelectStatement<
    $ControllerCommandSessionsTable,
    ControllerCommandSessionRow
  >
  _unresolvedSessionsQuery() {
    return _database.select(_database.controllerCommandSessions)
      ..where((session) => session.state.isIn(_unresolvedStateNames))
      ..orderBy([(session) => OrderingTerm.asc(session.updatedAt)]);
  }

  SimpleSelectStatement<
    $ControllerCommandSessionsTable,
    ControllerCommandSessionRow
  >
  _latestSessionQuery() {
    return _database.select(_database.controllerCommandSessions)..orderBy([
      (session) => OrderingTerm.desc(session.updatedAt),
      (session) => OrderingTerm.desc(session.createdAt),
    ]);
  }

  String _nextSessionId(ControllerCommandType commandType, DateTime now) {
    final randomSuffix = _random.nextInt(1 << 32).toRadixString(16);
    return '${commandType.name}:${now.microsecondsSinceEpoch}:$randomSuffix';
  }

  Future<int> _nextEventSequence(String sessionId) async {
    final sequenceMax = _database.controllerCommandEvents.sequence.max();
    final row =
        await (_database.selectOnly(_database.controllerCommandEvents)
              ..addColumns([sequenceMax])
              ..where(
                _database.controllerCommandEvents.sessionId.equals(sessionId),
              ))
            .getSingle();
    return (row.read(sequenceMax) ?? 0) + 1;
  }

  Future<ControllerCommandSession> _requireSession(String sessionId) async {
    final row = await (_database.select(
      _database.controllerCommandSessions,
    )..where((session) => session.id.equals(sessionId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError(
        'No controller command session found for id "$sessionId".',
      );
    }
    return _sessionFromRow(row);
  }

  static ControllerCommandSession _sessionFromRow(
    ControllerCommandSessionRow row,
  ) {
    return ControllerCommandSession(
      id: row.id,
      commandType: ControllerCommandType.values.byName(row.commandType),
      doseId: row.doseId,
      scheduleId: row.scheduleId,
      slotId: row.slotId,
      state: ControllerCommandSessionState.values.byName(row.state),
      failureReason: row.failureReason == null
          ? null
          : ControllerCommandFailureReason.values.byName(row.failureReason!),
      createdAt: row.createdAt.toUtc(),
      acceptedAt: row.acceptedAt?.toUtc(),
      resolvedAt: row.resolvedAt?.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  static ControllerCommandEvent _eventFromRow(ControllerCommandEventRow row) {
    return ControllerCommandEvent(
      id: row.id,
      sessionId: row.sessionId,
      sequence: row.sequence,
      eventType: ControllerCommandEventType.values.byName(row.eventType),
      occurredAt: row.occurredAt.toUtc(),
      details: row.details,
    );
  }

  static ControllerCommandFailureReason? _failureReasonForState(
    ControllerCommandSessionState state,
    ControllerCommandFailureReason? failureReason,
  ) {
    if (state == ControllerCommandSessionState.pending ||
        state == ControllerCommandSessionState.accepted ||
        _resolvedStateNames.contains(state.name)) {
      return null;
    }
    return failureReason;
  }

  static Value<DateTime?> _resolvedAtValueForState(
    ControllerCommandSessionState state, {
    DateTime? explicitResolvedAt,
    required DateTime updatedAt,
  }) {
    if (_resolvedStateNames.contains(state.name)) {
      return Value((explicitResolvedAt ?? updatedAt).toUtc());
    }
    return const Value(null);
  }

  static const List<String> _unresolvedStateNames = [
    'pending',
    'accepted',
    'failed',
    'timedOut',
    'interrupted',
  ];

  static const List<String> _resolvedStateNames = ['succeeded', 'cancelled'];

  static ControllerCommandSession? _latestRelevantSessionFromRows(
    List<ControllerCommandSessionRow> rows,
  ) {
    if (rows.isEmpty) {
      return null;
    }

    final unresolvedRow = rows.where((row) {
      return _unresolvedStateNames.contains(row.state);
    }).firstOrNull;

    return _sessionFromRow(unresolvedRow ?? rows.first);
  }
}
