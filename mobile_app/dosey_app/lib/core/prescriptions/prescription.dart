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

enum GuidedPillIcon {
  tablet(storageValue: 'tablet'),
  roundPill(storageValue: 'roundPill'),
  ovalTablet(storageValue: 'ovalTablet'),
  capsule(storageValue: 'capsule'),
  softgel(storageValue: 'softgel'),
  splitPill(storageValue: 'splitPill'),
  multiplePills(storageValue: 'multiplePills');

  const GuidedPillIcon({required this.storageValue});

  final String storageValue;

  static GuidedPillIcon fromStorageValue(String value) {
    return values.firstWhere(
      (icon) => icon.storageValue == value,
      orElse: () => GuidedPillIcon.roundPill,
    );
  }
}

class Prescription {
  Prescription({
    required this.id,
    required this.name,
    required this.pillType,
    this.guidedPillIcon = GuidedPillIcon.roundPill,
    int availableDoses = 0,
    @Deprecated('Use availableDoses instead') int? remainingDoses,
    this.loadedDoses = 0,
    this.usedDoses = 0,
    this.reviewDoses = 0,
    this.defaultRefillQuantity = 30,
    this.defaultDoseCountPerDose = 1,
    this.doseInstructions = '',
    this.refillThreshold = 3,
    required this.createdAt,
    required this.updatedAt,
  }) : _remainingDoses =
           remainingDoses ?? availableDoses + loadedDoses + reviewDoses,
       _usedLegacyRemainingDosesInput = remainingDoses != null,
       availableDoses = remainingDoses == null
           ? availableDoses
           : (remainingDoses - loadedDoses - reviewDoses).clamp(
               0,
               remainingDoses,
             );

  final String id;
  final String name;
  final PillType pillType;
  final GuidedPillIcon guidedPillIcon;
  final int _remainingDoses;
  final bool _usedLegacyRemainingDosesInput;
  final int availableDoses;
  final int loadedDoses;
  final int usedDoses;
  final int reviewDoses;
  final int defaultRefillQuantity;
  final int defaultDoseCountPerDose;
  final String doseInstructions;
  final int refillThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get remainingDoses => _remainingDoses;

  bool get usedLegacyRemainingDosesInput => _usedLegacyRemainingDosesInput;

  bool get needsRefill => remainingDoses <= refillThreshold;

  Prescription copyWith({
    String? name,
    PillType? pillType,
    GuidedPillIcon? guidedPillIcon,
    int? availableDoses,
    int? loadedDoses,
    int? usedDoses,
    int? reviewDoses,
    int? defaultRefillQuantity,
    int? defaultDoseCountPerDose,
    String? doseInstructions,
    int? remainingDoses,
    int? refillThreshold,
    DateTime? updatedAt,
  }) {
    final nextAvailableDoses = availableDoses ?? this.availableDoses;
    final nextLoadedDoses = loadedDoses ?? this.loadedDoses;
    final nextUsedDoses = usedDoses ?? this.usedDoses;
    final nextReviewDoses = reviewDoses ?? this.reviewDoses;
    return Prescription(
      id: id,
      name: name ?? this.name,
      pillType: pillType ?? this.pillType,
      guidedPillIcon: guidedPillIcon ?? this.guidedPillIcon,
      availableDoses: nextAvailableDoses,
      loadedDoses: nextLoadedDoses,
      usedDoses: nextUsedDoses,
      reviewDoses: nextReviewDoses,
      defaultRefillQuantity:
          defaultRefillQuantity ?? this.defaultRefillQuantity,
      defaultDoseCountPerDose:
          defaultDoseCountPerDose ?? this.defaultDoseCountPerDose,
      doseInstructions: doseInstructions ?? this.doseInstructions,
      remainingDoses: remainingDoses,
      refillThreshold: refillThreshold ?? this.refillThreshold,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PrescriptionRefill {
  const PrescriptionRefill({
    required this.id,
    required this.prescriptionId,
    required this.doseDelta,
    required this.remainingAfter,
    required this.occurredAt,
    required this.note,
  });

  final String id;
  final String prescriptionId;
  final int doseDelta;
  final int remainingAfter;
  final DateTime occurredAt;
  final String? note;
}
