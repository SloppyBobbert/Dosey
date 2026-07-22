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
  householdUpdated,
  robotHubUpdated,
}

enum AdminAuditTargetType {
  prescription,
  reminderSchedule,
  scheduleProfile,
  carouselSlot,
  household,
  robotHub,
  pin,
}

enum AdminAuditActorType { localAdmin, signedInUser, caregiver, system }

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.eventType,
    required this.targetType,
    required this.actorType,
    required this.actorLabel,
    required this.sourceDeviceRole,
    required this.summary,
    required this.occurredAt,
    this.targetId,
    this.actorUserId,
    this.detailsJson,
    this.cloudEventId,
    this.lastSyncedAt,
  });

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
