import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/carousel/carousel_dispense_coordinator.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

class ControllerReliabilityFixture {
  ControllerReliabilityFixture._({
    required this.database,
    required this.simulator,
    required this.supervisor,
    required this.coordinator,
    required this.bench,
    required this.commandRepository,
    required this.healthRepository,
    required this.doseLog,
    required this.robotFace,
    required this.scheduler,
    required this.dispenseGate,
    required this._availability,
    required this._controllerSubscription,
  });

  static const doseId = 'schedule-1:2026-07-10';

  final DoseyDatabase database;
  final SimulatedControllerGateway simulator;
  final ControllerHealthSupervisor supervisor;
  final CarouselDispenseCoordinator coordinator;
  final ControllerBenchService bench;
  final LocalControllerCommandRepository commandRepository;
  final LocalControllerHealthEventRepository healthRepository;
  final DriftDoseLogRepository doseLog;
  final RobotFaceController robotFace;
  final ManualControllerHealthScheduler scheduler;
  final SimulatorDelayGate dispenseGate;
  final StreamController<BleAvailabilitySnapshot> _availability;
  final StreamSubscription<ControllerSnapshot> _controllerSubscription;

  ControllerSnapshot latestController = const ControllerSnapshot.disconnected();

  DateTime get now => scheduler.now;

