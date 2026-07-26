import 'dart:async';
import 'dart:math';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

enum ControllerCommandType {
  dispenseNext,
  dispenseTest,
  servoTest,
  heartbeat,
  status,
  deviceInfo,
  configStatus,
  safetyStatus,
  debugOn,
  debugOff,
  pirStatus,
  ledTest,
}

enum ControllerCommandSessionState {
  pending,
  accepted,
  succeeded,
  failed,
  timedOut,
  cancelled,
  interrupted,
}

enum ControllerCommandFailureReason { nack, timeout, jam, offline, disconnect }

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

typedef ControllerCommandSessionIdGenerator =
    String Function(ControllerCommandType commandType, DateTime now);

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

class ControllerCommandHistoryEntry {
  const ControllerCommandHistoryEntry({
    required this.session,
    required this.events,
  });

  final ControllerCommandSession session;
  final List<ControllerCommandEvent> events;
}

abstract interface class ControllerCommandRepository {
  Future<ControllerCommandSession> createSession({
    required ControllerCommandType commandType,
    required DateTime now,
    String? doseId,
    String? scheduleId,
    String? slotId,
  });

  Future<ControllerCommandSession> getSession(String sessionId);

  Future<ControllerCommandEvent> appendEvent(
    String sessionId,
    ControllerCommandEventType eventType, {
    required DateTime occurredAt,
    String? details,
  });

  Future<void> updateSessionState(
    String sessionId,
    ControllerCommandSessionState state, {
    ControllerCommandFailureReason? failureReason,
    DateTime? acceptedAt,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  });

  Stream<List<ControllerCommandSession>> watchUnresolvedSessions();

  Future<List<ControllerCommandSession>> getUnresolvedSessions();

  Stream<ControllerCommandSession?> watchLatestRelevantSession();

  Future<ControllerCommandSession?> getLatestRelevantSession();

  Future<List<ControllerCommandEvent>> getEventsForSession(String sessionId);

  Stream<List<ControllerCommandHistoryEntry>> watchRecentHistory({
    int limit = 12,
  });
}

class LocalControllerCommandRepository implements ControllerCommandRepository {
  LocalControllerCommandRepository(
    this._database, {
    Random? random,
    ControllerCommandSessionIdGenerator? sessionIdGenerator,
  }) : _random = random ?? Random.secure(),
       // Keep the public constructor parameter free of a library-private name.
       // ignore: prefer_initializing_formals
       _sessionIdGenerator = sessionIdGenerator;

  final DoseyDatabase _database;
  final Random _random;
  final ControllerCommandSessionIdGenerator? _sessionIdGenerator;

  @override
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

  @override
  Future<ControllerCommandSession> getSession(String sessionId) {
    return _requireSession(sessionId);
  }

  @override
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

  @override
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

  @override
  Stream<List<ControllerCommandSession>> watchUnresolvedSessions() {
    final query = _unresolvedSessionsQuery();
    return query.watch().map((rows) => rows.map(_sessionFromRow).toList());
  }

