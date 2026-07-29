import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/demo/demo_data_repository.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/display/system_ui_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

abstract class SimulatorScenarioHarness {
  SimulatorScenarioHarness._({
    required this.database,
    required this.clock,
    required this.reconciliation,
    required this.notificationTaps,
  });

  static final seedTime = DateTime.utc(2040, 1, 2, 8);

  final DoseyDatabase database;
  final ControllableAppClock clock;
  final MissedDoseReconciliationService reconciliation;
  final ReminderNotificationTapController notificationTaps;

  String get doseId {
    final date = seedTime;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${DemoDataRepository.scheduleId}:${date.year}-$month-$day';
  }

  Future<List<DoseLogEvent>> doseEvents() async {
    final rows = await (database.select(
      database.doseLogEvents,
    )..orderBy([(event) => OrderingTerm.desc(event.occurredAt)])).get();
    return rows
        .map(
          (row) => DoseLogEvent(
            kind: DoseLogEventKind.values.byName(row.kind),
            doseId: row.doseId,
            occurredAt: row.occurredAt.toUtc(),
            marksDoseTaken: row.marksDoseTaken,
          ),
        )
        .toList();
  }

  Future<List<ControllerCommandSessionRow>> commandSessions() async =>
      (database.select(database.controllerCommandSessions)..orderBy([
            (session) => OrderingTerm.asc(session.createdAt),
            (session) => OrderingTerm.asc(session.id),
          ]))
          .get();

  Future<List<ControllerCommandEventRow>> commandEvents() async =>
      (database.select(database.controllerCommandEvents)..orderBy([
            (event) => OrderingTerm.asc(event.sessionId),
            (event) => OrderingTerm.asc(event.sequence),
          ]))
          .get();

  Future<String> slotStatus() async =>
      (await database.select(database.carouselLoadSlotSnapshots).getSingle())
          .status;

  Future<({int available, int loaded, int used, int review})>
  inventory() async {
    final row = await database.select(database.prescriptions).getSingle();
    return (
      available: row.availableDoses,
      loaded: row.loadedDoses,
      used: row.usedDoses,
      review: row.reviewDoses,
    );
  }

  Future<ScenarioSafetySnapshot> snapshot() async => ScenarioSafetySnapshot(
    doseEvents: await doseEvents(),
    sessions: await commandSessions(),
    commandEvents: await commandEvents(),
    inventory: await inventory(),
  );

  Future<void> close();
}

class StandaloneSimulatorScenarioHarness extends SimulatorScenarioHarness {
  StandaloneSimulatorScenarioHarness._({
    required super.database,
    required super.clock,
    required super.reconciliation,
    required super.notificationTaps,
    required this.simulator,
    required this.service,
    required this.commandRepository,
  }) : super._();

  final SimulatedControllerGateway simulator;
  final DemoScenarioService service;
  final LocalControllerCommandRepository commandRepository;

  static Future<StandaloneSimulatorScenarioHarness> create() async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(SimulatorScenarioHarness.seedTime);
    final stageGate = DemoStageGate();
    final simulator = SimulatedControllerGateway(
      canHostRobot: () => true,
      delay: stageGate.wait,
    );
    final ids = DemoCommandSessionIdGenerator();
    final commandRepository = LocalControllerCommandRepository(
      database,
      sessionIdGenerator: ids.call,
    );
    final doseLog = DriftDoseLogRepository(database);
    final slots = LocalCarouselSlotRepository(database);
    final guidedLoads = LocalGuidedCarouselLoadRepository(database);
    final lifecycle = ControllerLifecycleService(
      controller: simulator,
      commandRepository: commandRepository,
      doseLog: doseLog,
      carouselSlots: slots,
      guidedCarouselLoads: guidedLoads,
      database: database,
      now: clock.now,
    );
    final bench = ControllerBenchService(
      controller: simulator,
      lifecycle: lifecycle,
      commandRepository: commandRepository,
      now: clock.now,
    );
    final doseActions = DoseActionService(
      database: database,
      carouselSlots: slots,
      guidedCarouselLoads: guidedLoads,
      prescriptions: LocalPrescriptionRepository(database),
      doseLog: doseLog,
    );
    final reconciliation = _reconciliation(database, clock);
    final harness = StandaloneSimulatorScenarioHarness._(
      database: database,
      clock: clock,
      reconciliation: reconciliation,
      notificationTaps: ReminderNotificationTapController(),
      simulator: simulator,
      commandRepository: commandRepository,
      service: DemoScenarioService(
        data: DemoDataRepository(
          database,
          seedTime: SimulatorScenarioHarness.seedTime,
          deviceRole: AppDeviceRole.androidRobot,
        ),
        database: database,
        clock: clock,
        controller: simulator,
        stageGate: stageGate,
        idGenerator: ids,
        lifecycle: lifecycle,
        bench: bench,
        commandRepository: commandRepository,
        doseActions: doseActions,
        reconciliation: reconciliation,
        playbackDelay: (_) async {},
      ),
    );
    await DemoDataRepository(
      database,
      seedTime: SimulatorScenarioHarness.seedTime,
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();
    await simulator.connect();
    return harness;
  }

  Future<void> next({int count = 1}) async {
    for (var index = 0; index < count; index++) {
      await service.next();
    }
  }

  Future<void> select(DemoScenarioId id) => service.select(id);

