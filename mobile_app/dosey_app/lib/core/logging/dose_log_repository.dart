enum DoseLogEventKind { controllerDispenseSucceeded, doseTakenConfirmed, error }

class DoseLogEvent {
  const DoseLogEvent({
    required this.kind,
    required this.doseId,
    required this.occurredAt,
    required this.marksDoseTaken,
  });

  factory DoseLogEvent.controllerDispenseSucceeded({
    required String doseId,
    required DateTime occurredAt,
  }) {
    return DoseLogEvent(
      kind: DoseLogEventKind.controllerDispenseSucceeded,
      doseId: doseId,
      occurredAt: occurredAt,
      marksDoseTaken: false,
    );
  }

  final DoseLogEventKind kind;
  final String doseId;
  final DateTime occurredAt;
  final bool marksDoseTaken;
}

abstract interface class DoseLogRepository {
  Future<void> addEvent(DoseLogEvent event);

  Stream<List<DoseLogEvent>> watchEvents();
}
