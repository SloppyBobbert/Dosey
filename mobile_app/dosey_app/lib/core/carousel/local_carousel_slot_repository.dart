import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

abstract interface class CarouselSlotRepository {
  Stream<List<CarouselSlot>> watchSlots({String? profileId});

  Future<void> assignSlot(CarouselSlot slot);

  Future<void> markLoaded(String id);

  Future<void> markDispensed(String id);

  Future<void> markNeedsReview(String id);

  Future<void> clearSlot(String id);

  Future<void> clearProfile(String profileId);
}

class LocalCarouselSlotRepository implements CarouselSlotRepository {
  const LocalCarouselSlotRepository(this._database);

  final DoseyDatabase _database;

  @override
  Stream<List<CarouselSlot>> watchSlots({String? profileId}) {
    final query = _database.select(_database.carouselSlots)
      ..orderBy([(slot) => OrderingTerm.asc(slot.slotNumber)]);
    if (profileId != null) {
      query.where((slot) => slot.profileId.equals(profileId));
    }

    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<void> assignSlot(CarouselSlot slot) async {
    await _validateSlot(slot);
    await _clearDisabledScheduleSlots(slot.profileId);
    await _rejectDuplicateSlot(slot);
    await _rejectDuplicateSchedule(slot);

    try {
      final existing = await (_database.select(
        _database.carouselSlots,
      )..where((row) => row.id.equals(slot.id))).getSingleOrNull();
      if (existing == null) {
        await _database
            .into(_database.carouselSlots)
            .insert(_companionFor(slot));
        return;
      }

      final updated =
          await (_database.update(
            _database.carouselSlots,
          )..where((row) => row.id.equals(slot.id))).write(
            CarouselSlotsCompanion(
              slotNumber: Value(slot.slotNumber),
              prescriptionId: Value(slot.prescriptionId),
              scheduleId: Value(slot.scheduleId),
              profileId: Value(slot.profileId),
              status: Value(slot.status.storageValue),
              updatedAt: Value(slot.updatedAt.toUtc()),
            ),
          );
      if (updated == 0) {
        throw ArgumentError(
          'No carousel slot was updated for id "${slot.id}".',
        );
      }
    } on Object catch (error) {
      if (_isConstraintFailure(error)) {
        await _throwDuplicateConflict(slot);
      }
      rethrow;
    }
  }

  @override
  Future<void> markLoaded(String id) {
    return _updateStatus(id, CarouselSlotStatus.loaded);
  }

  @override
  Future<void> markDispensed(String id) {
    return _updateStatus(id, CarouselSlotStatus.dispensed);
  }

  @override
  Future<void> markNeedsReview(String id) {
    return _updateStatus(id, CarouselSlotStatus.needsReview);
  }

  @override
  Future<void> clearSlot(String id) {
    return (_database.delete(
      _database.carouselSlots,
    )..where((slot) => slot.id.equals(id))).go();
  }

  @override
  Future<void> clearProfile(String profileId) {
    return (_database.delete(
      _database.carouselSlots,
    )..where((slot) => slot.profileId.equals(profileId))).go();
  }

  Future<void> _updateStatus(String id, CarouselSlotStatus status) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Slot id is required.');
    }
    final updated =
        await (_database.update(
          _database.carouselSlots,
        )..where((slot) => slot.id.equals(id))).write(
          CarouselSlotsCompanion(
            status: Value(status.storageValue),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (updated == 0) {
      throw ArgumentError('No carousel slot was updated for id "$id".');
    }
  }

  static CarouselSlotsCompanion _companionFor(CarouselSlot slot) {
    return CarouselSlotsCompanion.insert(
      id: slot.id,
      slotNumber: slot.slotNumber,
      prescriptionId: slot.prescriptionId,
      scheduleId: slot.scheduleId,
      profileId: slot.profileId,
      status: slot.status.storageValue,
      createdAt: slot.createdAt.toUtc(),
      updatedAt: slot.updatedAt.toUtc(),
    );
  }

  Future<void> _rejectDuplicateSlot(CarouselSlot slot) async {
    final duplicate =
        await (_database.select(_database.carouselSlots)
              ..where(
                (row) =>
                    row.profileId.equals(slot.profileId) &
                    row.slotNumber.equals(slot.slotNumber) &
                    row.id.equals(slot.id).not(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (duplicate == null) return;

    throw ArgumentError(
      'Slot ${slot.slotNumber} is already assigned for this schedule profile.',
    );
  }

  Future<void> _clearDisabledScheduleSlots(String profileId) async {
    final disabledSchedules =
        await (_database.select(_database.reminderSchedules)..where(
              (schedule) =>
                  schedule.profileId.equals(profileId) &
                  schedule.isEnabled.equals(false),
            ))
            .get();
    if (disabledSchedules.isEmpty) return;

    await (_database.delete(_database.carouselSlots)..where(
          (slot) =>
              slot.profileId.equals(profileId) &
              slot.scheduleId.isIn(
                disabledSchedules.map((schedule) => schedule.id),
              ),
        ))
        .go();
  }

  Future<void> _throwDuplicateConflict(CarouselSlot slot) async {
    await _rejectDuplicateSlot(slot);
    await _rejectDuplicateSchedule(slot);
    throw ArgumentError(
      'Carousel slot assignment conflicts with an existing slot.',
    );
  }

  static bool _isConstraintFailure(Object error) {
    final message = error.toString();
    return message.contains('UNIQUE constraint failed') ||
        message.contains('constraint failed');
  }

  Future<void> _rejectDuplicateSchedule(CarouselSlot slot) async {
    final duplicate =
        await (_database.select(_database.carouselSlots)
              ..where(
                (row) =>
                    row.profileId.equals(slot.profileId) &
                    row.scheduleId.equals(slot.scheduleId) &
                    row.id.equals(slot.id).not(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (duplicate == null) return;

    throw ArgumentError(
      'This scheduled dose is already assigned to a carousel slot.',
    );
  }

  static CarouselSlot _fromRow(CarouselSlotRow row) {
    return CarouselSlot(
      id: row.id,
      slotNumber: row.slotNumber,
      prescriptionId: row.prescriptionId,
      scheduleId: row.scheduleId,
      profileId: row.profileId,
      status: CarouselSlotStatus.fromStorageValue(row.status),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }

  Future<void> _validateSlot(CarouselSlot slot) async {
    if (slot.id.trim().isEmpty) {
      throw ArgumentError.value(slot.id, 'id', 'Slot id is required.');
    }
    if (slot.slotNumber <= 0) {
      throw ArgumentError.value(
        slot.slotNumber,
        'slotNumber',
        'Slot number must be positive.',
      );
    }
    if (slot.prescriptionId.trim().isEmpty) {
      throw ArgumentError.value(
        slot.prescriptionId,
        'prescriptionId',
        'Prescription id is required.',
      );
    }
    if (slot.scheduleId.trim().isEmpty) {
      throw ArgumentError.value(
        slot.scheduleId,
        'scheduleId',
        'Schedule id is required.',
      );
    }
    if (slot.profileId.trim().isEmpty) {
      throw ArgumentError.value(
        slot.profileId,
        'profileId',
        'Schedule profile id is required.',
      );
    }

    final schedule =
        await (_database.select(_database.reminderSchedules)
              ..where((schedule) => schedule.id.equals(slot.scheduleId)))
            .getSingleOrNull();
    if (schedule == null) {
      throw ArgumentError.value(
        slot.scheduleId,
        'scheduleId',
        'Schedule must exist before assigning a carousel slot.',
      );
    }
    if (!schedule.isEnabled) {
      throw ArgumentError.value(
        slot.scheduleId,
        'scheduleId',
        'Schedule must be enabled before assigning a carousel slot.',
      );
    }
    if (schedule.profileId != slot.profileId) {
      throw ArgumentError.value(
        slot.profileId,
        'profileId',
        'Carousel slot profile must match the schedule profile.',
      );
    }
    if (schedule.prescriptionId != slot.prescriptionId) {
      throw ArgumentError.value(
        slot.prescriptionId,
        'prescriptionId',
        'Carousel slot prescription must match the schedule prescription.',
      );
    }
  }
}
