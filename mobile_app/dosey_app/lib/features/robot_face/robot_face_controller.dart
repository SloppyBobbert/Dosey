import 'dart:async';

import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';

class RobotFaceController {
  RobotFaceController({
    required this._settings,
    required this._robotFaceSettings,
    required this._controller,
    required this._scheduleProfiles,
    required this._reminders,
    required this._doseLog,
    Stream<DateTime>? clock,
    DateTime Function()? now,
    this.sleepyAfter = const Duration(minutes: 30),
    this.doseApproachingWindow = const Duration(minutes: 30),
  }) : _now = now ?? DateTime.now {
    _lastInteractionAt = _now();
    _subscriptions = <StreamSubscription<Object?>>[
      _settings.watchDeviceRole().listen((value) {
        _role = value;
        _emit();
      }),
      _robotFaceSettings.watchSettings().listen((value) {
        _robotSettings = value;
        _emit();
      }),
      _controller.watchController().listen((value) {
        _controllerSnapshot = value;
        _emit();
      }),
      _scheduleProfiles.watchActiveProfile().listen((value) {
        _activeProfile = value;
        _emit();
      }),
      _reminders.watchSchedules().listen((value) {
        _schedules = value;
        _emit();
      }),
      _doseLog.watchEvents().listen((value) {
        _events = value;
        _emit();
      }),
    ];
    final tickStream = clock;
    if (tickStream != null) {
      _subscriptions.add(
        tickStream.listen((value) {
          _currentTime = value;
          _emit();
        }),
      );
    }
  }

  final LocalAppSettingsRepository _settings;
  final RobotFaceSettingsRepository _robotFaceSettings;
  final ControllerGateway _controller;
  final ScheduleProfileRepository _scheduleProfiles;
  final ReminderRepository _reminders;
  final DoseLogRepository _doseLog;
  final DateTime Function() _now;
  final Duration sleepyAfter;
  final Duration doseApproachingWindow;

  final _stateController = StreamController<RobotFaceState>.broadcast();
  late final List<StreamSubscription<Object?>> _subscriptions;

  AppDeviceRole? _role;
  RobotFaceSettings _robotSettings = const RobotFaceSettings();
  ControllerSnapshot _controllerSnapshot =
      const ControllerSnapshot.disconnected();
  ScheduleProfile? _activeProfile;
  List<ReminderSchedule> _schedules = const <ReminderSchedule>[];
  List<DoseLogEvent> _events = const <DoseLogEvent>[];
  String? _dispensingDoseId;
  late DateTime _lastInteractionAt;
  DateTime? _currentTime;
  RobotFaceState? _latestState;

  Stream<RobotFaceState> watchState() async* {
    final state = _latestState ?? _computeState();
    yield state;
    yield* _stateController.stream;
  }

  void recordInteraction() {
    _lastInteractionAt = _current();
    _emit();
  }

  Future<void> requestDispenseForCurrentDose() async {
    final now = _current();
    final nextDose = _dueSchedule(now);
    if (nextDose == null) {
      throw StateError('No active dose is ready to dispense.');
    }
    final doseId = TodayNextDoseHelper.doseIdForDate(nextDose.id, now);
    _dispensingDoseId = doseId;
    _emit();
    try {
      await _controller.requestDispense(doseId: doseId);
    } finally {
      _dispensingDoseId = null;
      _lastInteractionAt = _current();
      _emit();
    }
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _stateController.close();
  }

  void _emit() {
    final nextState = _computeState();
    if (_latestState == nextState) {
      return;
    }
    _latestState = nextState;
    _stateController.add(nextState);
  }

  RobotFaceState _computeState() {
    final role = _role;
    final now = _current();
    final nextSchedule = _displaySchedule(now);
    final choreography = _choreographyFor(nextSchedule, now);
    final nextEventLabel = nextSchedule == null
        ? 'No reminders scheduled'
        : '${nextSchedule.timeLabel} · ${nextSchedule.label}';
    final baseState = RobotFaceState(
      mode: _modeFor(role, nextSchedule, now),
      nextEventLabel: nextEventLabel,
      isFlipped: _robotSettings.isFlipped,
      isLandscapeOnly: role?.canHostRobot ?? false,
      rampProgress: choreography.rampProgress,
      isInAwakeWindow: choreography.isInAwakeWindow,
      statusLabel: _statusFor(role, nextSchedule, now),
    );
    if (baseState.mode == RobotFaceMode.idle &&
        !baseState.isInAwakeWindow &&
        _robotSettings.dimAfterInactivity &&
        now.difference(_lastInteractionAt) >= sleepyAfter) {
      return RobotFaceState(
        mode: RobotFaceMode.sleepy,
        nextEventLabel: baseState.nextEventLabel,
        isFlipped: baseState.isFlipped,
        isLandscapeOnly: baseState.isLandscapeOnly,
        rampProgress: baseState.rampProgress,
        isInAwakeWindow: baseState.isInAwakeWindow,
        statusLabel: baseState.statusLabel,
      );
    }
    return baseState;
  }

