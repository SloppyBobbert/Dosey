import 'package:dosey_app/core/carousel/guided_dispense_target_resolver.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class DuplicateDispenseRequestException implements Exception {
  const DuplicateDispenseRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ControllerLifecycleService {
  ControllerLifecycleService({
    required this._controller,
    required this._commandRepository,
    required this._doseLog,
    required this._carouselSlots,
    this.guidedCarouselLoads,
    this.database,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const manualTestDoseId = 'manual-test';

  final ControllerGateway _controller;
  final ControllerCommandRepository _commandRepository;
  final DoseLogRepository _doseLog;
  final CarouselSlotRepository _carouselSlots;
  final LocalGuidedCarouselLoadRepository? guidedCarouselLoads;
  final DoseyDatabase? database;
  final DateTime Function() _now;
  final Set<String> _activeDispenseKeys = <String>{};

  static const _controllerDispenseKey = 'controller:dispense';

  Future<void> requestManualDispenseTest() {
    return _runDispense(
      commandType: ControllerCommandType.dispenseTest,
      doseId: manualTestDoseId,
    );
  }

  Future<void> requestManualServoTest() {
    return _runDispense(
      commandType: ControllerCommandType.servoTest,
      doseId: manualTestDoseId,
    );
  }

  Future<void> requestDoseDispense({
    required String doseId,
    String? slotId,
    String? scheduleId,
  }) {
    return _runDispense(
      commandType: ControllerCommandType.dispenseNext,
      doseId: doseId,
      slotId: slotId,
      scheduleId: scheduleId,
    );
  }

  Future<void> _runDispense({
    required ControllerCommandType commandType,
    required String doseId,
    String? slotId,
    String? scheduleId,
  }) async {
    // The controller has one physical dispense path. Serialize every dispense
    // command globally, then keep dose/slot keys for clearer duplicate errors.
    final activeKeys = <String>{'dose:$doseId'};
    if (slotId != null) {
      activeKeys.add('slot:$slotId');
    }
    if (activeKeys.any(_activeDispenseKeys.contains)) {
      throw const DuplicateDispenseRequestException(
        'A dispense request is already in progress for this dose.',
      );
    }
    if (_activeDispenseKeys.contains(_controllerDispenseKey)) {
      throw const DuplicateDispenseRequestException(
        'A controller dispense request is already in progress.',
      );
    }
    activeKeys.add(_controllerDispenseKey);
    _activeDispenseKeys.addAll(activeKeys);

    var controllerMoved = false;
    DateTime? acceptedAt;
    final sentAt = _current();
    GuidedDispenseTarget? guidedTarget;
    try {
      if (guidedCarouselLoads != null &&
          database != null &&
          scheduleId != null) {
        guidedTarget = await resolveGuidedDispenseTarget(
          database: database!,
          guidedCarouselLoads: guidedCarouselLoads!,
          scheduleId: scheduleId,
          doseId: doseId,
        );
        if (guidedTarget != null && !guidedTarget.isReadyToDispense) {
          throw StateError('Guided load slot is not ready to dispense.');
        }
      }
      final session = await _commandRepository.createSession(
        commandType: commandType,
        now: sentAt,
        doseId: doseId,
        scheduleId: scheduleId,
        slotId: slotId,
      );
      await _commandRepository.appendEvent(
        session.id,
        ControllerCommandEventType.commandSent,
        occurredAt: sentAt,
      );

      try {
        var movementStarted = false;
        Future<void> recordStage(ControllerDispenseStage stage) async {
          final occurredAt = _current();
          switch (stage) {
            case ControllerDispenseStage.accepted:
              if (acceptedAt != null) {
                return;
              }
              acceptedAt = occurredAt;
              await _commandRepository.appendEvent(
                session.id,
                ControllerCommandEventType.ack,
                occurredAt: occurredAt,
              );
              await _commandRepository.updateSessionState(
                session.id,
                ControllerCommandSessionState.accepted,
                acceptedAt: occurredAt,
                updatedAt: occurredAt,
              );
            case ControllerDispenseStage.movementStarted:
              if (movementStarted) {
                return;
              }
              if (acceptedAt == null) {
                await recordStage(ControllerDispenseStage.accepted);
              }
              movementStarted = true;
              await _commandRepository.appendEvent(
                session.id,
                ControllerCommandEventType.moveStarted,
                occurredAt: occurredAt,
              );
              await _commandRepository.updateSessionState(
                session.id,
                ControllerCommandSessionState.accepted,
                acceptedAt: acceptedAt,
                updatedAt: occurredAt,
              );
          }
        }

        if (_controller case final StagedControllerGateway stagedController) {
          await stagedController.requestStagedDispense(
            doseId: doseId,
            movement: switch (commandType) {
              ControllerCommandType.servoTest =>
                ControllerMovementCommand.servoTest,
              ControllerCommandType.dispenseTest =>
                ControllerMovementCommand.dispenseTest,
              ControllerCommandType.dispenseNext =>
                ControllerMovementCommand.dispenseNext,
              _ => throw StateError('Unsupported movement command type.'),
            },
            onStage: recordStage,
          );
        } else {
          await _controller.requestDispense(doseId: doseId);
          await recordStage(ControllerDispenseStage.accepted);
          await recordStage(ControllerDispenseStage.movementStarted);
        }
        controllerMoved = true;

        final resolvedAt = _current();
        await _commandRepository.appendEvent(
          session.id,
          ControllerCommandEventType.servoDone,
          occurredAt: resolvedAt,
        );
        if (guidedTarget != null) {
          await guidedCarouselLoads!.recordDispenseMovementSucceeded(
            profileId: guidedTarget.profileId,
            activeSessionId: guidedTarget.sessionId,
            slotNumber: guidedTarget.slotNumber,
            occurredAt: resolvedAt,
          );
          if (slotId != null) {
            try {
              await _carouselSlots.markDispensed(slotId);
            } on Object {
              // Guided snapshot/session state is authoritative for guided paths.
            }
          }
        } else if (slotId != null) {
          await _carouselSlots.markDispensed(slotId);
        }
        if (commandType == ControllerCommandType.dispenseNext) {
          await _doseLog.addEvent(
            DoseLogEvent.controllerDispenseSucceeded(
              doseId: doseId,
              occurredAt: resolvedAt,
            ),
          );
        }
        await _commandRepository.updateSessionState(
          session.id,
          ControllerCommandSessionState.succeeded,
          acceptedAt: acceptedAt,
          resolvedAt: resolvedAt,
          updatedAt: resolvedAt,
        );
      } on Object catch (error) {
        final failedAt = _current();
        if (error is ControllerCommandPreAcceptanceTimeoutException) {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.timedOut,
            failureReason: ControllerCommandFailureReason.timeout,
            updatedAt: failedAt,
          );
          await _restoreReadyStateForFailedGuidedOrLegacySlot(
            slotId: slotId,
            guidedTarget: guidedTarget,
          );
        } else if (error is ControllerCommandRejectedException) {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.nack,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.failed,
            failureReason: ControllerCommandFailureReason.nack,
            updatedAt: failedAt,
          );
          await _restoreReadyStateForFailedGuidedOrLegacySlot(
            slotId: slotId,
            guidedTarget: guidedTarget,
          );
        } else if (error is ControllerCommandPreconditionException) {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.failed,
            updatedAt: failedAt,
          );
          await _restoreReadyStateForFailedGuidedOrLegacySlot(
            slotId: slotId,
            guidedTarget: guidedTarget,
          );
        } else if (error is ControllerTransportOfflineException) {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.offline,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.failed,
            failureReason: ControllerCommandFailureReason.offline,
            updatedAt: failedAt,
          );
          await _restoreReadyStateForFailedGuidedOrLegacySlot(
            slotId: slotId,
            guidedTarget: guidedTarget,
          );
        } else if (error is ControllerCommandTimeoutException) {
          // From here down, the command may have reached hardware even when the
          // app did not observe a clean completion path. Treat those cases as
          // physically ambiguous and preserve a review trail instead of
          // pretending the slot is safely loaded again.
          // Accepted but unresolved is physically ambiguous: do not reopen the
          // carousel slot as loaded, because movement may already have started.
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _quarantineGuidedOrLegacySlotForReview(
            slotId: slotId,
            guidedTarget: guidedTarget,
            occurredAt: failedAt,
            reason: 'timeout',
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.timedOut,
            failureReason: ControllerCommandFailureReason.timeout,
            acceptedAt: acceptedAt,
            updatedAt: failedAt,
          );
        } else if (error is ControllerCommandJamException) {
          // Jams happen after acceptance in this model, so the user must review
          // the slot before another dispense attempt.
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _quarantineGuidedOrLegacySlotForReview(
            slotId: slotId,
            guidedTarget: guidedTarget,
            occurredAt: failedAt,
            reason: ControllerCommandFailureReason.jam.name,
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.failed,
            failureReason: ControllerCommandFailureReason.jam,
            acceptedAt: acceptedAt,
            updatedAt: failedAt,
          );
        } else if (error is ControllerCommandInterruptedException) {
          // A disconnect after possible acceptance is unsafe to classify as
          // failed-before-movement. Preserve the session for review.
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.offline,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _quarantineGuidedOrLegacySlotForReview(
            slotId: slotId,
            guidedTarget: guidedTarget,
            occurredAt: failedAt,
            reason: ControllerCommandFailureReason.disconnect.name,
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
            failureReason: ControllerCommandFailureReason.disconnect,
            acceptedAt: acceptedAt,
            updatedAt: failedAt,
          );
        } else if (controllerMoved) {
          // Local logging or slot writes failed after movement completed. Keep
          // the physical state conservative instead of rolling back to loaded.
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _quarantineGuidedOrLegacySlotForReview(
            slotId: slotId,
            guidedTarget: guidedTarget,
            occurredAt: failedAt,
            reason: 'post_send_local_failure',
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
            acceptedAt: acceptedAt ?? failedAt,
            updatedAt: failedAt,
          );
        } else {
          // Unknown transport errors are treated as acceptance-ambiguous unless
          // the gateway proves they happened before the command reached hardware.
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          await _quarantineGuidedOrLegacySlotForReview(
            slotId: slotId,
            guidedTarget: guidedTarget,
            occurredAt: failedAt,
            reason: 'unknown_transport_error',
          );
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
            acceptedAt: acceptedAt,
            updatedAt: failedAt,
          );
        }
        rethrow;
      }
    } on Object {
      rethrow;
    } finally {
      _activeDispenseKeys.removeAll(activeKeys);
    }
  }

  DateTime _current() => _now().toUtc();

  Future<void> _restoreReadyStateForFailedGuidedOrLegacySlot({
    required String? slotId,
    required GuidedDispenseTarget? guidedTarget,
  }) async {
    if (guidedTarget != null) {
      return;
    }
    if (slotId != null) {
      await _carouselSlots.markLoaded(slotId);
    }
  }

  Future<void> _quarantineGuidedOrLegacySlotForReview({
    required String? slotId,
    required GuidedDispenseTarget? guidedTarget,
    required DateTime occurredAt,
    required String reason,
  }) async {
    if (guidedTarget != null) {
      await guidedCarouselLoads!.quarantineSlotForReview(
        profileId: guidedTarget.profileId,
        activeSessionId: guidedTarget.sessionId,
        slotNumber: guidedTarget.slotNumber,
        occurredAt: occurredAt,
        reason: reason,
      );
      if (slotId != null) {
        await _moveSlotToNeedsReview(slotId);
      }
      return;
    }
    if (slotId != null) {
      await _moveSlotToNeedsReview(slotId);
    }
  }

  Future<void> _moveSlotToNeedsReview(String slotId) async {
    try {
      await _carouselSlots.markNeedsReview(slotId);
    } on Object {
      // Preserve the original error. If this follow-up status write fails, the
      // slot still must not be reopened as loaded automatically.
    }
  }
}