  @override
  Future<List<ControllerCommandSession>> getUnresolvedSessions() async {
    final rows = await _unresolvedSessionsQuery().get();
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Stream<ControllerCommandSession?> watchLatestRelevantSession() {
    // Combine two bounded queries instead of scanning the whole table: prefer
    // the newest unresolved session, otherwise fall back to the newest row.
    final unresolvedStream = _unresolvedSessionsLatestFirstQuery().watch();
    final latestStream = (_latestSessionQuery()..limit(1)).watch();
    return _combineLatestRelevantSession(unresolvedStream, latestStream);
  }

  @override
  Future<ControllerCommandSession?> getLatestRelevantSession() async {
    final unresolvedRows = await _unresolvedSessionsLatestFirstQuery().get();
    if (unresolvedRows.isNotEmpty) {
      return _sessionFromRow(unresolvedRows.first);
    }

    final latestRow = await (_latestSessionQuery()..limit(1)).getSingleOrNull();
    return latestRow == null ? null : _sessionFromRow(latestRow);
  }

  @override
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

  @override
  Stream<List<ControllerCommandHistoryEntry>> watchRecentHistory({
    int limit = 12,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    final query = _latestSessionQuery()..limit(limit);
    return query.watch().asyncMap((rows) async {
      return Future.wait(
        rows.map((row) async {
          final session = _sessionFromRow(row);
          return ControllerCommandHistoryEntry(
            session: session,
            events: await getEventsForSession(session.id),
          );
        }),
      );
    });
  }

  SimpleSelectStatement<
    $ControllerCommandSessionsTable,
    ControllerCommandSessionRow
  >
  _unresolvedSessionsQuery() {
    return _database.select(_database.controllerCommandSessions)
      ..where((session) => session.resolvedAt.isNull())
      ..orderBy([(session) => OrderingTerm.asc(session.updatedAt)]);
  }

  SimpleSelectStatement<
    $ControllerCommandSessionsTable,
    ControllerCommandSessionRow
  >
  _unresolvedSessionsLatestFirstQuery() {
    return _database.select(_database.controllerCommandSessions)
      ..where((session) => session.resolvedAt.isNull())
      ..orderBy([
        (session) => OrderingTerm.desc(session.updatedAt),
        (session) => OrderingTerm.desc(session.createdAt),
      ]);
  }

  SimpleSelectStatement<
    $ControllerCommandSessionsTable,
    ControllerCommandSessionRow
  >
  _latestSessionQuery() {
    // Query newest-first once, then prefer any unresolved session in memory so
    // an older safety issue is not hidden by a newer successful test command.
    return _database.select(_database.controllerCommandSessions)..orderBy([
      (session) => OrderingTerm.desc(session.updatedAt),
      (session) => OrderingTerm.desc(session.createdAt),
      (session) => OrderingTerm.desc(session.id),
    ]);
  }

  String _nextSessionId(ControllerCommandType commandType, DateTime now) {
    final generated = _sessionIdGenerator?.call(commandType, now);
    if (generated != null) {
      return generated;
    }
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

  static const List<String> _resolvedStateNames = ['succeeded', 'cancelled'];

  // combineLatest-style merge without adding an rxdart dependency: emit only
  // after both bounded streams have produced a value, then prefer the newest
  // unresolved session and fall back to the newest row overall.
  static Stream<ControllerCommandSession?> _combineLatestRelevantSession(
    Stream<List<ControllerCommandSessionRow>> unresolvedStream,
    Stream<List<ControllerCommandSessionRow>> latestStream,
  ) {
    late final StreamController<ControllerCommandSession?> controller;
    StreamSubscription<List<ControllerCommandSessionRow>>? unresolvedSub;
    StreamSubscription<List<ControllerCommandSessionRow>>? latestSub;
    List<ControllerCommandSessionRow> unresolvedRows =
        const <ControllerCommandSessionRow>[];
    List<ControllerCommandSessionRow> latestRows =
        const <ControllerCommandSessionRow>[];
    var hasUnresolved = false;
    var hasLatest = false;

    void emit() {
      if (!hasUnresolved || !hasLatest) {
        return;
      }
      if (unresolvedRows.isNotEmpty) {
        controller.add(_sessionFromRow(unresolvedRows.first));
        return;
      }
      controller.add(
        latestRows.isEmpty ? null : _sessionFromRow(latestRows.first),
      );
    }

    controller = StreamController<ControllerCommandSession?>(
      onListen: () {
        unresolvedSub = unresolvedStream.listen((rows) {
          unresolvedRows = rows;
          hasUnresolved = true;
          emit();
        }, onError: controller.addError);
        latestSub = latestStream.listen((rows) {
          latestRows = rows;
          hasLatest = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await unresolvedSub?.cancel();
        await latestSub?.cancel();
      },
    );

    return controller.stream;
  }
}
