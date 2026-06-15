class ReminderSchedule {
  const ReminderSchedule({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String label;
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
    int? hour,
    int? minute,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return ReminderSchedule(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
