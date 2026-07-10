import 'dart:async';

import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'successful dispense with slot persists session/events, marks slot dispensed, and logs movement only',
    () async {
      final fixture = await _LifecycleFixture.create();
      addTearDown(fixture.close);

      await fixture.service.requestDoseDispense(
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
        slotId: 'slot-1',
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessionRows, hasLength(1));
      expect(
        sessionRows.single.commandType,
        ControllerCommandType.dispenseNext.name,
      );
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.succeeded.name,
      );
      expect(sessionRows.single.doseId, 'dose-1');
      expect(sessionRows.single.scheduleId, 'schedule-1');
      expect(sessionRows.single.slotId, 'slot-1');
      expect(sessionRows.single.acceptedAt, isNotNull);
      expect(sessionRows.single.resolvedAt, isNotNull);

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.ack.name,
        ControllerCommandEventType.servoDone.name,
      ]);

      final slot = await fixture.slotRow('slot-1');
      expect(slot.status, CarouselSlotStatus.dispensed.storageValue);

      final doseLogRows = await fixture.database
          .select(fixture.database.doseLogEvents)
          .get();
      expect(doseLogRows, hasLength(1));
      expect(
        doseLogRows.single.kind,
        DoseLogEventKind.controllerDispenseSucceeded.name,
      );
      expect(doseLogRows.single.doseId, 'dose-1');
      expect(doseLogRows.single.marksDoseTaken, isFalse);
    },
  );

  test(
    'rejected dispense before acceptance keeps slot loaded, marks failed with nack, and skips movement log',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _RejectingControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerCommandRejectedException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessionRows, hasLength(1));
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.failed.name,
      );
      expect(
        sessionRows.single.failureReason,
        ControllerCommandFailureReason.nack.name,
      );

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.nack.name,
      ]);

      final slot = await fixture.slotRow('slot-1');
      expect(slot.status, CarouselSlotStatus.loaded.storageValue);
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'offline before acceptance keeps slot loaded, marks failed offline, and skips movement log',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _OfflineBeforeAcceptanceControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerTransportOfflineException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.failed.name,
      );
      expect(
        sessionRows.single.failureReason,
        ControllerCommandFailureReason.offline.name,
      );

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.offline.name,
      ]);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.loaded.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'local precondition failures keep the slot loaded and do not quarantine it',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _PreconditionFailureControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerCommandPreconditionException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.failed.name,
      );
      expect(sessionRows.single.failureReason, isNull);

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.controllerError.name,
      ]);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.loaded.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'timeout after acceptance moves slot to needs review and marks session timed out',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _TimeoutAfterAcceptanceControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerCommandTimeoutException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.timedOut.name,
      );
      expect(sessionRows.single.acceptedAt, isNull);

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.controllerError.name,
      ]);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.needsReview.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'jam after acceptance moves slot to needs review and marks session failed with jam',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _JamAfterAcceptanceControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerCommandJamException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.failed.name,
      );
      expect(
        sessionRows.single.failureReason,
        ControllerCommandFailureReason.jam.name,
      );
      expect(sessionRows.single.acceptedAt, isNull);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.needsReview.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'disconnect after ambiguous acceptance moves slot to needs review and marks session interrupted',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _DisconnectAfterAcceptanceControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(isA<ControllerCommandInterruptedException>()),
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.interrupted.name,
      );
      expect(
        sessionRows.single.failureReason,
        ControllerCommandFailureReason.disconnect.name,
      );
      expect(sessionRows.single.acceptedAt, isNull);

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.offline.name,
      ]);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.needsReview.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'unknown transport loss keeps the slot in needs review instead of reopening it as loaded',
    () async {
      final fixture = await _LifecycleFixture.create(
        gateway: _UnknownTransportLossControllerGateway(),
      );
      addTearDown(fixture.close);

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsStateError,
      );

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(
        sessionRows.single.state,
        ControllerCommandSessionState.interrupted.name,
      );

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.controllerError.name,
      ]);

      expect(
        (await fixture.slotRow('slot-1')).status,
        CarouselSlotStatus.needsReview.storageValue,
      );
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test(
    'manual dispense persists a session trail without writing shared dose log events',
    () async {
      final fixture = await _LifecycleFixture.create();
      addTearDown(fixture.close);

      await fixture.service.requestManualDispenseTest();

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessionRows, hasLength(1));
      expect(
        sessionRows.single.commandType,
        ControllerCommandType.dispenseTest.name,
      );
      expect(sessionRows.single.slotId, isNull);

      final eventRows = await fixture.database
          .select(fixture.database.controllerCommandEvents)
          .get();
      expect(eventRows.map((row) => row.eventType).toList(), <String>[
        ControllerCommandEventType.commandSent.name,
        ControllerCommandEventType.ack.name,
        ControllerCommandEventType.servoDone.name,
      ]);

      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
      expect(await fixture.slotRow('slot-1'), isNotNull);
    },
  );

  test(
    'duplicate slot dispense requests are rejected while one is already in flight',
    () async {
      final gateway = _BlockingControllerGateway();
      final fixture = await _LifecycleFixture.create(gateway: gateway);
      addTearDown(fixture.close);

      final firstRequest = fixture.service.requestDoseDispense(
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
        slotId: 'slot-1',
      );

      await gateway.requestStarted.future;

      await expectLater(
        fixture.service.requestDoseDispense(
          doseId: 'dose-1',
          scheduleId: 'schedule-1',
          slotId: 'slot-1',
        ),
        throwsA(
          isA<DuplicateDispenseRequestException>().having(
            (error) => error.message,
            'message',
            'A dispense request is already in progress for this dose.',
          ),
        ),
      );

      gateway.completeRequest();
      await firstRequest;

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessionRows, hasLength(1));
    },
  );

  test(
    'mixed slot and dose entry points still share the same in-flight guard',
    () async {
      final gateway = _BlockingControllerGateway();
      final fixture = await _LifecycleFixture.create(gateway: gateway);
      addTearDown(fixture.close);

      final firstRequest = fixture.service.requestDoseDispense(
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
        slotId: 'slot-1',
      );

      await gateway.requestStarted.future;

      await expectLater(
        fixture.service.requestDoseDispense(doseId: 'dose-1'),
        throwsA(isA<DuplicateDispenseRequestException>()),
      );

      gateway.completeRequest();
      await firstRequest;

      final sessionRows = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessionRows, hasLength(1));
    },
  );

  test('post-send local failures do not reopen the slot as loaded', () async {
    final fixture = await _LifecycleFixture.create(
      doseLog: _ThrowingDoseLogRepository(),
    );
    addTearDown(fixture.close);

    await expectLater(
      fixture.service.requestDoseDispense(
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
        slotId: 'slot-1',
      ),
      throwsStateError,
    );

    final slot = await fixture.slotRow('slot-1');
    expect(slot.status, isNot(CarouselSlotStatus.loaded.storageValue));

    final sessionRows = await fixture.database
        .select(fixture.database.controllerCommandSessions)
        .get();
    expect(
      sessionRows.single.state,
      ControllerCommandSessionState.interrupted.name,
    );
  });
}

