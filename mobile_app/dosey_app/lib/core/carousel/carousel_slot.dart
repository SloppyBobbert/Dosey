enum CarouselSlotStatus {
  assigned(storageValue: 'assigned', label: 'Assigned'),
  loaded(storageValue: 'loaded', label: 'Loaded'),
  dispensed(storageValue: 'dispensed', label: 'Dispensed'),
  needsReview(storageValue: 'needs_review', label: 'Needs review');

  const CarouselSlotStatus({required this.storageValue, required this.label});

  final String storageValue;
  final String label;

  static CarouselSlotStatus fromStorageValue(String value) {
    return values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => CarouselSlotStatus.needsReview,
    );
  }
}

class CarouselSlot {
  const CarouselSlot({
    required this.id,
    required this.slotNumber,
    required this.prescriptionId,
    required this.scheduleId,
    required this.profileId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int slotNumber;
  final String prescriptionId;
  final String scheduleId;
  final String profileId;
  final CarouselSlotStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  CarouselSlot copyWith({
    int? slotNumber,
    String? prescriptionId,
    String? scheduleId,
    String? profileId,
    CarouselSlotStatus? status,
    DateTime? updatedAt,
  }) {
    return CarouselSlot(
      id: id,
      slotNumber: slotNumber ?? this.slotNumber,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      scheduleId: scheduleId ?? this.scheduleId,
      profileId: profileId ?? this.profileId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
