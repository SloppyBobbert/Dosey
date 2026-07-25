import 'dart:async';

import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'dart:convert';

import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';

class RobotFaceController {
  RobotFaceController({
    required this._settings,
    required this._robotFaceSettings,
    required this._controller,
    required this._controllerLifecycle,
    required this._scheduleProfiles,
    required this._reminders,
    required this._doseLog,
    this.carouselSlots,
    Stream<List<MedicationShortageAlertRow>>? shortageAlerts,
    Stream<ConnectivityState>? connectivity,
    Stream<DateTime>? clock,
    DateTime Function()? now,
    this.sleepyAfter = const Duration(minutes: 30),
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
    if (shortageAlerts != null) {
      _subscriptions.add(
        shortageAlerts.listen((value) {
          _shortageAlerts = value;
          _emit();
        }),
      );
    }
    if (connectivity != null) {
      _subscriptions.add(
        connectivity.listen((value) {
          _connectivityState = value;
          _emit();
        }),
      );
    }
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
  final ControllerLifecycleService _controllerLifecycle;
  final ScheduleProfileRepository _scheduleProfiles;
  final ReminderRepository _reminders;
  final DoseLogRepository _doseLog;
  final CarouselSlotRepository? carouselSlots;
  final DateTime Function() _now;
  final Duration sleepyAfter;

  final _stateController = StreamController<RobotFaceState>.broadcast();
  late final List<StreamSubscription<Object?>> _subscriptions;

  AppDeviceRole? _role;
  RobotFaceSettings _robotSettings = const RobotFaceSettings();
  ControllerSnapshot _controllerSnapshot =
      const ControllerSnapshot.disconnected();
  ScheduleProfile? _activeProfile;
  List<ReminderSchedule> _schedules = const <ReminderSchedule>[];
  List<DoseLogEvent> _events = const <DoseLogEvent>[];
  List<MedicationShortageAlertRow> _shortageAlerts =
      const <MedicationShortageAlertRow>[];
  String? _dispensingDoseId;
  late DateTime _lastInteractionAt;
  DateTime? _currentTime;
  ConnectivityState? _connectivityState;
  RobotFaceState? _latestState;

  Stream<RobotFaceState> watchState() async* {
    final state = _latestState ??= _computeState();
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
    if (_dispensingDoseId != null) {
      throw const DuplicateDispenseRequestException(
        'A dispense request is already in progress for this dose.',
      );
    }
    // Movement is tracked as command progress only. A separate explicit user
    // action must confirm, skip, or request help for the dose.
    _dispensingDoseId = doseId;
    _emit();
    try {
      await _controllerLifecycle.requestDoseDispense(
        doseId: doseId,
        scheduleId: nextDose.id,
      );
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
    final activeShortageAlert = _activeShortageAlert();
    final activeMissedDose = _activeMissedAlertDose(now);
    // Missed-dose alerts intentionally pin the display to the unresolved dose
    // so recognition and follow-up actions stay attached to the event the user
    // is actually seeing.
    final displaySchedule = activeMissedDose?.schedule ?? _displaySchedule(now);
    final displayDoseId =
        activeMissedDose?.doseId ??
        (displaySchedule == null
            ? null
            : TodayNextDoseHelper.doseIdForDate(displaySchedule.id, now));
    // Compute the current dose event once so mode, status, and actions cannot
    // drift from separate scans of the log.
    final latestDoseEvent = displayDoseId == null
        ? null
        : TodayNextDoseHelper.latestEventForDose(_events, displayDoseId);
    final hasActiveMissedAlert = activeMissedDose != null;
    final nextSchedule = hasActiveMissedAlert
        ? displaySchedule
        : _scheduleForPostMissedRecognition(
            displaySchedule,
            now,
            latestDoseEvent,
          );
    final choreography = _choreographyFor(nextSchedule, now);
    final dueDoseId = _dueDoseIdFor(nextSchedule, now);
    final mode = _modeFor(
      role,
      nextSchedule,
      now,
      dueDoseId,
      latestDoseEvent,
      hasActiveMissedAlert: hasActiveMissedAlert,
    );
    final nextEventLabel = nextSchedule == null
        ? 'No reminders scheduled'
        : '${nextSchedule.timeLabel} · ${nextSchedule.label}';
    final actionDoseId = _actionDoseIdFor(
      mode,
      nextSchedule,
      dueDoseId,
      latestDoseEvent,
      hasActiveMissedAlert: hasActiveMissedAlert,
      displayDoseId: displayDoseId,
    );
    final voiceOccurrenceKey = _voiceOccurrenceKeyFor(
      nextSchedule,
      now,
      displayDoseId: displayDoseId,
      dueDoseId: dueDoseId,
    );
    final baseState = RobotFaceState(
      mode: mode,
      nextEventLabel: nextEventLabel,
      isFlipped: _robotSettings.isFlipped,
      isLandscapeOnly: role?.canHostRobot ?? false,
      rampProgress: choreography.rampProgress,
      isInAwakeWindow: choreography.isInAwakeWindow,
      statusLabel: _statusFor(role, nextSchedule, dueDoseId, latestDoseEvent),
      networkAdvisory: _connectivityState == ConnectivityState.offline
          ? RobotFaceNetworkAdvisory.internetOffline
          : null,
      actionDoseId: actionDoseId,
      voiceOccurrenceKey: voiceOccurrenceKey,
      isAwaitingControllerConfirmation:
          latestDoseEvent?.kind == DoseLogEventKind.controllerDispenseSucceeded,
      availableActions: _availableActionsFor(
        actionDoseId,
        mode: mode,
        hasActiveMissedAlert: hasActiveMissedAlert,
      ),
      hasPinnedShortageAlert: activeShortageAlert != null,
      activeShortageLabel: _activeShortageAlertLabel(activeShortageAlert),
      activeShortageMedicationLabel: _activeShortageMedicationLabel(
        activeShortageAlert,
      ),
      activeShortageScheduledLabel: _activeShortageScheduledLabel(
        activeShortageAlert,
      ),
      activeShortageSlotNumber: activeShortageAlert?.slotNumber,
    );
    if (baseState.mode == RobotFaceMode.idle &&
        !baseState.isInAwakeWindow &&
        _robotSettings.dimAfterInactivity &&
        now.difference(_lastInteractionAt) >= sleepyAfter) {
      return baseState.copyWith(mode: RobotFaceMode.sleepy);
    }
    return baseState;
  }

  MedicationShortageAlertRow? _activeShortageAlert() {
    final profileId = _activeProfile?.id;
    if (profileId == null) {
      return null;
    }
    MedicationShortageAlertRow? activeAlert;
    for (final alert in _shortageAlerts) {
      if (alert.profileId != profileId) {
        continue;
      }
      if (alert.status == 'past_due') {
        return alert;
      }
      if (alert.status == 'active') {
        activeAlert ??= alert;
      }
    }
    return activeAlert;
  }

  String? _activeShortageAlertLabel(MedicationShortageAlertRow? alert) {
    if (alert == null) {
      return null;
    }
    return 'Urgent shortage · slot ${alert.slotNumber}';
  }

  String? _activeShortageMedicationLabel(MedicationShortageAlertRow? alert) {
    if (alert == null) {
      return null;
    }
    return _joinedPrescriptionNames(alert.prescriptionNamesJson);
  }

  String? _activeShortageScheduledLabel(MedicationShortageAlertRow? alert) {
    if (alert == null) {
      return null;
    }
    final scheduledAt = alert.scheduledAt.toLocal();
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _joinedPrescriptionNames(String namesJson) {
    try {
      final decoded = jsonDecode(namesJson);
      if (decoded is List) {
        final labels = decoded
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        if (labels.isNotEmpty) {
          return labels.join(' + ');
        }
      }
    } on FormatException {
      // Fall through to the stored raw value when legacy rows contain bad JSON.
    }
    return namesJson;
  }

  String? _actionDoseIdFor(
    RobotFaceMode mode,
    ReminderSchedule? nextSchedule,
    String? dueDoseId,
    DoseLogEvent? latestDoseEvent, {
    required bool hasActiveMissedAlert,
    required String? displayDoseId,
  }) {
    if (mode == RobotFaceMode.missed && hasActiveMissedAlert) {
      return displayDoseId;
    }

    if (nextSchedule == null || dueDoseId == null) {
      return null;
    }
    if (mode.needsContextualAction) {
      return dueDoseId;
    }

    if (mode == RobotFaceMode.offline || mode == RobotFaceMode.error) {
      // A controller fault should not strand a visible dispensed dose; keep the
      // human follow-up actions available until a terminal dose event lands.
      if (latestDoseEvent != null &&
          _keepsDoseActionable(latestDoseEvent.kind)) {
        return dueDoseId;
      }
    }

    return null;
  }

  bool _keepsDoseActionable(DoseLogEventKind kind) {
    return switch (kind) {
      DoseLogEventKind.controllerDispenseSucceeded ||
      DoseLogEventKind.doseVisibleConfirmed ||
      DoseLogEventKind.doseSnoozed ||
      DoseLogEventKind.caregiverHelpRequested => true,
      _ => false,
    };
  }

  Set<RobotFaceActionKind> _availableActionsFor(
    String? actionDoseId, {
    required RobotFaceMode mode,
    required bool hasActiveMissedAlert,
  }) {
    if (actionDoseId == null) {
      return const <RobotFaceActionKind>{};
    }

    if (mode == RobotFaceMode.missed && hasActiveMissedAlert) {
      return const <RobotFaceActionKind>{
        RobotFaceActionKind.recognizeMissedDose,
      };
    }

    final actions = <RobotFaceActionKind>{
      RobotFaceActionKind.confirmTaken,
      RobotFaceActionKind.skipDose,
      RobotFaceActionKind.askForHelp,
    };

    final hasHelpRequest = _events.any(
      (event) =>
          event.doseId == actionDoseId &&
          event.kind == DoseLogEventKind.caregiverHelpRequested,
    );
    // Help requests are informational. Confirm/skip stay available so the dose
    // can still reach a terminal state after help is requested.
    if (hasHelpRequest) {
      actions.remove(RobotFaceActionKind.askForHelp);
    }

    return actions;
  }

  RobotFaceMode _modeFor(
    AppDeviceRole? role,
    ReminderSchedule? nextSchedule,
    DateTime now,
    String? dueDoseId,
    DoseLogEvent? latestDoseEvent, {
    required bool hasActiveMissedAlert,
  }) {
    if (role == null || !role.canHostRobot) {
      return RobotFaceMode.offline;
    }
    if (_controllerSnapshot.healthState == ControllerHealthState.error) {
      return RobotFaceMode.error;
    }
    if (_controllerSnapshot.healthState != ControllerHealthState.online) {
      return RobotFaceMode.offline;
    }
    if (nextSchedule == null) {
      return RobotFaceMode.idle;
    }
    if (dueDoseId != null && _dispensingDoseId == dueDoseId) {
      return RobotFaceMode.dispensing;
    }
    if (latestDoseEvent != null) {
      switch (latestDoseEvent.kind) {
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
        case DoseLogEventKind.doseMissedRecognized:
          if (hasActiveMissedAlert) {
            return RobotFaceMode.missed;
          }
          break;
        case DoseLogEventKind.error:
          return RobotFaceMode.error;
      }
    }
    final scheduledTime = TodayNextDoseHelper.scheduledTimeForDate(
      nextSchedule,
      now,
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
    String? dueDoseId,
    DoseLogEvent? latestDoseEvent,
  ) {
    if (role == null || !role.canHostRobot) {
      return 'Robot Face is only available in Robot Mode';
    }
    if (_controllerSnapshot.healthState != ControllerHealthState.online) {
      return _controllerSnapshot.statusLabel;
    }
    if (latestDoseEvent?.kind == DoseLogEventKind.doseMissedRecognized) {
      return 'Missed dose acknowledged';
    }
    if (nextSchedule == null) {
      return 'No active reminder';
    }
    if (dueDoseId != null && _dispensingDoseId == dueDoseId) {
      return 'Dispensing in progress';
    }
    if (latestDoseEvent == null) {
      return null;
    }
    return switch (latestDoseEvent.kind) {
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
      DoseLogEventKind.doseMissedRecognized => 'Missed dose acknowledged',
      DoseLogEventKind.error => 'Dose error logged',
    };
  }

  bool _hasActiveMissedAlert(String doseId) {
    DateTime? missedAt;
    DateTime? recognizedAt;
    for (final event in _events) {
      if (event.doseId != doseId) {
        continue;
      }
      switch (event.kind) {
        case DoseLogEventKind.doseMissed:
          missedAt = missedAt == null || event.occurredAt.isAfter(missedAt)
              ? event.occurredAt
              : missedAt;
        case DoseLogEventKind.doseMissedRecognized:
          recognizedAt =
              recognizedAt == null || event.occurredAt.isAfter(recognizedAt)
              ? event.occurredAt
              : recognizedAt;
        default:
          break;
      }
    }

    return missedAt != null &&
        (recognizedAt == null || recognizedAt.isBefore(missedAt));
  }

  _RobotFaceDisplayDose? _activeMissedAlertDose(DateTime now) {
    _RobotFaceDisplayDose? activeDose;
    DateTime? activeScheduledTime;
    final today = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day);
    final candidateDates = <DateTime>[
      today.subtract(const Duration(days: 1)),
      today,
    ];

    for (final schedule in _activeSchedules) {
      if (!schedule.isEnabled) {
        continue;
      }

      for (final doseDate in candidateDates) {
        final scheduledTime = TodayNextDoseHelper.scheduledTimeForDate(
          schedule,
          doseDate,
        );
        if (scheduledTime.isAfter(now)) {
          continue;
        }

        final doseId = TodayNextDoseHelper.doseIdForDate(schedule.id, doseDate);
        if (!_hasActiveMissedAlert(doseId)) {
          continue;
        }

        if (activeScheduledTime == null ||
            scheduledTime.isAfter(activeScheduledTime)) {
          activeScheduledTime = scheduledTime;
          activeDose = _RobotFaceDisplayDose(
            schedule: schedule,
            doseId: doseId,
          );
        }
      }
    }

    return activeDose;
  }

  ReminderSchedule? _scheduleForPostMissedRecognition(
    ReminderSchedule? displaySchedule,
    DateTime now,
    DoseLogEvent? latestDoseEvent,
  ) {
    if (displaySchedule == null ||
        latestDoseEvent?.kind != DoseLogEventKind.doseMissedRecognized) {
      return displaySchedule;
    }

    return TodayNextDoseHelper.currentSchedule(
      _activeSchedules,
      _events,
      now: now,
    );
  }

  DateTime _current() => _currentTime ?? _now();

  ReminderSchedule? _displaySchedule(DateTime now) {
    // Keep showing the latest unresolved due dose before advancing to future
    // reminders, so follow-up actions stay attached to the right dose.
    return TodayNextDoseHelper.currentOrLatestDueSchedule(
      _activeSchedules,
      _events,
      now: now,
    );
  }

  ReminderSchedule? _dueSchedule(DateTime now) {
    for (final schedule in _activeSchedules) {
      if (!schedule.isEnabled) {
        continue;
      }

      final scheduledTime = TodayNextDoseHelper.scheduledTimeForDate(
        schedule,
        now,
      );

      if (scheduledTime.isAfter(now)) {
        continue;
      }

      final doseId = TodayNextDoseHelper.doseIdForDate(schedule.id, now);
      if (!TodayNextDoseHelper.hasTerminalEventForDose(_events, doseId)) {
        return schedule;
      }
    }

    return null;
  }

  String? _dueDoseIdFor(ReminderSchedule? nextSchedule, DateTime now) {
    if (nextSchedule == null) {
      return null;
    }
    final dueSchedule = _dueSchedule(now);
    if (dueSchedule == null || dueSchedule.id != nextSchedule.id) {
      return null;
    }
    // Action ids are only minted for the actual due schedule, not for future
    // reminders shown in the status card.
    return TodayNextDoseHelper.doseIdForDate(dueSchedule.id, now);
  }

  String? _voiceOccurrenceKeyFor(
    ReminderSchedule? nextSchedule,
    DateTime now, {
    required String? displayDoseId,
    required String? dueDoseId,
  }) {
    if (nextSchedule == null) {
      return null;
    }
    return dueDoseId ??
        displayDoseId ??
        TodayNextDoseHelper.doseIdForDate(nextSchedule.id, now);
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

    final scheduledTime = TodayNextDoseHelper.scheduledTimeForDate(
      schedule,
      now,
    );
    final wakeBeforeWindow = _wakeBeforeWindow;
    final stayAwakeWindow = Duration(
      minutes: _robotSettings.stayAwakeAfterDoseMinutes,
    );
    final wakeWindowStart = scheduledTime.subtract(wakeBeforeWindow);
    final wakeWindowEnd = scheduledTime.add(stayAwakeWindow);

    // Ramp drives visual urgency before the dose time while stay-awake keeps the
    // face active afterward for confirmation/help.
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
    return Duration(minutes: _robotSettings.wakeBeforeDoseMinutes);
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

class _RobotFaceDisplayDose {
  const _RobotFaceDisplayDose({required this.schedule, required this.doseId});

  final ReminderSchedule schedule;
  final String doseId;
}