  Future<int> commandEventCount(ControllerCommandEventType type) async {
    final events = await commandEvents();
    return events.where((event) => event.eventType == type.name).length;
  }

  @override
  Future<void> close() async {
    await service.close();
    notificationTaps.dispose();
    await simulator.close();
    await clock.close();
    await database.close();
  }
}

class ShellSimulatorScenarioHarness extends SimulatorScenarioHarness {
  ShellSimulatorScenarioHarness._({
    required super.database,
    required super.clock,
    required super.reconciliation,
    required super.notificationTaps,
    required this.simulator,
  }) : super._();

  final SimulatedControllerGateway simulator;

  static Future<ShellSimulatorScenarioHarness> create() async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(SimulatorScenarioHarness.seedTime);
    final simulator = _ShellTestSimulatedControllerGateway();
    final harness = ShellSimulatorScenarioHarness._(
      database: database,
      clock: clock,
      reconciliation: _reconciliation(database, clock),
      notificationTaps: ReminderNotificationTapController(),
      simulator: simulator,
    );
    await DemoDataRepository(
      database,
      seedTime: SimulatorScenarioHarness.seedTime,
      deviceRole: AppDeviceRole.androidRobot,
    ).resetAndSeed();
    await simulator.connect();
    return harness;
  }

  Widget buildShell({bool startOnController = false}) {
    return DoseyAppScope(
      database: database,
      appClock: clock,
      buildProfile: AppBuildProfile.robot,
      controllerGateway: simulator,
      notificationTapController: notificationTaps,
      missedDoseReconciliationService: reconciliation,
      screenAwakeGateway: const _HarnessScreenAwakeGateway(),
      systemUiGateway: const _HarnessSystemUiGateway(),
      child: MaterialApp(
        home: DoseyShell(startOnController: startOnController),
      ),
    );
  }

  DemoScenarioService demoScenarios(BuildContext context) =>
      DoseyAppScope.of(context).demoScenarios!;

  @override
  Future<void> close() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await attempt(simulator.close);
    await attempt(() async => notificationTaps.dispose());
    await attempt(clock.close);
    await attempt(database.close);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

class _ShellTestSimulatedControllerGateway extends SimulatedControllerGateway {
  _ShellTestSimulatedControllerGateway() : super(canHostRobot: () => true);

  Future<void>? _closeFuture;

  @override
  Future<void> close() => _closeFuture ??= super.close();
}

MissedDoseReconciliationService _reconciliation(
  DoseyDatabase database,
  ControllableAppClock clock,
) {
  final doseLog = DriftDoseLogRepository(database);
  return MissedDoseReconciliationService(
    reminders: LocalReminderRepository(database),
    doseLog: doseLog,
    carouselSlots: LocalCarouselSlotRepository(database),
    database: database,
    now: clock.now,
  );
}

class ScenarioSafetySnapshot {
  const ScenarioSafetySnapshot({
    required this.doseEvents,
    required this.sessions,
    required this.commandEvents,
    required this.inventory,
  });

  final List<DoseLogEvent> doseEvents;
  final List<ControllerCommandSessionRow> sessions;
  final List<ControllerCommandEventRow> commandEvents;
  final ({int available, int loaded, int used, int review}) inventory;

  bool sameAs(ScenarioSafetySnapshot other) =>
      inventory == other.inventory &&
      _sameList(doseEvents, other.doseEvents, _sameDoseEvent) &&
      _sameList(sessions, other.sessions, _sameSession) &&
      _sameList(commandEvents, other.commandEvents, _sameCommandEvent);

  static bool _sameList<T>(
    List<T> first,
    List<T> second,
    bool Function(T first, T second) equals,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (!equals(first[index], second[index])) return false;
    }
    return true;
  }

  static bool _sameDoseEvent(DoseLogEvent first, DoseLogEvent second) =>
      first.kind == second.kind &&
      first.doseId == second.doseId &&
      first.occurredAt == second.occurredAt &&
      first.marksDoseTaken == second.marksDoseTaken;

  static bool _sameSession(
    ControllerCommandSessionRow first,
    ControllerCommandSessionRow second,
  ) =>
      first.id == second.id &&
      first.commandType == second.commandType &&
      first.doseId == second.doseId &&
      first.scheduleId == second.scheduleId &&
      first.slotId == second.slotId &&
      first.state == second.state &&
      first.failureReason == second.failureReason &&
      first.createdAt == second.createdAt &&
      first.acceptedAt == second.acceptedAt &&
      first.resolvedAt == second.resolvedAt &&
      first.updatedAt == second.updatedAt;

  static bool _sameCommandEvent(
    ControllerCommandEventRow first,
    ControllerCommandEventRow second,
  ) =>
      first.id == second.id &&
      first.sessionId == second.sessionId &&
      first.sequence == second.sequence &&
      first.eventType == second.eventType &&
      first.occurredAt == second.occurredAt &&
      first.details == second.details;
}

class _HarnessScreenAwakeGateway implements ScreenAwakeGateway {
  const _HarnessScreenAwakeGateway();

  @override
  Future<void> setKeepScreenAwake(bool enabled) async {}

  @override
  Future<void> wakeScreen() async {}
}

class _HarnessSystemUiGateway implements SystemUiGateway {
  const _HarnessSystemUiGateway();

  @override
  Future<void> enterRobotFace() async {}

  @override
  Future<void> restoreAppUi() async {}
}
