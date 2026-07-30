enum CaregiverDoseAction { taken, skipped, snoozed, helpRequested }

enum CaregiverPillType { pill, capsule, tablet }

class CaregiverMedication {
  CaregiverMedication({
    required this.id,
    required String name,
    required this.instructions,
    this.pillType = CaregiverPillType.pill,
    required this.active,
    required this.version,
  }) : name = _required(name, 'name');

  final String id;
  final String name;
  final String instructions;
  final CaregiverPillType pillType;
  final bool active;
  final int version;
}

class CaregiverSchedule {
  CaregiverSchedule({
    required this.id,
    required this.medicationId,
    required String label,
    required this.hour,
    required this.minute,
    this.timezoneId = 'UTC',
    required this.enabled,
    required this.version,
  }) : label = _required(label, 'label') {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Schedule time is invalid.');
    }
  }

  final String id;
  final String medicationId;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool enabled;
  final int version;
}

class CaregiverDoseEvent {
  const CaregiverDoseEvent({
    required this.id,
    required this.scheduleId,
    required this.scheduledFor,
    required this.occurredAt,
    required this.action,
  });

  final String id;
  final String scheduleId;
  final DateTime scheduledFor;
  final DateTime occurredAt;
  final CaregiverDoseAction action;
}

class CaregiverSnapshot {
  CaregiverSnapshot({
    required this.householdId,
    required this.revision,
    required this.generatedAt,
    required List<CaregiverMedication> medications,
    required List<CaregiverSchedule> schedules,
    required List<CaregiverDoseEvent> events,
  }) : medications = List.unmodifiable(medications),
       schedules = List.unmodifiable(schedules),
       events = List.unmodifiable(events);

  final String householdId;
  final String revision;
  final DateTime generatedAt;
  final List<CaregiverMedication> medications;
  final List<CaregiverSchedule> schedules;
  final List<CaregiverDoseEvent> events;
}

enum CaregiverMutationKind {
  upsertMedication,
  deleteMedication,
  upsertSchedule,
  deleteSchedule,
  recordDose,
}

class CaregiverMutation {
  const CaregiverMutation._({required this.kind, required this.values});

  factory CaregiverMutation.recordDose({
    required String scheduleId,
    required String scheduledForIso,
    required CaregiverDoseAction action,
  }) => CaregiverMutation._(
    kind: CaregiverMutationKind.recordDose,
    values: {
      'scheduleId': scheduleId,
      'scheduledFor': scheduledForIso,
      'action': action.name,
    },
  );

  factory CaregiverMutation.upsertMedication(CaregiverMedication medication) =>
      CaregiverMutation._(
        kind: CaregiverMutationKind.upsertMedication,
        values: {
          'id': medication.id,
          'name': medication.name,
          'instructions': medication.instructions,
          'pillType': medication.pillType.name,
          'active': medication.active,
          'version': medication.version,
        },
      );

  factory CaregiverMutation.deleteMedication(CaregiverMedication medication) =>
      CaregiverMutation._(
        kind: CaregiverMutationKind.deleteMedication,
        values: {'id': medication.id, 'version': medication.version},
      );

  factory CaregiverMutation.upsertSchedule(CaregiverSchedule schedule) =>
      CaregiverMutation._(
        kind: CaregiverMutationKind.upsertSchedule,
        values: {
          'id': schedule.id,
          'medicationId': schedule.medicationId,
          'label': schedule.label,
          'hour': schedule.hour,
          'minute': schedule.minute,
          'timezoneId': schedule.timezoneId,
          'enabled': schedule.enabled,
          'version': schedule.version,
        },
      );

  factory CaregiverMutation.deleteSchedule(CaregiverSchedule schedule) =>
      CaregiverMutation._(
        kind: CaregiverMutationKind.deleteSchedule,
        values: {'id': schedule.id, 'version': schedule.version},
      );

  final CaregiverMutationKind kind;
  final Map<String, Object?> values;
}

String _required(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, name, 'is required');
  return normalized;
}
