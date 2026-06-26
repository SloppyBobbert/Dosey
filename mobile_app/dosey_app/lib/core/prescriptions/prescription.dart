enum PillType {
  pill(storageValue: 'pill', label: 'Pill'),
  capsule(storageValue: 'capsule', label: 'Capsule'),
  tablet(storageValue: 'tablet', label: 'Tablet');

  const PillType({required this.storageValue, required this.label});

  final String storageValue;
  final String label;

  static PillType fromStorageValue(String value) {
    return values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => PillType.pill,
    );
  }
}

class Prescription {
  const Prescription({
    required this.id,
    required this.name,
    required this.pillType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final PillType pillType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Prescription copyWith({
    String? name,
    PillType? pillType,
    DateTime? updatedAt,
  }) {
    return Prescription(
      id: id,
      name: name ?? this.name,
      pillType: pillType ?? this.pillType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