class _LifecycleFixture {
  _LifecycleFixture({required this.database, required this.service});

  final DoseyDatabase database;
  final ControllerLifecycleService service;

  static Future<_LifecycleFixture> create({
    ControllerGateway? gateway,
    DoseLogRepository? doseLog,
  }) async {
    final database = DoseyDatabase.inMemory();
    final now = DateTime(2026, 7, 10, 12);
    await _seedLoadedSlot(database, now: now);
    final service = ControllerLifecycleService(
      controller: gateway ?? _AcceptingControllerGateway(),
      commandRepository: LocalControllerCommandRepository(database),
      doseLog: doseLog ?? DriftDoseLogRepository(database),
      carouselSlots: LocalCarouselSlotRepository(database),
      now: () => now,
    );
    return _LifecycleFixture(database: database, service: service);
  }

  Future<CarouselSlotRow> slotRow(String id) {
    return (database.select(
      database.carouselSlots,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<void> close() => database.close();

  static Future<void> _seedLoadedSlot(
    DoseyDatabase database, {
    required DateTime now,
  }) async {
    await database
        .into(database.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: 'prescription-1',
            name: 'Test med',
            pillType: 'tablet',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.reminderSchedules)
        .insert(
          ReminderSchedulesCompanion.insert(
            id: 'schedule-1',
            label: 'Morning meds',
            prescriptionId: const Value('prescription-1'),
            profileId: const Value('schedule-1'),
            hour: 9,
            minute: 0,
            isEnabled: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.carouselSlots)
        .insert(
          CarouselSlotsCompanion.insert(
            id: 'slot-1',
            slotNumber: 1,
            prescriptionId: 'prescription-1',
            scheduleId: 'schedule-1',
            profileId: 'schedule-1',
            status: CarouselSlotStatus.loaded.storageValue,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}

class _AcceptingControllerGateway implements ControllerGateway {
  @override
  Future<void> cancelActiveCommand() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> requestDispense({required String doseId}) async {}

  @override
  Stream<ControllerSnapshot> watchController() {
    return Stream.value(const ControllerSnapshot.connected());
  }
}

class _RejectingControllerGateway extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerCommandRejectedException();
  }
}

class _OfflineBeforeAcceptanceControllerGateway
    extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerTransportOfflineException();
  }
}

class _TimeoutAfterAcceptanceControllerGateway
    extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerCommandTimeoutException();
  }
}

class _PreconditionFailureControllerGateway
    extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerCommandPreconditionException(
      'Robot Mode must be active before dispense.',
    );
  }
}

class _JamAfterAcceptanceControllerGateway extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerCommandJamException();
  }
}

class _DisconnectAfterAcceptanceControllerGateway
    extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw const ControllerCommandInterruptedException();
  }
}

class _UnknownTransportLossControllerGateway
    extends _AcceptingControllerGateway {
  @override
  Future<void> requestDispense({required String doseId}) async {
    throw StateError('transport dropped before acknowledgment was observable');
  }
}

class _BlockingControllerGateway extends _AcceptingControllerGateway {
  final requestStarted = Completer<void>();
  final _releaseRequest = Completer<void>();

  @override
  Future<void> requestDispense({required String doseId}) async {
    if (!requestStarted.isCompleted) {
      requestStarted.complete();
    }
    await _releaseRequest.future;
  }

  void completeRequest() {
    if (!_releaseRequest.isCompleted) {
      _releaseRequest.complete();
    }
  }
}

class _ThrowingDoseLogRepository implements DoseLogRepository {
  @override
  Future<void> addEvent(DoseLogEvent event) async {
    throw StateError('dose log write failed');
  }

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    return const Stream.empty();
  }
}