  static Future<ControllerReliabilityFixture> create({
    bool gateDispenseStages = false,
  }) async {
    final database = DoseyDatabase.inMemory();
    final scheduler = ManualControllerHealthScheduler(
      DateTime.utc(2026, 7, 10, 9, 5),
    );
    final dispenseGate = SimulatorDelayGate();
    final simulator = SimulatedControllerGateway(
      canHostRobot: () => true,
      delay: gateDispenseStages ? dispenseGate.call : (_) async {},
      benchDelay: (_) async {},
    );
    final availability = StreamController<BleAvailabilitySnapshot>.broadcast();
    var healthId = 0;
    final healthRepository = LocalControllerHealthEventRepository(
      database,
      idGenerator: (type, occurredAt) => 'health:${healthId++}',
    );
    final supervisor = ControllerHealthSupervisor(
      delegate: simulator,
      availability: availability.stream,
      eventSink: healthRepository,
      now: () => scheduler.now,
      timerFactory: scheduler.schedule,
      heartbeatInterval: const Duration(seconds: 10),
      reconnectBackoff: const [Duration(seconds: 2), Duration(seconds: 5)],
    );
    final commandRepository = LocalControllerCommandRepository(
      database,
      sessionIdGenerator: (type, now) =>
          '${type.name}:${now.microsecondsSinceEpoch}:${healthId++}',
    );
    final doseLog = DriftDoseLogRepository(database);
    final slots = LocalCarouselSlotRepository(database);
    final lifecycle = ControllerLifecycleService(
      controller: supervisor,
      commandRepository: commandRepository,
      doseLog: doseLog,
      carouselSlots: slots,
      now: () => scheduler.now,
    );
    final coordinator = CarouselDispenseCoordinator(
      controllerLifecycle: lifecycle,
    );
    final bench = ControllerBenchService(
      controller: supervisor,
      lifecycle: lifecycle,
      commandRepository: commandRepository,
      now: () => scheduler.now,
    );

    await _seedDatabase(database, scheduler.now);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    final robotFace = RobotFaceController(
      settings: settings,
      robotFaceSettings: RobotFaceSettingsRepository(database),
      controller: supervisor,
      controllerLifecycle: lifecycle,
      scheduleProfiles: LocalScheduleProfileRepository(database),
      reminders: LocalReminderRepository(database),
      doseLog: doseLog,
      carouselSlots: slots,
      now: () => scheduler.now,
    );

    late final ControllerReliabilityFixture fixture;
    final controllerSubscription = supervisor.watchController().listen((value) {
      fixture.latestController = value;
    });
    fixture = ControllerReliabilityFixture._(
      database: database,
      simulator: simulator,
      supervisor: supervisor,
      coordinator: coordinator,
      bench: bench,
      commandRepository: commandRepository,
      healthRepository: healthRepository,
      doseLog: doseLog,
      robotFace: robotFace,
      scheduler: scheduler,
      dispenseGate: dispenseGate,
      availability: availability,
      controllerSubscription: controllerSubscription,
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
    return coordinator.dispenseLoadedSlot(
      slotId: 'slot-1',
      doseId: doseId,
      scheduleId: 'schedule-1',
    );
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

  Future<RobotFaceState> robotState() => robotFace.watchState().first;

  Future<RobotFaceState> robotStateWithMode(RobotFaceMode mode) {
    return robotFace
        .watchState()
        .firstWhere((state) => state.mode == mode)
        .timeout(const Duration(seconds: 2));
  }

  Future<void> recordVisible() async {
    await elapse(const Duration(seconds: 1));
    await doseLog.addEvent(
      DoseLogEvent.doseVisibleConfirmed(doseId: doseId, occurredAt: now),
    );
  }

  Future<void> recordTaken() async {
    await elapse(const Duration(seconds: 1));
    await doseLog.addEvent(
      DoseLogEvent.doseTakenConfirmed(doseId: doseId, occurredAt: now),
    );
  }

  Future<List<ControllerHealthEventType>> healthEventTypes() async {
    final events = await healthRepository.watchRecentEvents(limit: 100).first;
    return events.reversed.map((event) => event.type).toList();
  }

  Future<void> elapse(Duration duration) => scheduler.elapse(duration);

  Future<void> releaseDispenseStagesUntilComplete(Future<void> dispense) async {
    final completed = Completer<void>();
    dispense.then(
      (_) => completed.complete(),
      onError: (Object _, StackTrace _) => completed.complete(),
    );
    while (!completed.isCompleted) {
      await Future.any([dispenseGate.waitUntilBlocked(), completed.future]);
      if (completed.isCompleted) break;
      dispenseGate.releaseNext();
      await settle();
    }
  }

  Future<void> settle() => pumpEventQueue();

  Future<void> close() async {
    await robotFace.close();
    await _controllerSubscription.cancel();
    await supervisor.close();
    await _availability.close();
    await database.close();
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

class SimulatorDelayGate {
  final List<Completer<void>> _pending = [];
  Completer<void> _blocked = Completer<void>();

  Future<void> call(Duration _) {
    final delay = Completer<void>();
    _pending.add(delay);
    if (!_blocked.isCompleted) _blocked.complete();
    return delay.future;
  }

  Future<void> waitUntilBlocked() => _blocked.future;

  void releaseNext() {
    if (_pending.isEmpty) {
      throw StateError('No simulator delay is blocked.');
    }
    _pending.removeAt(0).complete();
    _blocked = Completer<void>();
  }
}

class ManualControllerHealthScheduler {
  ManualControllerHealthScheduler(this._start);

  final DateTime _start;
  final List<_ManualControllerHealthTimer> _timers = [];
  Duration _elapsed = Duration.zero;

  DateTime get now => _start.add(_elapsed);

  int get pendingTimerCount =>
      _timers.where((timer) => !timer.isCancelled).length;

  ControllerHealthTimer schedule(Duration delay, void Function() callback) {
    final timer = _ManualControllerHealthTimer(_elapsed + delay, callback);
    _timers.add(timer);
    return timer;
  }

  Future<void> elapse(Duration duration) async {
    _elapsed += duration;
    while (true) {
      final due = _timers
          .where((timer) => !timer.isCancelled && timer.deadline <= _elapsed)
          .toList();
      if (due.isEmpty) break;
      for (final timer in due) {
        timer.fire();
      }
      await pumpEventQueue();
    }
    await pumpEventQueue();
  }
}

class _ManualControllerHealthTimer implements ControllerHealthTimer {
  _ManualControllerHealthTimer(this.deadline, this._callback);

  final Duration deadline;
  final void Function() _callback;
  bool isCancelled = false;

  void fire() {
    if (isCancelled) return;
    isCancelled = true;
    _callback();
  }

  @override
  void cancel() => isCancelled = true;
}
