import 'dart:async';
import 'dart:convert';

import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/ble_controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'controller_reliability_fixture.dart';
import 'fake_flutter_blue_plus_plugin.dart';

class D1ObservedCommand {
  const D1ObservedCommand(this.id, this.command);

  final String id;
  final D1Command command;
}

class BleControllerLifecycleFixture {
  BleControllerLifecycleFixture._({
    required this.database,
    required this.plugin,
    required this.transport,
    required this.supervisor,
    required this.lifecycle,
    required this.commandRepository,
    required this.healthRepository,
    required this.doseLog,
    required this.scheduler,
    required this._controllerSubscription,
    required this._controllerEventSubscription,
  });

  static const doseId = 'schedule-1:2026-07-10';

  final DoseyDatabase database;
  final FakeFlutterBluePlusPlugin plugin;
  final FlutterBluePlusBleGateway transport;
  final ControllerHealthSupervisor supervisor;
  final ControllerLifecycleService lifecycle;
  final LocalControllerCommandRepository commandRepository;
  final LocalControllerHealthEventRepository healthRepository;
  final DriftDoseLogRepository doseLog;
  final ManualControllerHealthScheduler scheduler;
  final StreamSubscription<ControllerSnapshot> _controllerSubscription;
  final StreamSubscription<ControllerEvent> _controllerEventSubscription;

  ControllerSnapshot latestController = const ControllerSnapshot.disconnected();
  final List<ControllerEvent> controllerEvents = [];
  int _readLineCount = 0;

  static Future<BleControllerLifecycleFixture> create({
    Duration commandTimeout = const Duration(seconds: 8),
    PrepareBleAccess? prepareBleAccess,
  }) async {
    final database = DoseyDatabase.inMemory();
    final plugin = FakeFlutterBluePlusPlugin();
    final scheduler = ManualControllerHealthScheduler(
      DateTime.utc(2026, 7, 10, 9, 5),
    );
    final transport = FlutterBluePlusBleGateway(plugin: plugin);
    final bleController = BleControllerGateway(
      transport: transport,
      canHostRobot: () => true,
      prepareBleAccess: prepareBleAccess,
      commandTimeout: commandTimeout,
    );
    var id = 0;
    final healthRepository = LocalControllerHealthEventRepository(
      database,
      idGenerator: (type, occurredAt) => 'health:${id++}',
    );
    final supervisor = ControllerHealthSupervisor(
      delegate: bleController,
      availability: transport.watchAvailability(),
      eventSink: healthRepository,
      now: () => scheduler.now,
      timerFactory: scheduler.schedule,
      heartbeatInterval: const Duration(seconds: 10),
      reconnectBackoff: const [Duration(seconds: 2), Duration(seconds: 5)],
    );
    final commandRepository = LocalControllerCommandRepository(
      database,
      sessionIdGenerator: (type, now) =>
          '${type.name}:${now.microsecondsSinceEpoch}:${id++}',
    );
    final doseLog = DriftDoseLogRepository(database);
    final lifecycle = ControllerLifecycleService(
      controller: supervisor,
      commandRepository: commandRepository,
      doseLog: doseLog,
      carouselSlots: LocalCarouselSlotRepository(database),
      now: () => scheduler.now,
    );
    await _seedDatabase(database, scheduler.now);

    late final BleControllerLifecycleFixture fixture;
    final subscription = supervisor.watchController().listen((snapshot) {
      fixture.latestController = snapshot;
    });
    final eventSubscription = supervisor.watchControllerEvents().listen((
      event,
    ) {
      fixture.controllerEvents.add(event);
    });
    fixture = BleControllerLifecycleFixture._(
      database: database,
      plugin: plugin,
      transport: transport,
      supervisor: supervisor,
      lifecycle: lifecycle,
      commandRepository: commandRepository,
      healthRepository: healthRepository,
      doseLog: doseLog,
      scheduler: scheduler,
      controllerSubscription: subscription,
      controllerEventSubscription: eventSubscription,
    );
    await fixture.settle();
    return fixture;
  }

