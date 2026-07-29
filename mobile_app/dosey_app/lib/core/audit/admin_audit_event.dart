enum AdminAuditEventType {
  prescriptionSaved,
  prescriptionDeleted,
  prescriptionRefillAdded,
  scheduleSaved,
  scheduleDeleted,
  scheduleProfileSaved,
  activeScheduleProfileChanged,
  carouselSlotAssigned,
  carouselSlotLoaded,
  carouselSlotNeedsReviewMarked,
  pinEnabled,
  pinChanged,
  pinDisabled,
  householdProfileUpdated,
  householdCreated,
  householdInvitationGenerated,
  householdMemberRemoved,
  householdLeft,
  pairingCodeGenerated,
  guidedLoadConfirmed,
  guidedLoadPhysicallyUnloaded,
  guidedLoadMarkedStale,
  guidedLoadShortageCreated,
  guidedLoadShortageRecognized,
  guidedLoadShortageResolved,
  guidedLoadShortagePastDue,
  maintenanceEntered,
}

enum AdminAuditTargetType {
  prescription,
  reminderSchedule,
  scheduleProfile,
  carouselSlot,
  household,
  robot,
  pin,
  carouselLoadSession,
  medicationShortageAlert,
  maintenance,
}

enum AdminAuditActorType { localAdmin, signedInUser, caregiver, system }

class AdminAuditEvent {
  AdminAuditEvent({
    required this.eventType,
    required this.targetType,
    required this.actorType,
    required this.actorLabel,
    required this.sourceDeviceRole,
    required this.summary,
    required this.occurredAt,
    String? id,
    this.targetId,
    this.actorUserId,
    this.detailsJson,
    this.cloudEventId,
    this.lastSyncedAt,
  }) : id = id ?? _nextId();

  static int _idSequence = 0;

  static String _nextId() {
    final sequence = _idSequence++;
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return 'admin-audit-$timestamp-$sequence';
  }

  final String id;
  final AdminAuditEventType eventType;
  final AdminAuditTargetType targetType;
  final String? targetId;
  final AdminAuditActorType actorType;
  final String? actorUserId;
  final String actorLabel;
  final String sourceDeviceRole;
  final String summary;
  final String? detailsJson;
  final String? cloudEventId;
  final DateTime? lastSyncedAt;
  final DateTime occurredAt;
}

class AdminAuditActorIdentity {
  const AdminAuditActorIdentity({
    required this.actorType,
    required this.actorLabel,
    required this.actorProviderLabel,
    this.actorUserId,
  });

  final AdminAuditActorType actorType;
  final String? actorUserId;
  final String actorLabel;
  final String? actorProviderLabel;
}
