import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';

class ControllerLifecycleService {
  ControllerLifecycleService({
    required this._controller,
    required this._commandRepository,
    required this._doseLog,
    required this._carouselSlots,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const manualTestDoseId = 'manual-test';

  final ControllerGateway _controller;
  final LocalControllerCommandRepository _commandRepository;
  final DoseLogRepository _doseLog;
  final CarouselSlotRepository _carouselSlots;
  final DateTime Function() _now;
  final Set<String> _activeDispenseKeys = <String>{};

  Future<void> requestManualDispenseTest() {
    return _runDispense(
      commandType: ControllerCommandType.dispenseTest,
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
    final activeKeys = <String>{'dose:$doseId'};
    if (slotId != null) {
      activeKeys.add('slot:$slotId');
    }
    if (activeKeys.any(_activeDispenseKeys.contains)) {
      throw StateError(
        'A dispense request is already in progress for this dose.',
      );
    }
    _activeDispenseKeys.addAll(activeKeys);

    var controllerMoved = false;
    DateTime? acceptedAt;
    final sentAt = _current();
    try {
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
        await _controller.requestDispense(doseId: doseId);
        controllerMoved = true;
        acceptedAt = _current();
        await _commandRepository.appendEvent(
          session.id,
          ControllerCommandEventType.ack,
          occurredAt: acceptedAt,
        );
        await _commandRepository.updateSessionState(
          session.id,
          ControllerCommandSessionState.accepted,
          acceptedAt: acceptedAt,
          updatedAt: acceptedAt,
        );

        final resolvedAt = _current();
        await _commandRepository.appendEvent(
          session.id,
          ControllerCommandEventType.servoDone,
          occurredAt: resolvedAt,
        );
        if (slotId != null) {
          await _carouselSlots.markDispensed(slotId);
        }
        await _doseLog.addEvent(
          DoseLogEvent.controllerDispenseSucceeded(
            doseId: doseId,
            occurredAt: resolvedAt,
          ),
        );
        await _commandRepository.updateSessionState(
          session.id,
          ControllerCommandSessionState.succeeded,
          acceptedAt: acceptedAt,
          resolvedAt: resolvedAt,
          updatedAt: resolvedAt,
        );
      } on Object catch (error) {
        final failedAt = _current();
        if (error is ControllerCommandRejectedException) {
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
          if (slotId != null) {
            await _carouselSlots.markLoaded(slotId);
          }
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
          if (slotId != null) {
            await _carouselSlots.markLoaded(slotId);
          }
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
          if (slotId != null) {
            await _carouselSlots.markLoaded(slotId);
          }
        } else if (error is ControllerCommandTimeoutException) {
          acceptedAt ??= failedAt;
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.ack,
            occurredAt: acceptedAt,
          );
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          if (slotId != null) {
            await _moveSlotToNeedsReview(slotId);
          }
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.timedOut,
            acceptedAt: acceptedAt,
            updatedAt: failedAt,
          );
        } else if (error is ControllerCommandJamException) {
          acceptedAt ??= failedAt;
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.ack,
            occurredAt: acceptedAt,
          );
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          if (slotId != null) {
            await _moveSlotToNeedsReview(slotId);
          }
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.failed,
            acceptedAt: acceptedAt,
            failureReason: ControllerCommandFailureReason.jam,
            updatedAt: failedAt,
          );
        } else if (error is ControllerCommandInterruptedException) {
          acceptedAt ??= failedAt;
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.ack,
            occurredAt: acceptedAt,
          );
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.offline,
            occurredAt: failedAt,
            details: error.toString(),
          );
          if (slotId != null) {
            await _moveSlotToNeedsReview(slotId);
          }
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
            acceptedAt: acceptedAt,
            failureReason: ControllerCommandFailureReason.disconnect,
            updatedAt: failedAt,
          );
        } else if (controllerMoved) {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          if (slotId != null) {
            await _moveSlotToNeedsReview(slotId);
          }
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
            acceptedAt: acceptedAt ?? failedAt,
            updatedAt: failedAt,
          );
        } else {
          await _commandRepository.appendEvent(
            session.id,
            ControllerCommandEventType.controllerError,
            occurredAt: failedAt,
            details: error.toString(),
          );
          if (slotId != null) {
            await _moveSlotToNeedsReview(slotId);
          }
          await _commandRepository.updateSessionState(
            session.id,
            ControllerCommandSessionState.interrupted,
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

  Future<void> _moveSlotToNeedsReview(String slotId) async {
    try {
      await _carouselSlots.markNeedsReview(slotId);
    } on Object {
      // Preserve the original error. If this follow-up status write fails, the
      // slot still must not be reopened as loaded automatically.
    }
  }
}
