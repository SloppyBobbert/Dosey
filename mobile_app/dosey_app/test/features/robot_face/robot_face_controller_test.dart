import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_controller.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'idle state includes the next event label when nothing urgent is active',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9),
        scheduleHour: 10,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.nextEventLabel, '10:00 · Morning meds');
      expect(state.rampProgress, 0);
      expect(state.isInAwakeWindow, isFalse);
    },
  );

  test(
    'ramp progress rises inside the configured wake-before window',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 55),
        scheduleHour: 10,
        scheduleMinute: 0,
        robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 10),
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.doseApproaching);
      expect(state.rampProgress, closeTo(0.5, 0.001));
      expect(state.isInAwakeWindow, isTrue);
    },
  );

  test(
    'wake before off keeps the face idle until the scheduled time',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 45),
        scheduleHour: 10,
        scheduleMinute: 0,
        robotFaceSettings: const RobotFaceSettings(wakeBeforeDoseMinutes: 0),
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.rampProgress, 0);
      expect(state.isInAwakeWindow, isFalse);
    },
  );

  test(
    'transitions to sleepy after the inactivity timeout when dimming is enabled',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 14,
        scheduleMinute: 0,
        clock: clock.stream,
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();

      expect(
        await fixture.controller.watchState().first,
        isA<RobotFaceState>(),
      );

      now = now.add(const Duration(minutes: 31));
      fixture.now = now;
      clock.add(now);

      final sleepyState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.sleepy,
      );

      expect(sleepyState.nextEventLabel, '14:00 · Morning meds');
    },
  );

  test(
    'shows dose ready before dispense confirmation and does not mark taken from movement alone',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        scheduleHour: 9,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final readyState = await fixture.controller.watchState().first;
      expect(readyState.mode, RobotFaceMode.doseReady);
      expect(readyState.rampProgress, 1);
      expect(readyState.isInAwakeWindow, isTrue);

      await fixture.doseLog.addEvent(
        DoseLogEvent.controllerDispenseSucceeded(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final waitingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.waitingForConfirmation,
      );

      expect(waitingState.mode, isNot(RobotFaceMode.happyConfirmed));
      expect(waitingState.statusLabel, contains('Awaiting'));
    },
  );

  test(
    'surfaces happy confirmed for the current due dose before advancing',
    () async {
      final fixture = await _RobotFaceControllerFixture.create(
        now: DateTime(2026, 7, 8, 9, 5),
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: DateTime(2026, 7, 8, 9, 5),
            label: 'Afternoon meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: fixture.currentDoseId,
          occurredAt: fixture.now.toUtc(),
        ),
      );

      final confirmedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.happyConfirmed,
      );

      expect(confirmedState.nextEventLabel, '09:00 · Morning meds');
      expect(confirmedState.statusLabel, 'Dose confirmed taken');
      expect(confirmedState.rampProgress, 1);
      expect(confirmedState.isInAwakeWindow, isTrue);
    },
  );

  test(
    'awake window keeps the face awake after a dose for the configured time',
    () async {
      final clock = StreamController<DateTime>.broadcast();
      var now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 9,
        scheduleMinute: 0,
        clock: clock.stream,
        robotFaceSettings: const RobotFaceSettings(
          stayAwakeAfterDoseMinutes: 10,
        ),
      );
      addTearDown(() async {
        await clock.close();
        await fixture.close();
      });

      await fixture.settle();

      now = DateTime(2026, 7, 8, 9, 9);
      fixture.now = now;
      clock.add(now);

      final awakeState = await fixture.controller.watchState().firstWhere(
        (state) => state.isInAwakeWindow,
      );

      expect(awakeState.mode, RobotFaceMode.doseReady);
      expect(awakeState.rampProgress, 1);

      now = DateTime(2026, 7, 8, 9, 11);
      fixture.now = now;
      clock.add(now);

      final noLongerAwakeState = await fixture.controller
          .watchState()
          .firstWhere((state) => !state.isInAwakeWindow);

      expect(noLongerAwakeState.mode, RobotFaceMode.doseReady);
      expect(noLongerAwakeState.rampProgress, 1);
    },
  );

  test(
    'does not show another profile schedule before the active profile resolves',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        emitDefaultActiveProfile: false,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-2',
            hour: 8,
            minute: 30,
            now: now,
            label: 'Wrong profile meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final state = await fixture.controller.watchState().first;

      expect(state.mode, RobotFaceMode.idle);
      expect(state.nextEventLabel, 'No reminders scheduled');
      expect(state.statusLabel, 'No active reminder');
    },
  );

  test(
    'dispense request uses the first unresolved due schedule shown on the face',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 8,
            minute: 0,
            now: now,
            label: 'Early meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      final initialState = await fixture.controller.watchState().first;
      expect(initialState.nextEventLabel, '08:00 · Early meds');

      final dispenseFuture = fixture.controller.requestDispenseForCurrentDose();

      final dispensingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.dispensing,
      );

      expect(dispensingState.nextEventLabel, '08:00 · Early meds');
      expect(fixture.controllerGateway.requestedDoseIds, <String>[
        'schedule-1:2026-07-08',
      ]);

      fixture.controllerGateway.completeDispense();
      await dispenseFuture;
    },
  );

  test(
    'dispense request rejects future reminders that are not due yet',
    () async {
      final now = DateTime(2026, 7, 8, 9);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        scheduleHour: 10,
        scheduleMinute: 0,
      );
      addTearDown(fixture.close);

      await fixture.settle();

      expect(
        fixture.controller.requestDispenseForCurrentDose(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No active dose is ready to dispense.',
          ),
        ),
      );
      expect(fixture.controllerGateway.requestedDoseIds, isEmpty);
    },
  );

  test(
    'resolved earlier due dose advances display and dispense to the next due dose',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 8,
            minute: 0,
            now: now,
            label: 'Early meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: 'schedule-1:2026-07-08',
          occurredAt: now.toUtc(),
        ),
      );

      final readyState = await fixture.controller.watchState().firstWhere(
        (state) => state.nextEventLabel == '09:00 · Current meds',
      );

      expect(readyState.mode, RobotFaceMode.doseReady);

      final dispenseFuture = fixture.controller.requestDispenseForCurrentDose();
      final dispensingState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.dispensing,
      );

      expect(dispensingState.nextEventLabel, '09:00 · Current meds');
      expect(fixture.controllerGateway.requestedDoseIds, <String>[
        'schedule-2:2026-07-08',
      ]);

      fixture.controllerGateway.completeDispense();
      await dispenseFuture;
    },
  );

  test(
    'dispense request rejects a completed current due dose when the next dose is still in the future',
    () async {
      final now = DateTime(2026, 7, 8, 9, 5);
      final fixture = await _RobotFaceControllerFixture.create(
        now: now,
        schedules: <ReminderSchedule>[
          _schedule(
            id: 'schedule-1',
            profileId: 'profile-1',
            hour: 9,
            minute: 0,
            now: now,
            label: 'Current meds',
          ),
          _schedule(
            id: 'schedule-2',
            profileId: 'profile-1',
            hour: 13,
            minute: 0,
            now: now,
            label: 'Later meds',
          ),
        ],
      );
      addTearDown(fixture.close);

      await fixture.settle();

      await fixture.doseLog.addEvent(
        DoseLogEvent.doseTakenConfirmed(
          doseId: 'schedule-1:2026-07-08',
          occurredAt: now.toUtc(),
        ),
      );

      final confirmedState = await fixture.controller.watchState().firstWhere(
        (state) => state.mode == RobotFaceMode.happyConfirmed,
      );

      expect(confirmedState.nextEventLabel, '09:00 · Current meds');

      expect(
        fixture.controller.requestDispenseForCurrentDose(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No active dose is ready to dispense.',
          ),
        ),
      );
      expect(fixture.controllerGateway.requestedDoseIds, isEmpty);
    },
  );

  test('shows missed state for a terminal missed dose event', () async {
    final fixture = await _RobotFaceControllerFixture.create(
      now: DateTime(2026, 7, 8, 9, 5),
      scheduleHour: 9,
      scheduleMinute: 0,
    );
    addTearDown(fixture.close);

    await fixture.settle();

    await fixture.doseLog.addEvent(
      DoseLogEvent.doseMissed(
        doseId: fixture.currentDoseId,
        occurredAt: fixture.now.toUtc(),
      ),
    );

    final missedState = await fixture.controller.watchState().firstWhere(
      (state) => state.mode == RobotFaceMode.missed,
    );

    expect(missedState.nextEventLabel, '09:00 · Morning meds');
    expect(missedState.statusLabel, 'Dose missed');
  });
}

