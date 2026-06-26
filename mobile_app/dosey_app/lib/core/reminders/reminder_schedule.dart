import 'package:dosey_app/core/schedules/schedule_profile.dart';

class ReminderSchedule {
  const ReminderSchedule({
    required this.id,
    required this.label,
    this.prescriptionId,
    this.profileId = defaultProfileId,
    required this.hour,
    required this.minute,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultProfileId = ScheduleProfile.defaultProfileId;

  final String id;
  final String label;
  final String? prescriptionId;
  final String profileId;
  final int hour;
  final int minute;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get timeLabel {
    final paddedHour = hour.toString().padLeft(2, '0');
    final paddedMinute = minute.toString().padLeft(2, '0');
    return '$paddedHour:$paddedMinute';
  }

  ReminderSchedule copyWith({
    String? label,
    String? prescriptionId,
    String? profileId,
    int? hour,
    int? minute,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return ReminderSchedule(
      id: id,
      label: label ?? this.label,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      profileId: profileId ?? this.profileId,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
