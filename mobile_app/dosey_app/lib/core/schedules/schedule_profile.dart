class ScheduleProfile {
  const ScheduleProfile({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultProfileId = 'schedule-1';

  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleProfile copyWith({
    String? name,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return ScheduleProfile(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