ReminderSchedule _schedule({
  required String id,
  required String profileId,
  required int hour,
  required int minute,
  required DateTime now,
  String label = 'Morning meds',
}) {
  return ReminderSchedule(
    id: id,
    label: label,
    profileId: profileId,
    hour: hour,
    minute: minute,
    isEnabled: true,
    createdAt: now.toUtc(),
    updatedAt: now.toUtc(),
  );
}

class _RobotFaceControllerFixture {
  _RobotFaceControllerFixture({
    required this.database,
    required this.doseLog,
    required this.controller,
    required this.controllerGateway,
    required this.currentDoseId,
    required this.nowGetter,
    required this._setNow,
  });

  final DoseyDatabase database;
  final _FakeDoseLogRepository doseLog;
  final RobotFaceController controller;
  final _FakeControllerGateway controllerGateway;
  final String currentDoseId;
  final DateTime Function() nowGetter;
  final void Function(DateTime value) _setNow;

  DateTime get now => nowGetter();

  static Future<_RobotFaceControllerFixture> create({
    required DateTime now,
    int scheduleHour = 10,
    int scheduleMinute = 0,
    List<ReminderSchedule>? schedules,
    RobotFaceSettings robotFaceSettings = const RobotFaceSettings(),
    ScheduleProfile? activeProfile,
    bool emitDefaultActiveProfile = true,
    Stream<DateTime>? clock,
  }) async {
    final database = DoseyDatabase.inMemory();
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    final robotFaceSettingsRepository = RobotFaceSettingsRepository(database);
    final profiles = _FakeScheduleProfileRepository();
    final reminders = _FakeReminderRepository();
    final doseLog = _FakeDoseLogRepository();
    final controllerGateway = _FakeControllerGateway(
      const ControllerSnapshot.connected(),
    );
    var currentNow = now;

    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await robotFaceSettingsRepository.saveSettings(robotFaceSettings);
    if (activeProfile != null || emitDefaultActiveProfile) {
      profiles.emit(
        activeProfile ??
            ScheduleProfile(
              id: 'profile-1',
              name: 'Default',
              isActive: true,
              createdAt: now.toUtc(),
              updatedAt: now.toUtc(),
            ),
      );
    }
    reminders.emit(
      schedules ??
          <ReminderSchedule>[
            _schedule(
              id: 'schedule-1',
              profileId: 'profile-1',
              hour: scheduleHour,
              minute: scheduleMinute,
              now: now,
            ),
          ],
    );

    final robotFaceController = RobotFaceController(
      settings: settings,
      robotFaceSettings: robotFaceSettingsRepository,
      controller: controllerGateway,
      scheduleProfiles: profiles,
      reminders: reminders,
      doseLog: doseLog,
      clock: clock,
      now: () => currentNow,
    );

    return _RobotFaceControllerFixture(
      database: database,
      doseLog: doseLog,
      controller: robotFaceController,
      controllerGateway: controllerGateway,
      currentDoseId: 'schedule-1:2026-07-08',
      nowGetter: () => currentNow,
      setNow: (value) {
        currentNow = value;
      },
    );
  }