  Future<void> connect() async {
    await supervisor.setMonitoringEligible(true);
    await supervisor.connect();
    await settle();
  }

  Future<void> dispense() {
    return lifecycle.requestDoseDispense(
      slotId: 'slot-1',
      doseId: doseId,
      scheduleId: 'schedule-1',
    );
  }

  Future<D1ObservedCommand> nextCommand(D1Command command) async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      final lines = plugin.writtenLines;
      while (_readLineCount < lines.length) {
        final fields = lines[_readLineCount++].split(' ');
        if (fields.length != 4 || fields[0] != 'D1' || fields[1] != 'CMD') {
          continue;
        }
        final observed = D1ObservedCommand(
          fields[2],
          D1Command.values.singleWhere(
            (candidate) => candidate.wireName == fields[3],
          ),
        );
        if (observed.command == command) return observed;
      }
      await settle();
    }
    throw StateError('No ${command.wireName} command was written.');
  }

  void emitEvent(D1ObservedCommand command, String code) {
    emitRaw('D1 EVT ${command.id} $code\n');
  }

  void emitNack(D1ObservedCommand command, String reason) {
    emitRaw('D1 NACK ${command.id} $reason\n');
  }

  void emitError(D1ObservedCommand command, String code) {
    emitRaw('D1 ERROR ${command.id} $code\n');
  }

  void emitRaw(String text, {List<int>? chunkSizes}) {
    final bytes = ascii.encode(text);
    if (chunkSizes == null) {
      plugin.emitProtocolBytes(bytes);
      return;
    }
    var offset = 0;
    for (final size in chunkSizes) {
      if (offset >= bytes.length) break;
      final end = (offset + size).clamp(0, bytes.length);
      plugin.emitProtocolBytes(bytes.sublist(offset, end));
      offset = end;
    }
    if (offset < bytes.length) {
      plugin.emitProtocolBytes(bytes.sublist(offset));
    }
  }

  Future<List<ControllerCommandHistoryEntry>> commandHistory() {
    return commandRepository.watchRecentHistory().first;
  }

  Future<CarouselSlotStatus> slotStatus() async {
    final row = await (database.select(
      database.carouselSlots,
    )..where((slot) => slot.id.equals('slot-1'))).getSingle();
    return CarouselSlotStatus.fromStorageValue(row.status);
  }

  Future<int> availableDoses() async {
    final row =
        await (database.select(database.prescriptions)..where(
              (prescription) => prescription.id.equals('prescription-1'),
            ))
            .getSingle();
    return row.availableDoses;
  }

  Future<List<DoseLogEvent>> doseEvents() => doseLog.watchEvents().first;

  Future<List<ControllerHealthEventType>> healthEventTypes() async {
    final events = await healthRepository.watchRecentEvents(limit: 100).first;
    return events.reversed.map((event) => event.type).toList();
  }

  Future<void> elapse(Duration duration) => scheduler.elapse(duration);

  Future<void> settle() => pumpEventQueue();

  Future<void> waitUntil(
    bool Function() condition, {
    required String description,
  }) async {
    for (var attempt = 0; attempt < 100; attempt += 1) {
      if (condition()) return;
      await settle();
    }
    throw StateError('Timed out waiting for $description.');
  }

  Future<void> close() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(_controllerSubscription.cancel);
    await attempt(_controllerEventSubscription.cancel);
    await attempt(supervisor.close);
    await attempt(transport.close);
    await attempt(plugin.close);
    await attempt(database.close);

    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStackTrace!);
    }
  }

  static Future<void> _seedDatabase(
    DoseyDatabase database,
    DateTime now,
  ) async {
    await database
        .into(database.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: 'prescription-1',
            name: 'Test med',
            pillType: 'tablet',
            availableDoses: const Value(1),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'schedule-1',
        label: 'Morning meds',
        prescriptionId: 'prescription-1',
        profileId: ScheduleProfile.defaultProfileId,
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
            profileId: ScheduleProfile.defaultProfileId,
            status: CarouselSlotStatus.loaded.storageValue,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
