import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith preserves bucket mode when remainingDoses is omitted', () {
    final prescription = Prescription(
      id: 'rx-1',
      name: 'Vitamin D',
      pillType: PillType.capsule,
      guidedPillIcon: GuidedPillIcon.softgel,
      availableDoses: 10,
      loadedDoses: 3,
      usedDoses: 2,
      reviewDoses: 1,
      createdAt: DateTime.utc(2026, 7, 23, 8),
      updatedAt: DateTime.utc(2026, 7, 23, 8),
    );

    final updated = prescription.copyWith(availableDoses: 8);

    expect(updated.usedLegacyRemainingDosesInput, isFalse);
    expect(updated.availableDoses, 8);
    expect(updated.loadedDoses, 3);
    expect(updated.reviewDoses, 1);
    expect(updated.remainingDoses, 12);
    expect(updated.guidedPillIcon, GuidedPillIcon.softgel);
  });

  test('copyWith preserves explicit remainingDoses updates', () {
    final prescription = Prescription(
      id: 'rx-1',
      name: 'Vitamin D',
      pillType: PillType.capsule,
      availableDoses: 10,
      loadedDoses: 3,
      reviewDoses: 1,
      createdAt: DateTime.utc(2026, 7, 23, 8),
      updatedAt: DateTime.utc(2026, 7, 23, 8),
    );

    final updated = prescription.copyWith(remainingDoses: 20);

    expect(updated.usedLegacyRemainingDosesInput, isTrue);
    expect(updated.remainingDoses, 20);
    expect(updated.availableDoses, 16);
    expect(updated.loadedDoses, 3);
    expect(updated.reviewDoses, 1);
  });
}
