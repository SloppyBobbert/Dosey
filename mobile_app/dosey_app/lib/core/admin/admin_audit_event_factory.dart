import 'dart:convert';

import 'package:dosey_app/core/audit/admin_audit_event.dart';

class AdminAuditEventFactory {
  const AdminAuditEventFactory();

  AdminAuditEvent prescriptionSaved({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.prescriptionSaved,
    targetType: AdminAuditTargetType.prescription,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent prescriptionDeleted({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.prescriptionDeleted,
    targetType: AdminAuditTargetType.prescription,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent prescriptionRefillAdded({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.prescriptionRefillAdded,
    targetType: AdminAuditTargetType.prescription,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent scheduleSaved({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.scheduleSaved,
    targetType: AdminAuditTargetType.reminderSchedule,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent scheduleDeleted({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.scheduleDeleted,
    targetType: AdminAuditTargetType.reminderSchedule,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent scheduleProfileSaved({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.scheduleProfileSaved,
    targetType: AdminAuditTargetType.scheduleProfile,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent activeScheduleProfileChanged({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.activeScheduleProfileChanged,
    targetType: AdminAuditTargetType.scheduleProfile,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent carouselSlotAssigned({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.carouselSlotAssigned,
    targetType: AdminAuditTargetType.carouselSlot,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent carouselSlotLoaded({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.carouselSlotLoaded,
    targetType: AdminAuditTargetType.carouselSlot,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent carouselSlotNeedsReviewMarked({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.carouselSlotNeedsReviewMarked,
    targetType: AdminAuditTargetType.carouselSlot,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );
  AdminAuditEvent pinEnabled({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.pinEnabled,
    targetType: AdminAuditTargetType.pin,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
  );
  AdminAuditEvent pinChanged({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.pinChanged,
    targetType: AdminAuditTargetType.pin,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
  );
  AdminAuditEvent pinDisabled({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.pinDisabled,
    targetType: AdminAuditTargetType.pin,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
  );

  AdminAuditEvent maintenanceEntered({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.maintenanceEntered,
    targetType: AdminAuditTargetType.maintenance,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    occurredAt: occurredAt,
  );

  AdminAuditEvent householdProfileUpdated({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) {
    return _build(
      eventType: AdminAuditEventType.householdProfileUpdated,
      targetType: AdminAuditTargetType.household,
      actor: actor,
      sourceDeviceRole: sourceDeviceRole,
      summary: summary,
      occurredAt: occurredAt,
      details: details,
    );
  }

  AdminAuditEvent householdCreated({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    required String robotDisplayName,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.householdCreated,
    targetType: AdminAuditTargetType.household,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    targetId: targetId,
    summary: summary,
    details: {'robotDisplayName': robotDisplayName},
    occurredAt: occurredAt,
  );

  AdminAuditEvent householdInvitationGenerated({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    required String invitedEmail,
    required DateTime expiresAt,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.householdInvitationGenerated,
    targetType: AdminAuditTargetType.household,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    targetId: targetId,
    summary: summary,
    details: {
      'invitedEmail': invitedEmail,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    },
    occurredAt: occurredAt,
  );

  AdminAuditEvent householdMemberRemoved({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    required String removedAccountId,
    required String removedLabel,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.householdMemberRemoved,
    targetType: AdminAuditTargetType.household,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    targetId: targetId,
    summary: summary,
    details: {
      'removedAccountId': removedAccountId,
      'removedLabel': removedLabel,
    },
    occurredAt: occurredAt,
  );

  AdminAuditEvent householdLeft({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.householdLeft,
    targetType: AdminAuditTargetType.household,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    targetId: targetId,
    summary: summary,
    occurredAt: occurredAt,
  );

  AdminAuditEvent pairingCodeGenerated({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.pairingCodeGenerated,
    targetType: AdminAuditTargetType.robot,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadConfirmed({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadConfirmed,
    targetType: AdminAuditTargetType.carouselLoadSession,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadPhysicallyUnloaded({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadPhysicallyUnloaded,
    targetType: AdminAuditTargetType.carouselLoadSession,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadMarkedStale({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadMarkedStale,
    targetType: AdminAuditTargetType.carouselLoadSession,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadShortageCreated({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadShortageCreated,
    targetType: AdminAuditTargetType.medicationShortageAlert,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadShortageRecognized({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadShortageRecognized,
    targetType: AdminAuditTargetType.medicationShortageAlert,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadShortageResolved({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadShortageResolved,
    targetType: AdminAuditTargetType.medicationShortageAlert,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent guidedLoadShortagePastDue({
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String targetId,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
  }) => _build(
    eventType: AdminAuditEventType.guidedLoadShortagePastDue,
    targetType: AdminAuditTargetType.medicationShortageAlert,
    actor: actor,
    sourceDeviceRole: sourceDeviceRole,
    summary: summary,
    details: details,
    occurredAt: occurredAt,
    targetId: targetId,
  );

  AdminAuditEvent _build({
    required AdminAuditEventType eventType,
    required AdminAuditTargetType targetType,
    required AdminAuditActorIdentity actor,
    required String sourceDeviceRole,
    required String summary,
    Map<String, Object?>? details,
    DateTime? occurredAt,
    String? targetId,
  }) {
    return AdminAuditEvent(
      eventType: eventType,
      targetType: targetType,
      targetId: targetId,
      actorType: actor.actorType,
      actorUserId: actor.actorUserId,
      actorLabel: actor.actorLabel,
      sourceDeviceRole: sourceDeviceRole,
      summary: summary,
      detailsJson: details == null ? null : jsonEncode(details),
      occurredAt: (occurredAt ?? DateTime.now()).toUtc(),
    );
  }
}