  set now(DateTime value) => _setNow(value);

  Future<void> settle() => pumpEventQueue();

  Future<void> close() async {
    await controller.close();
    await database.close();
  }
}

class _FakeControllerGateway implements ControllerGateway {
  _FakeControllerGateway(this._snapshot);

  final ControllerSnapshot _snapshot;
  final List<String> requestedDoseIds = <String>[];
  Completer<void>? _dispenseCompleter;

  @override
  Future<void> cancelActiveCommand() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> requestDispense({required String doseId}) async {
    requestedDoseIds.add(doseId);
    final completer = Completer<void>();
    _dispenseCompleter = completer;
    await completer.future;
  }

  void completeDispense() {
    _dispenseCompleter?.complete();
    _dispenseCompleter = null;
  }

  @override
  Stream<ControllerSnapshot> watchController() => Stream.value(_snapshot);
}

class _FakeDoseLogRepository implements DoseLogRepository {
  final _controller = StreamController<List<DoseLogEvent>>.broadcast();
  final List<DoseLogEvent> _events = <DoseLogEvent>[];

  @override
  Future<void> addEvent(DoseLogEvent event) async {
    _events.insert(0, event);
    _controller.add(List<DoseLogEvent>.unmodifiable(_events));
  }

  @override
  Stream<List<DoseLogEvent>> watchEvents() async* {
    yield List<DoseLogEvent>.unmodifiable(_events);
    yield* _controller.stream;
  }
}

class _FakeReminderRepository implements ReminderRepository {
  final _controller = StreamController<List<ReminderSchedule>>.broadcast();
  List<ReminderSchedule> _schedules = const <ReminderSchedule>[];

  void emit(List<ReminderSchedule> schedules) {
    _schedules = List<ReminderSchedule>.unmodifiable(schedules);
  }

  @override
  Future<void> deleteSchedule(String id) async {}

  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {}

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) async* {
    yield _filtered(profileId);
    yield* _controller.stream.map((_) => _filtered(profileId));
  }

  List<ReminderSchedule> _filtered(String? profileId) {
    if (profileId == null) {
      return _schedules;
    }
    return _schedules
        .where((schedule) => schedule.profileId == profileId)
        .toList();
  }
}

class _FakeScheduleProfileRepository implements ScheduleProfileRepository {
  final _controller = StreamController<ScheduleProfile?>.broadcast();
  ScheduleProfile? _profile;

  void emit(ScheduleProfile? profile) {
    _profile = profile;
  }

  @override
  Future<void> setActiveProfile(String id) async {}

  @override
  Future<void> upsertProfile(ScheduleProfile profile) async {}

  @override
  Stream<ScheduleProfile?> watchActiveProfile() async* {
    yield _profile;
    yield* _controller.stream;
  }

  @override
  Stream<List<ScheduleProfile>> watchProfiles() async* {
    yield _profile == null
        ? const <ScheduleProfile>[]
        : <ScheduleProfile>[_profile!];
  }
}