  RobotFaceMode _modeFor(
    AppDeviceRole? role,
    ReminderSchedule? nextSchedule,
    DateTime now,
  ) {
    if (role == null || !role.canHostRobot) {
      return RobotFaceMode.offline;
    }
    if (_controllerSnapshot.connectionState ==
        ControllerConnectionState.error) {
      return RobotFaceMode.error;
    }
    if (_controllerSnapshot.connectionState !=
        ControllerConnectionState.connected) {
      return RobotFaceMode.offline;
    }
    if (nextSchedule == null) {
      return RobotFaceMode.idle;
    }
    final doseId = TodayNextDoseHelper.doseIdForDate(nextSchedule.id, now);
    final latestEvent = TodayNextDoseHelper.latestEventForDose(_events, doseId);
    if (_dispensingDoseId == doseId) {
      return RobotFaceMode.dispensing;
    }
    if (latestEvent != null) {
      switch (latestEvent.kind) {
        case DoseLogEventKind.controllerDispenseSucceeded:
        case DoseLogEventKind.doseVisibleConfirmed:
        case DoseLogEventKind.doseSnoozed:
        case DoseLogEventKind.caregiverHelpRequested:
          return RobotFaceMode.waitingForConfirmation;
        case DoseLogEventKind.doseTakenConfirmed:
        case DoseLogEventKind.doseAlreadyTaken:
        case DoseLogEventKind.doseTakenEarly:
        case DoseLogEventKind.doseTakenLate:
        case DoseLogEventKind.doseSkipped:
          return RobotFaceMode.happyConfirmed;
        case DoseLogEventKind.doseMissed:
          return RobotFaceMode.missed;
        case DoseLogEventKind.error:
          return RobotFaceMode.error;
      }
    }
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      nextSchedule.hour,
      nextSchedule.minute,
    );
    if (!scheduledTime.isAfter(now)) {
      return RobotFaceMode.doseReady;
    }
    if (scheduledTime.difference(now) <= _wakeBeforeWindow) {
      return RobotFaceMode.doseApproaching;
    }
    return RobotFaceMode.idle;
  }

  String? _statusFor(
    AppDeviceRole? role,
    ReminderSchedule? nextSchedule,
    DateTime now,
  ) {
    if (role == null || !role.canHostRobot) {
      return 'Robot Face is only available in Robot Mode';
    }
    if (_controllerSnapshot.connectionState !=
        ControllerConnectionState.connected) {
      return _controllerSnapshot.statusLabel;
    }
    if (nextSchedule == null) {
      return 'No active reminder';
    }
    final doseId = TodayNextDoseHelper.doseIdForDate(nextSchedule.id, now);
    final latestEvent = TodayNextDoseHelper.latestEventForDose(_events, doseId);
    if (_dispensingDoseId == doseId) {
      return 'Dispensing in progress';
    }
    if (latestEvent == null) {
      return null;
    }
    return switch (latestEvent.kind) {
      DoseLogEventKind.controllerDispenseSucceeded =>
        'Awaiting dose confirmation',
      DoseLogEventKind.doseVisibleConfirmed =>
        'Dose visible, awaiting confirmation',
      DoseLogEventKind.doseSnoozed => 'Dose snoozed',
      DoseLogEventKind.caregiverHelpRequested => 'Caregiver help requested',
      DoseLogEventKind.doseTakenConfirmed => 'Dose confirmed taken',
      DoseLogEventKind.doseAlreadyTaken => 'Dose already taken',
      DoseLogEventKind.doseTakenEarly => 'Dose taken early',
      DoseLogEventKind.doseTakenLate => 'Dose taken late',
      DoseLogEventKind.doseSkipped => 'Dose skipped',
      DoseLogEventKind.doseMissed => 'Dose missed',
      DoseLogEventKind.error => 'Dose error logged',
    };
  }

  DateTime _current() => _currentTime ?? _now();

  ReminderSchedule? _displaySchedule(DateTime now) {
    return TodayNextDoseHelper.currentOrLatestDueSchedule(
      _activeSchedules,
      _events,
      now: now,
    );
  }

  ReminderSchedule? _dueSchedule(DateTime now) {
    final schedule = _displaySchedule(now);
    if (schedule == null) {
      return null;
    }

    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );

    return scheduledTime.isAfter(now) ? null : schedule;
  }

  _RobotFaceChoreography _choreographyFor(
    ReminderSchedule? schedule,
    DateTime now,
  ) {
    if (schedule == null) {
      return const _RobotFaceChoreography(
        rampProgress: 0,
        isInAwakeWindow: false,
      );
    }

    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );
    final wakeBeforeWindow = Duration(
      minutes: _robotSettings.wakeBeforeDoseMinutes,
    );
    final stayAwakeWindow = Duration(
      minutes: _robotSettings.stayAwakeAfterDoseMinutes,
    );
    final wakeWindowStart = scheduledTime.subtract(wakeBeforeWindow);
    final wakeWindowEnd = scheduledTime.add(stayAwakeWindow);

    final rampProgress = switch (now.compareTo(scheduledTime)) {
      >= 0 => 1.0,
      _ when wakeBeforeWindow == Duration.zero => 0.0,
      _ when now.isBefore(wakeWindowStart) => 0.0,
      _ =>
        now
                .difference(wakeWindowStart)
                .inMilliseconds
                .clamp(0, wakeBeforeWindow.inMilliseconds) /
            wakeBeforeWindow.inMilliseconds,
    };

    return _RobotFaceChoreography(
      rampProgress: rampProgress.clamp(0.0, 1.0),
      isInAwakeWindow:
          !now.isBefore(wakeWindowStart) && !now.isAfter(wakeWindowEnd),
    );
  }

  List<ReminderSchedule> get _activeSchedules {
    final activeProfile = _activeProfile;
    if (activeProfile == null) {
      return const <ReminderSchedule>[];
    }
    return _schedules
        .where((schedule) => schedule.profileId == activeProfile.id)
        .toList(growable: false);
  }

  Duration get _wakeBeforeWindow {
    final settingsWindow = Duration(
      minutes: _robotSettings.wakeBeforeDoseMinutes,
    );
    return settingsWindow > Duration.zero
        ? settingsWindow
        : doseApproachingWindow;
  }
}

class _RobotFaceChoreography {
  const _RobotFaceChoreography({
    required this.rampProgress,
    required this.isInAwakeWindow,
  });

  final double rampProgress;
  final bool isInAwakeWindow;
}
