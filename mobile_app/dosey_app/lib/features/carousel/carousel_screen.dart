import 'dart:convert';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_planner.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/active_profile_schedules_stream.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/shared/protected_admin_ui.dart';
import 'package:flutter/material.dart';

part 'carousel_refill_countdown.dart';

class CarouselScreen extends StatefulWidget {
  const CarouselScreen({super.key});

  @override
  State<CarouselScreen> createState() => _CarouselScreenState();
}

class _CarouselScreenState extends State<CarouselScreen> {
  final _slotController = TextEditingController();

  @override
  void dispose() {
    _slotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<List<Prescription>>(
      stream: dependencies.prescriptions.watchPrescriptions(),
      builder: (context, prescriptionSnapshot) {
        final prescriptions =
            prescriptionSnapshot.data ?? const <Prescription>[];
        final prescriptionsById = {
          for (final prescription in prescriptions)
            prescription.id: prescription,
        };

        return StreamBuilder<ScheduleProfile?>(
          stream: dependencies.scheduleProfiles.watchActiveProfile(),
          builder: (context, profileSnapshot) {
            final activeProfile = profileSnapshot.data;
            return StreamBuilder<List<ReminderSchedule>>(
              stream: watchActiveProfileSchedules(
                dependencies.reminders,
                activeProfile,
              ),
              builder: (context, scheduleSnapshot) {
                final schedules =
                    scheduleSnapshot.data ?? const <ReminderSchedule>[];
                return StreamBuilder<List<CarouselSlot>>(
                  stream: activeProfile == null
                      ? Stream<List<CarouselSlot>>.value(const <CarouselSlot>[])
                      : dependencies.carouselSlots.watchSlots(
                          profileId: activeProfile.id,
                        ),
                  builder: (context, slotSnapshot) {
                    final slotRows =
                        slotSnapshot.data ?? const <CarouselSlot>[];
                    final scheduleIds = {
                      for (final schedule in schedules)
                        if (schedule.isEnabled) schedule.id,
                    };
                    final slots = slotRows
                        .where((slot) => scheduleIds.contains(slot.scheduleId))
                        .toList();
                    // Hide slots for disabled or inactive-profile schedules so
                    // this screen matches what Today can actually dispense.
                    return StreamBuilder<AppDeviceRole>(
                      stream: dependencies.effectiveRole.watchDeviceRole(),
                      builder: (context, roleSnapshot) {
                        return StreamBuilder<CarouselLoadSession?>(
                          stream: activeProfile == null
                              ? Stream<CarouselLoadSession?>.value(null)
                              : dependencies.guidedCarouselLoads
                                    .watchActiveLoad(activeProfile.id),
                          builder: (context, activeLoadSnapshot) {
                            return StreamBuilder<
                              List<MedicationShortageAlertRow>
                            >(
                              stream: activeProfile == null
                                  ? Stream<
                                      List<MedicationShortageAlertRow>
                                    >.value(
                                      const <MedicationShortageAlertRow>[],
                                    )
                                  : dependencies.guidedCarouselLoads
                                        .watchActiveShortageAlerts(
                                          activeProfile.id,
                                        ),
                              builder: (context, shortageSnapshot) {
                                return StreamBuilder<ControllerSnapshot>(
                                  stream: dependencies.controller
                                      .watchController(),
                                  builder: (context, controllerSnapshot) {
                                    final controller =
                                        controllerSnapshot.data ??
                                        const ControllerSnapshot.disconnected();
                                    final canRequestDispense =
                                        _canRequestDispense(
                                          roleSnapshot.data,
                                          controller,
                                        );
                                    final activeLoad = activeLoadSnapshot.data;
                                    final shortageAlerts =
                                        shortageSnapshot.data ??
                                        const <MedicationShortageAlertRow>[];
                                    final activeShortage =
                                        _highestPriorityShortageAlert(
                                          shortageAlerts,
                                        );
                                    return ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        18,
                                        16,
                                        24,
                                      ),
                                      children: [
                                        _CarouselHeader(slots: slots),
                                        const SizedBox(height: 12),
                                        _GuidedLoadActionCard(
                                          activeProfile: activeProfile,
                                          activeLoad: activeLoad,
                                          activeShortage: activeShortage,
                                          onStartLoading: activeProfile == null
                                              ? null
                                              : () => _showRefillEntry(
                                                  context,
                                                  activeProfile: activeProfile,
                                                  activeLoad: activeLoad,
                                                  schedules: schedules,
                                                  prescriptionsById:
                                                      prescriptionsById,
                                                ),
                                        ),
                                        if (activeShortage != null) ...[
                                          const SizedBox(height: 12),
                                          _UrgentShortageCard(
                                            alert: activeShortage,
                                            canContinueLoading:
                                                activeProfile != null &&
                                                _canContinueLoadingFromShortage(
                                                  activeLoad: activeLoad,
                                                  alert: activeShortage,
                                                  schedules: schedules,
                                                  prescriptionsById:
                                                      prescriptionsById,
                                                ),
                                            onAcknowledge: () =>
                                                _acknowledgeShortage(
                                                  context,
                                                  activeShortage.id,
                                                ),
                                            onContinueLoading:
                                                activeProfile == null
                                                ? null
                                                : () => _showTopOffFlow(
                                                    context,
                                                    activeProfile:
                                                        activeProfile,
                                                    activeLoad: activeLoad,
                                                    schedules: schedules,
                                                    prescriptionsById:
                                                        prescriptionsById,
                                                    sourceAlert: activeShortage,
                                                  ),
                                            onUseFullReload:
                                                activeProfile == null
                                                ? null
                                                : () => _showFullReloadFlow(
                                                    context,
                                                    activeProfile:
                                                        activeProfile,
                                                    activeLoad: activeLoad,
                                                    schedules: schedules,
                                                    prescriptionsById:
                                                        prescriptionsById,
                                                  ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        const _PrototypeSafetyCard(),
                                        const SizedBox(height: 12),
                                        _AssignmentCard(
                                          slotController: _slotController,
                                          activeProfile: activeProfile,
                                          schedules: schedules,
                                          slots: slots,
                                          prescriptionsById: prescriptionsById,
                                        ),
                                        const SizedBox(height: 12),
                                        _RefillCountdownCard(slots: slots),
                                        const SizedBox(height: 12),
                                        if (slots.isEmpty)
                                          const Card(
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text(
                                                'No slots assigned yet.',
                                              ),
                                            ),
                                          )
                                        else
                                          for (final slot in slots)
                                            _SlotCard(
                                              slot: slot,
                                              schedule: _scheduleForSlot(
                                                schedules,
                                                slot,
                                              ),
                                              prescription:
                                                  prescriptionsById[slot
                                                      .prescriptionId],
                                              canRequestDispense:
                                                  canRequestDispense,
                                            ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static bool _canRequestDispense(
    AppDeviceRole? storedRole,
    ControllerSnapshot controller,
  ) {
    final platform = currentAppDevicePlatform();
    final role = storedRole != null && storedRole.isAllowedOn(platform)
        ? storedRole
        : AppDeviceRole.defaultFor(platform);
    return role.canHostRobot && controller.canRequestDispense;
  }

  static ReminderSchedule? _scheduleForSlot(
    List<ReminderSchedule> schedules,
    CarouselSlot slot,
  ) {
    for (final schedule in schedules) {
      if (schedule.id == slot.scheduleId) return schedule;
    }
    return null;
  }

  static String doseIdForToday(String scheduleId) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$scheduleId:${now.year}-$month-$day';
  }

  static MedicationShortageAlertRow? _highestPriorityShortageAlert(
    List<MedicationShortageAlertRow> alerts,
  ) {
    if (alerts.isEmpty) {
      return null;
    }

    MedicationShortageAlertRow? pastDue;
    MedicationShortageAlertRow? active;
    for (final alert in alerts) {
      if (alert.status == 'past_due') {
        pastDue ??= alert;
        continue;
      }
      if (alert.status == 'active') {
        active ??= alert;
      }
    }
    return pastDue ?? active;
  }

  Future<void> _showRefillEntry(
    BuildContext context, {
    required ScheduleProfile activeProfile,
    required CarouselLoadSession? activeLoad,
    required List<ReminderSchedule> schedules,
    required Map<String, Prescription> prescriptionsById,
  }) async {
    final action = await showModalBottomSheet<_RefillEntryAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RefillEntrySheet(activeLoad: activeLoad),
    );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _RefillEntryAction.topOff:
        await _showTopOffFlow(
          context,
          activeProfile: activeProfile,
          activeLoad: activeLoad,
          schedules: schedules,
          prescriptionsById: prescriptionsById,
        );
      case _RefillEntryAction.fullReload:
        await _showFullReloadFlow(
          context,
          activeProfile: activeProfile,
          activeLoad: activeLoad,
          schedules: schedules,
          prescriptionsById: prescriptionsById,
        );
    }
  }

  Future<void> _showTopOffFlow(
    BuildContext context, {
    required ScheduleProfile activeProfile,
    required CarouselLoadSession? activeLoad,
    required List<ReminderSchedule> schedules,
    required Map<String, Prescription> prescriptionsById,
    MedicationShortageAlertRow? sourceAlert,
  }) async {
    final load = activeLoad;
    if (load == null) {
      _showMessage(
        context,
        'Top-off needs an active load. Use Full Reload instead.',
      );
      return;
    }
    if (load.status == CarouselLoadSessionStatus.stale) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _TopOffBlockedStaleSheet(
          onUseFullReload: () {
            Navigator.of(context).pop();
            _showFullReloadFlow(
              this.context,
              activeProfile: activeProfile,
              activeLoad: activeLoad,
              schedules: schedules,
              prescriptionsById: prescriptionsById,
            );
          },
        ),
      );
      return;
    }

    final plan = GuidedCarouselLoadPlanner().buildTopOffPlan(
      activeSession: load,
      medications: _buildFutureMedications(
        schedules: schedules,
        prescriptionsById: prescriptionsById,
        now: DateTime.now(),
      ),
      now: DateTime.now(),
    );

    if (!plan.isValid) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _TopOffNotAvailableSheet(
          reason: plan.invalidReason,
          onUseFullReload: () {
            Navigator.of(context).pop();
            _showFullReloadFlow(
              this.context,
              activeProfile: activeProfile,
              activeLoad: activeLoad,
              schedules: schedules,
              prescriptionsById: prescriptionsById,
            );
          },
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TopOffFlowSheet(
        activeProfile: activeProfile,
        activeLoad: load,
        plan: plan,
        sourceAlert: sourceAlert,
      ),
    );
  }

  Future<void> _showFullReloadFlow(
    BuildContext context, {
    required ScheduleProfile activeProfile,
    required CarouselLoadSession? activeLoad,
    required List<ReminderSchedule> schedules,
    required Map<String, Prescription> prescriptionsById,
  }) async {
    final plan = GuidedCarouselLoadPlanner().buildFullReloadPlan(
      medications: _buildFutureMedications(
        schedules: schedules,
        prescriptionsById: prescriptionsById,
        now: DateTime.now(),
      ),
      now: DateTime.now(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FullReloadFlowSheet(
        activeProfile: activeProfile,
        activeLoad: activeLoad,
        plan: plan,
      ),
    );
  }

  bool _canContinueLoadingFromShortage({
    required CarouselLoadSession? activeLoad,
    required MedicationShortageAlertRow alert,
    required List<ReminderSchedule> schedules,
    required Map<String, Prescription> prescriptionsById,
  }) {
    if (activeLoad == null ||
        activeLoad.status != CarouselLoadSessionStatus.confirmed ||
        activeLoad.id != alert.loadSessionId ||
        !alert.scheduledAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }
    final plan = GuidedCarouselLoadPlanner().buildTopOffPlan(
      activeSession: activeLoad,
      medications: _buildFutureMedications(
        schedules: schedules,
        prescriptionsById: prescriptionsById,
        now: DateTime.now(),
      ),
      now: DateTime.now(),
    );
    return plan.isValid && _plannedTopOffFillableSlots(plan).isNotEmpty;
  }

  Future<void> _acknowledgeShortage(
    BuildContext context,
    String alertId,
  ) async {
    final dependencies = DoseyAppScope.of(context);
    await dependencies.guidedCarouselLoads.recognizeShortageAlert(
      alertId,
      recognizedAt: DateTime.now(),
    );
  }

  List<CarouselDoseBundleMedication> _buildFutureMedications({
    required List<ReminderSchedule> schedules,
    required Map<String, Prescription> prescriptionsById,
    required DateTime now,
  }) {
    final medications = <CarouselDoseBundleMedication>[];
    final localNow = now.toLocal();
    for (final schedule in schedules) {
      if (!schedule.isEnabled || schedule.prescriptionId == null) {
        continue;
      }
      final prescription = prescriptionsById[schedule.prescriptionId];
      if (prescription == null) {
        continue;
      }
      var scheduledAt = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        schedule.hour,
        schedule.minute,
      );
      while (!scheduledAt.isAfter(localNow)) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }
      for (
        var index = 0;
        index < GuidedCarouselLoadPlanner.capacity;
        index += 1
      ) {
        medications.add(
          CarouselDoseBundleMedication(
            prescriptionId: prescription.id,
            prescriptionName: prescription.name,
            scheduleId: schedule.id,
            scheduledAt: scheduledAt.toUtc(),
            availableDoses: prescription.availableDoses,
            guidedPillIcon: prescription.guidedPillIcon,
            doseCount: prescription.defaultDoseCountPerDose,
            createdAt: prescription.createdAt,
            updatedAt: prescription.updatedAt,
          ),
        );
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }
    }
    return medications;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static List<int> _plannedTopOffFillableSlots(GuidedCarouselLoadPlan plan) {
    return plan.slots
        .where((slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.loaded)
        .map((slot) => slot.slotNumber)
        .toList(growable: false);
  }
}

class _CarouselHeader extends StatelessWidget {
  const _CarouselHeader({required this.slots});

  final List<CarouselSlot> slots;

  @override
  Widget build(BuildContext context) {
    final loaded = slots
        .where((slot) => slot.status == CarouselSlotStatus.loaded)
        .length;
    final readyToDispense = loaded;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.onTertiaryContainer,
                  foregroundColor: colorScheme.tertiaryContainer,
                  child: const Icon(Icons.view_carousel_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loading bay',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Daviky carousel',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Daviky loading',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$loaded loaded / ${slots.length} assigned',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loading only prepares compartments. Dosey still needs manual confirmation before a dose is marked taken.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CarouselHeroChip(
                  icon: Icons.inventory_2_outlined,
                  label: '${slots.length} assigned',
                ),
                _CarouselHeroChip(
                  icon: Icons.check_circle_outline,
                  label: '$loaded loaded',
                ),
                _CarouselHeroChip(
                  icon: Icons.play_circle_outline,
                  label: '$readyToDispense ready to dispense',
                ),
                const _CarouselHeroChip(
                  icon: Icons.route_outlined,
                  label: 'Feeds dispense flow',
                ),
                const _CarouselHeroChip(
                  icon: Icons.science_outlined,
                  label: 'Prototype loading',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselHeroChip extends StatelessWidget {
  const _CarouselHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onTertiaryContainer.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RefillEntryAction { topOff, fullReload }

class _GuidedLoadActionCard extends StatelessWidget {
  const _GuidedLoadActionCard({
    required this.activeProfile,
    required this.activeLoad,
    required this.activeShortage,
    required this.onStartLoading,
  });

  final ScheduleProfile? activeProfile;
  final CarouselLoadSession? activeLoad;
  final MedicationShortageAlertRow? activeShortage;
  final VoidCallback? onStartLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = activeProfile != null;
    final currentPosition = activeLoad?.currentPosition;
    final isStaleLoad = activeLoad?.status == CarouselLoadSessionStatus.stale;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.onPrimaryContainer,
                  foregroundColor: colorScheme.primaryContainer,
                  child: const Icon(Icons.restart_alt_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guided carousel loading',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isStaleLoad
                            ? 'The saved load changed and now needs review before any top-off. Use Full Reload after you review the carousel.'
                            : activeShortage != null
                            ? 'A shortage is active. Review loading before the next dispense.'
                            : 'Start from START/home, review the carousel, and record refill changes here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CarouselHeroChip(
                  icon: Icons.home_outlined,
                  label: currentPosition == null || currentPosition.isStart
                      ? 'START/home ready'
                      : 'Saved position ${currentPosition.value}',
                ),
                _CarouselHeroChip(
                  icon: Icons.layers_outlined,
                  label: activeLoad == null
                      ? 'No active load'
                      : activeLoad!.mode.name,
                ),
                if (isStaleLoad)
                  const _CarouselHeroChip(
                    icon: Icons.warning_amber_rounded,
                    label: 'Load needs review',
                  ),
                _CarouselHeroChip(
                  icon: Icons.lock_clock_outlined,
                  label: 'Local only',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartLoading,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Start refill/loading'),
              ),
            ),
            if (!isReady) ...[
              const SizedBox(height: 8),
              Text(
                'Choose an active schedule profile before guided loading.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UrgentShortageCard extends StatelessWidget {
  const _UrgentShortageCard({
    required this.alert,
    required this.canContinueLoading,
    required this.onAcknowledge,
    required this.onContinueLoading,
    required this.onUseFullReload,
  });

  final MedicationShortageAlertRow alert;
  final bool canContinueLoading;
  final VoidCallback onAcknowledge;
  final VoidCallback? onContinueLoading;
  final VoidCallback? onUseFullReload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urgent shortage',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _shortageMedicationLabel(alert),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  'Scheduled ${_formatAlertTime(alert.scheduledAt)}',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
                Text(
                  'Slot ${alert.slotNumber}',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.status == 'past_due'
                  ? 'This local-only shortage is still unresolved and past due on this phone. Dosey is not sending remote shortage updates yet.'
                  : 'Local-only alert on this phone. Dosey is not sending remote shortage updates yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This shortage stays pinned in Robot Face until loading is handled here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: alert.recognizedAt == null ? onAcknowledge : null,
                  child: Text(
                    alert.recognizedAt == null ? 'Mark seen' : 'Seen',
                  ),
                ),
                if (canContinueLoading)
                  FilledButton(
                    onPressed: onContinueLoading,
                    child: const Text('Resolve and continue loading'),
                  )
                else
                  FilledButton.tonal(
                    onPressed: onUseFullReload,
                    child: const Text('Use Full Reload instead'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RefillEntrySheet extends StatelessWidget {
  const _RefillEntrySheet({required this.activeLoad});

  final CarouselLoadSession? activeLoad;

  @override
  Widget build(BuildContext context) {
    final isStaleLoad = activeLoad?.status == CarouselLoadSessionStatus.stale;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a refill path',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                isStaleLoad
                    ? 'Top-off is blocked until the stale load is reviewed. Full Reload clears the carousel first.'
                    : 'Top-off keeps the current load. Full Reload clears the carousel first.',
              ),
              const SizedBox(height: 16),
              _EntryOptionTile(
                title: 'Top off empty slots',
                subtitle: activeLoad == null
                    ? 'Needs an active guided load to preserve the saved position.'
                    : isStaleLoad
                    ? 'This saved load needs review or Full Reload before top-off can continue.'
                    : 'Start at START/home, fill the empty tail, then return to the saved position.',
                icon: Icons.auto_awesome_motion_outlined,
                onTap: activeLoad == null || isStaleLoad
                    ? null
                    : () =>
                          Navigator.of(context).pop(_RefillEntryAction.topOff),
              ),
              const SizedBox(height: 12),
              _EntryOptionTile(
                title: 'Empty and reload all',
                subtitle:
                    'Starts at START/home and ends at START/home. Use this for unload-first reloads or broken top-off states.',
                icon: Icons.refresh_rounded,
                onTap: () =>
                    Navigator.of(context).pop(_RefillEntryAction.fullReload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryOptionTile extends StatelessWidget {
  const _EntryOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _TopOffNotAvailableSheet extends StatelessWidget {
  const _TopOffNotAvailableSheet({
    required this.reason,
    required this.onUseFullReload,
  });

  final GuidedCarouselLoadInvalidReason? reason;
  final VoidCallback onUseFullReload;

  @override
  Widget build(BuildContext context) {
    final copy = switch (reason) {
      GuidedCarouselLoadInvalidReason.interiorEmptyGap =>
        'Top-off cannot continue because the carousel has an interior empty gap.',
      GuidedCarouselLoadInvalidReason.nonLoadedRetainedPrefix =>
        'Top-off cannot continue because the saved prefix includes review or error states.',
      GuidedCarouselLoadInvalidReason.nonContiguousRetainedPrefix =>
        'Top-off cannot continue because the saved positions are not contiguous from slot 1.',
      null => 'Top-off is not available for this load.',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use Full Reload instead',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(copy),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUseFullReload,
                child: const Text('Open Full Reload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopOffBlockedStaleSheet extends StatelessWidget {
  const _TopOffBlockedStaleSheet({required this.onUseFullReload});

  final VoidCallback onUseFullReload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top-off needs review first',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'This saved load is stale. Review the carousel and use Full Reload before you continue loading.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUseFullReload,
                child: const Text('Open Full Reload'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopOffFlowSheet extends StatefulWidget {
  const _TopOffFlowSheet({
    required this.activeProfile,
    required this.activeLoad,
    required this.plan,
    this.sourceAlert,
  });

  static const confirmButtonKey = ValueKey<String>('top-off-confirm-button');

  final ScheduleProfile activeProfile;
  final CarouselLoadSession activeLoad;
  final GuidedCarouselLoadPlan plan;
  final MedicationShortageAlertRow? sourceAlert;

  @override
  State<_TopOffFlowSheet> createState() => _TopOffFlowSheetState();
}

class _TopOffFlowSheetState extends State<_TopOffFlowSheet> {
  late final Set<int> _selectedSlots = <int>{};
  bool _isSubmitting = false;

  List<int> get _fillableSlots => widget.plan.slots
      .where((slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.loaded)
      .map((slot) => slot.slotNumber)
      .toList(growable: false);

  List<int> get _deferredEmptySlots => widget.plan.slots
      .where((slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.empty)
      .map((slot) => slot.slotNumber)
      .toList(growable: false);

  List<int> get _blockedShortageSlots => widget.plan.slots
      .where((slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.shortage)
      .map((slot) => slot.slotNumber)
      .toList(growable: false);

  bool get _canConfirm =>
      _fillableSlots.isNotEmpty &&
      _selectedSlots.length == _fillableSlots.length;

  @override
  Widget build(BuildContext context) {
    final priorPosition = widget.plan.priorPosition ?? CarouselPosition.start;
    final currentPosition = widget.activeLoad.currentPosition;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top off empty slots',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.sourceAlert == null
                    ? 'Start from START/home. Tap only the compartments this top-off will fill now. Then return the carousel to ${_positionLabel(priorPosition)} before you confirm.'
                    : 'This shortage can continue with a partial top-off. Start from START/home, fill only the compartments planned for this pass, then return to ${_positionLabel(priorPosition)} before you confirm.',
              ),
              const SizedBox(height: 16),
              _FlowCheckpointCard(
                title: 'Return checkpoint',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FlowStatusChip(
                          icon: Icons.my_location_outlined,
                          label:
                              'Current saved position ${_positionLabel(currentPosition)}',
                        ),
                        _FlowStatusChip(
                          icon: Icons.bookmark_outline,
                          label:
                              'Return to preserved position ${_positionLabel(priorPosition)}',
                          isAccent: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Top-off keeps the previous position metadata. Do not confirm until the carousel is back at that saved position.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Before you tap confirm, manually return the carousel to ${_positionLabel(priorPosition)}.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_blockedShortageSlots.isNotEmpty ||
                        _deferredEmptySlots.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_blockedShortageSlots.isNotEmpty)
                            _FlowStatusChip(
                              icon: Icons.warning_amber_rounded,
                              label:
                                  'Stops again at slot ${_blockedShortageSlots.first}',
                              isWarning: true,
                            ),
                          if (_deferredEmptySlots.isNotEmpty)
                            _FlowStatusChip(
                              icon: Icons.pause_circle_outline,
                              label:
                                  '${_deferredEmptySlots.length} later slots stay empty',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CarouselPlanView(
                slotStates: {
                  for (final slot in widget.plan.slots)
                    slot.slotNumber: _slotVisualStateForTopOff(
                      slot.status,
                      _selectedSlots.contains(slot.slotNumber),
                    ),
                },
                onSlotTap: (slotNumber) {
                  if (!_fillableSlots.contains(slotNumber)) {
                    return;
                  }
                  setState(() {
                    if (!_selectedSlots.add(slotNumber)) {
                      _selectedSlots.remove(slotNumber);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(
                _blockedShortageSlots.isEmpty && _deferredEmptySlots.isEmpty
                    ? 'Selected ${_selectedSlots.length} of ${_fillableSlots.length} planned compartments.'
                    : 'Selected ${_selectedSlots.length} of ${_fillableSlots.length} compartments planned for this pass. Later empty slots are not part of this continuation.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: _TopOffFlowSheet.confirmButtonKey,
                  onPressed: _isSubmitting || !_canConfirm ? null : _confirm,
                  child: Text(
                    'Return to ${_positionLabel(priorPosition)} and confirm top-off',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    final dependencies = DoseyAppScope.of(context);
    try {
      if (!mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (_) async {
          await dependencies.guidedCarouselLoads.confirmTopOff(
            sessionId:
                'guided-top-off-${DateTime.now().toUtc().microsecondsSinceEpoch}',
            profileId: widget.activeProfile.id,
            predecessorSessionId: widget.activeLoad.id,
            plan: widget.plan,
            startedAt: DateTime.now(),
            confirmedAt: DateTime.now(),
          );
        },
      );
      if (!mounted || !result.isSuccess) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Top-off saved. Loading still does not mark a dose taken.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _FullReloadFlowSheet extends StatefulWidget {
  const _FullReloadFlowSheet({
    required this.activeProfile,
    required this.activeLoad,
    required this.plan,
  });

  final ScheduleProfile activeProfile;
  final CarouselLoadSession? activeLoad;
  final GuidedCarouselLoadPlan plan;

  @override
  State<_FullReloadFlowSheet> createState() => _FullReloadFlowSheetState();
}

class _FullReloadFlowSheetState extends State<_FullReloadFlowSheet> {
  late final Set<int> _recoveredSlots = <int>{};
  bool _isUnloading = false;
  bool _isConfirming = false;
  bool _didUnload = false;

  bool get _canConfirmReload => widget.activeLoad == null || _didUnload;

  @override
  Widget build(BuildContext context) {
    final occupiedStates = <int, _CarouselPlanVisualState>{
      for (var slot = 1; slot <= GuidedCarouselLoadPlanner.capacity; slot += 1)
        slot: _didUnload || widget.activeLoad == null
            ? _CarouselPlanVisualState.empty
            : _fullReloadSlotVisualState(
                widget.activeLoad!.slots
                    .firstWhere((entry) => entry.slotNumber == slot)
                    .status,
                _recoveredSlots.contains(slot),
              ),
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Empty and reload all',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start at START/home. Full Reload finishes at START/home after the new load is confirmed.',
              ),
              const SizedBox(height: 16),
              if (widget.activeLoad != null && !_didUnload) ...[
                const _FlowCheckpointCard(
                  title: 'Unload first',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FlowStatusChip(
                            icon: Icons.home_outlined,
                            label: 'Start at START/home',
                          ),
                          _FlowStatusChip(
                            icon: Icons.lock_outline,
                            label: 'Reload stays locked until unload is saved',
                            isWarning: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Full Reload requires a separate persisted physical unload transaction first. The new load cannot be confirmed until this unload step is saved.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '1. Confirm physical unload',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap any compartments you physically returned to the bottle. Unselected doses move to review. This unload is saved separately and requires the action PIN.',
                ),
                const SizedBox(height: 12),
                _CarouselPlanView(
                  slotStates: occupiedStates,
                  onSlotTap: (slotNumber) {
                    final snapshot = widget.activeLoad!.slots.firstWhere(
                      (entry) => entry.slotNumber == slotNumber,
                    );
                    if (snapshot.status != CarouselLoadSlotStatus.loaded &&
                        snapshot.status != CarouselLoadSlotStatus.retained) {
                      return;
                    }
                    setState(() {
                      if (!_recoveredSlots.add(slotNumber)) {
                        _recoveredSlots.remove(slotNumber);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isUnloading ? null : _confirmUnload,
                    child: const Text('Confirm physical unload'),
                  ),
                ),
                const SizedBox(height: 18),
                const _ReloadLockedCard(),
              ] else ...[
                const _FlowCheckpointCard(
                  title: 'Empty carousel confirmed',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FlowStatusChip(
                            icon: Icons.check_circle_outline,
                            label: 'Unload saved',
                            isAccent: true,
                          ),
                          _FlowStatusChip(
                            icon: Icons.visibility_outlined,
                            label: 'Carousel should now look empty',
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Now confirm the new load. This reload starts at START/home and should end at START/home.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '2. Confirm the new load',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The carousel should look empty before you confirm the new load. Dosey still needs manual confirmation before a dose is marked taken.',
                ),
                const SizedBox(height: 12),
                _CarouselPlanView(slotStates: occupiedStates),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isConfirming || !_canConfirmReload
                        ? null
                        : _confirmReload,
                    child: const Text('Confirm empty and reload all'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnload() async {
    final activeLoad = widget.activeLoad;
    if (activeLoad == null) {
      return;
    }
    setState(() => _isUnloading = true);
    final dependencies = DoseyAppScope.of(context);
    try {
      final recoveredScheduleIds = activeLoad.slots
          .where((slot) => _recoveredSlots.contains(slot.slotNumber))
          .expand((slot) => slot.scheduleIds)
          .toList(growable: false);
      final result = await runProtectedAdminAction<void>(
        context,
        action: (_) async {
          await dependencies.guidedCarouselLoads.confirmPhysicalUnload(
            profileId: widget.activeProfile.id,
            activeSessionId: activeLoad.id,
            recoveredScheduleIds: recoveredScheduleIds,
            recoveredSlotNumbers: _recoveredSlots.toList(growable: false),
            occurredAt: DateTime.now(),
          );
        },
      );
      if (!mounted || !result.isSuccess) return;
      setState(() => _didUnload = true);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUnloading = false);
    }
  }

  Future<void> _confirmReload() async {
    setState(() => _isConfirming = true);
    final dependencies = DoseyAppScope.of(context);
    try {
      final result = await runProtectedAdminAction<void>(
        context,
        action: (_) async {
          await dependencies.guidedCarouselLoads.confirmFullLoad(
            sessionId:
                'guided-full-reload-${DateTime.now().toUtc().microsecondsSinceEpoch}',
            profileId: widget.activeProfile.id,
            plan: widget.plan,
            startedAt: DateTime.now(),
            confirmedAt: DateTime.now(),
          );
        },
      );
      if (!mounted || !result.isSuccess) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full reload saved. Keep the carousel at START/home.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }
}

enum _CarouselPlanVisualState {
  retained,
  empty,
  selectableEmpty,
  selectedEmpty,
  deferredEmpty,
  shortageBlocked,
  recovered,
}

class _CarouselPlanView extends StatelessWidget {
  const _CarouselPlanView({required this.slotStates, this.onSlotTap});

  final Map<int, _CarouselPlanVisualState> slotStates;
  final ValueChanged<int>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (
              var slot = 1;
              slot <= GuidedCarouselLoadPlanner.capacity;
              slot += 1
            )
              _CarouselPlanSlotChip(
                slotNumber: slot,
                state: slotStates[slot] ?? _CarouselPlanVisualState.empty,
                onTap: onSlotTap == null ? null : () => onSlotTap!(slot),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowCheckpointCard extends StatelessWidget {
  const _FlowCheckpointCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _FlowStatusChip extends StatelessWidget {
  const _FlowStatusChip({
    required this.icon,
    required this.label,
    this.isAccent = false,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isAccent;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isWarning
        ? colorScheme.errorContainer
        : isAccent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foreground = isWarning
        ? colorScheme.onErrorContainer
        : isAccent
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReloadLockedCard extends StatelessWidget {
  const _ReloadLockedCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reload confirmation stays locked until the physical unload transaction is saved.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselPlanSlotChip extends StatelessWidget {
  const _CarouselPlanSlotChip({
    required this.slotNumber,
    required this.state,
    this.onTap,
  });

  final int slotNumber;
  final _CarouselPlanVisualState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (state) {
      _CarouselPlanVisualState.retained => (
        const Color(0xFF143242),
        Colors.white,
        const Color(0x334EE6FF),
      ),
      _CarouselPlanVisualState.selectableEmpty => (
        const Color(0x1A4EE6FF),
        const Color(0xFF0B5366),
        const Color(0x664EE6FF),
      ),
      _CarouselPlanVisualState.selectedEmpty => (
        const Color(0xFF56EBC6),
        const Color(0xFF03221B),
        const Color(0xFF56EBC6),
      ),
      _CarouselPlanVisualState.deferredEmpty => (
        const Color(0x14FFD666),
        const Color(0xFF8A6514),
        const Color(0x66FFD666),
      ),
      _CarouselPlanVisualState.shortageBlocked => (
        const Color(0x1AFF728C),
        const Color(0xFF8E2841),
        const Color(0x66FF728C),
      ),
      _CarouselPlanVisualState.recovered => (
        const Color(0xFFB7F2D4),
        const Color(0xFF0A3827),
        const Color(0xFF56EBC6),
      ),
      _CarouselPlanVisualState.empty => (
        const Color(0x15FFFFFF),
        const Color(0xFF5C6679),
        const Color(0x33FFFFFF),
      ),
    };
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Ink(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            '$slotNumber',
            style: TextStyle(fontWeight: FontWeight.w800, color: foreground),
          ),
        ),
      ),
    );
  }
}

_CarouselPlanVisualState _slotVisualStateForTopOff(
  GuidedCarouselLoadPlanSlotStatus status,
  bool isSelected,
) {
  return switch (status) {
    GuidedCarouselLoadPlanSlotStatus.retained =>
      _CarouselPlanVisualState.retained,
    GuidedCarouselLoadPlanSlotStatus.loaded =>
      isSelected
          ? _CarouselPlanVisualState.selectedEmpty
          : _CarouselPlanVisualState.selectableEmpty,
    GuidedCarouselLoadPlanSlotStatus.shortage =>
      _CarouselPlanVisualState.shortageBlocked,
    GuidedCarouselLoadPlanSlotStatus.empty =>
      _CarouselPlanVisualState.deferredEmpty,
  };
}

_CarouselPlanVisualState _fullReloadSlotVisualState(
  CarouselLoadSlotStatus status,
  bool isRecovered,
) {
  if (status == CarouselLoadSlotStatus.loaded ||
      status == CarouselLoadSlotStatus.retained) {
    return isRecovered
        ? _CarouselPlanVisualState.recovered
        : _CarouselPlanVisualState.retained;
  }
  return _CarouselPlanVisualState.empty;
}

String _shortageMedicationLabel(MedicationShortageAlertRow alert) {
  try {
    final decoded = jsonDecode(alert.prescriptionNamesJson);
    if (decoded is List) {
      final labels = decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (labels.isNotEmpty) {
        return labels.join(' + ');
      }
    }
  } on FormatException {
    // Keep the stored value when legacy rows contain malformed JSON.
  }
  return alert.prescriptionNamesJson;
}

String _formatAlertTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _positionLabel(CarouselPosition position) {
  return position.isStart ? 'START/home' : 'slot ${position.value}';
}

class _PrototypeSafetyCard extends StatelessWidget {
  const _PrototypeSafetyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prototype loading safety',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Use candy, beads, dry beans, vitamins, or fake pills for prototype testing. Do not use real prescription medication in early tests.',
            ),
            const SizedBox(height: 6),
            Text(
              'Dosey does not verify pills, prescriptions, or swallowed doses.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.slotController,
    required this.activeProfile,
    required this.schedules,
    required this.slots,
    required this.prescriptionsById,
  });

  final TextEditingController slotController;
  final ScheduleProfile? activeProfile;
  final List<ReminderSchedule> schedules;
  final List<CarouselSlot> slots;
  final Map<String, Prescription> prescriptionsById;

  @override
  Widget build(BuildContext context) {
    final nextSchedule = _nextUnassignedSchedule();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign slots',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (activeProfile != null)
              Text('Active schedule: ${activeProfile!.name}')
            else
              const Text('No active schedule profile.'),
            const SizedBox(height: 10),
            if (schedules.isEmpty)
              const Text('No active schedules to load.')
            else if (nextSchedule == null)
              const Text('All active schedules have a carousel slot.')
            else ...[
              Text(_scheduleLabel(nextSchedule)),
              const SizedBox(height: 10),
              TextFormField(
                controller: slotController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Slot number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: activeProfile == null
                    ? null
                    : () => _assignNextDose(context, nextSchedule),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Assign next dose'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ReminderSchedule? _nextUnassignedSchedule() {
    final assignedScheduleIds = {for (final slot in slots) slot.scheduleId};
    for (final schedule in schedules) {
      // Only enabled schedules with a prescription id can become physical slots.
      if (schedule.isEnabled &&
          schedule.prescriptionId != null &&
          !assignedScheduleIds.contains(schedule.id)) {
        return schedule;
      }
    }
    return null;
  }

  String _scheduleLabel(ReminderSchedule schedule) {
    final prescription = prescriptionsById[schedule.prescriptionId];
    final label = prescription?.name ?? schedule.label;
    return '${schedule.timeLabel} · $label';
  }

  Future<void> _assignNextDose(
    BuildContext context,
    ReminderSchedule schedule,
  ) async {
    final dependencies = DoseyAppScope.of(context);
    final slotNumber = int.tryParse(slotController.text.trim());
    if (slotNumber == null) {
      _showMessage(context, 'Enter a slot number.');
      return;
    }
    final prescriptionId = schedule.prescriptionId;
    final profile = activeProfile;
    if (prescriptionId == null || profile == null) {
      _showMessage(context, 'Choose a scheduled prescription first.');
      return;
    }

    final now = DateTime.now().toUtc();
    try {
      final slot = CarouselSlot(
        id: '${profile.id}-${schedule.id}',
        slotNumber: slotNumber,
        prescriptionId: prescriptionId,
        scheduleId: schedule.id,
        profileId: profile.id,
        status: CarouselSlotStatus.assigned,
        createdAt: now,
        updatedAt: now,
      );
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!context.mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          await dependencies.carouselSlots.assignSlot(
            slot,
            auditEvent: const AdminAuditEventFactory().carouselSlotAssigned(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: slot.id,
              summary: 'Assigned carousel slot ${slot.slotNumber}.',
              details: {
                'scheduleId': slot.scheduleId,
                'prescriptionId': slot.prescriptionId,
              },
            ),
          );
        },
      );
      if (!result.isSuccess) return;
      slotController.clear();
      if (!context.mounted) return;
      _showMessage(context, 'Slot assigned.');
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message.toString());
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SlotCard extends StatefulWidget {
  const _SlotCard({
    required this.slot,
    required this.schedule,
    required this.prescription,
    required this.canRequestDispense,
  });

  final CarouselSlot slot;
  final ReminderSchedule? schedule;
  final Prescription? prescription;
  final bool canRequestDispense;

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  var _isDispensing = false;

  @override
  void didUpdateWidget(_SlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.id != widget.slot.id) {
      _isDispensing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(widget.slot.slotNumber.toString())),
        title: Text('Slot ${widget.slot.slotNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(_doseLabel), Text(widget.slot.status.label)],
        ),
        trailing: _SlotAction(
          status: widget.slot.status,
          onMarkLoaded: _isDispensing ? null : () => _markLoaded(context),
          onMarkNeedsReview: _isDispensing
              ? null
              : () => _markNeedsReview(context),
          onDispense: _isDispensing || !widget.canRequestDispense
              ? null
              : () => _dispense(context),
        ),
      ),
    );
  }

  Future<void> _markNeedsReview(BuildContext context) async {
    final dependencies = DoseyAppScope.of(context);
    try {
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!context.mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          await dependencies.carouselSlots.markNeedsReview(
            widget.slot.id,
            auditEvent: const AdminAuditEventFactory()
                .carouselSlotNeedsReviewMarked(
                  actor: actor,
                  sourceDeviceRole: sourceDeviceRole,
                  targetId: widget.slot.id,
                  summary:
                      'Marked slot ${widget.slot.slotNumber} for refill review.',
                ),
          );
        },
      );
      if (!result.isSuccess) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot marked for refill review.')),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  String get _doseLabel {
    final schedule = widget.schedule;
    final name =
        widget.prescription?.name ??
        schedule?.label ??
        widget.slot.prescriptionId;
    return schedule == null ? name : '${schedule.timeLabel} · $name';
  }

  Future<void> _markLoaded(BuildContext context) async {
    final dependencies = DoseyAppScope.of(context);
    try {
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!context.mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          await dependencies.carouselSlots.markLoaded(
            widget.slot.id,
            auditEvent: const AdminAuditEventFactory().carouselSlotLoaded(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: widget.slot.id,
              summary: 'Marked slot ${widget.slot.slotNumber} loaded.',
            ),
          );
        },
      );
      if (!result.isSuccess) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Slot marked loaded.')));
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _dispense(BuildContext context) async {
    if (_isDispensing) return;
    if (!await authorizeActionPin(context)) {
      return;
    }
    if (!context.mounted) return;
    setState(() {
      _isDispensing = true;
    });
    final dependencies = DoseyAppScope.of(context);
    try {
      // Dispense moves the carousel and logs controller progress only. It must
      // not mark the dose taken.
      await dependencies.controllerLifecycle.requestDoseDispense(
        slotId: widget.slot.id,
        doseId: _CarouselScreenState.doseIdForToday(widget.slot.scheduleId),
        scheduleId: widget.slot.scheduleId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dispense command logged. Confirm taken only after the dose is verified.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dispense failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isDispensing = false;
        });
      }
    }
  }
}

class _SlotAction extends StatelessWidget {
  const _SlotAction({
    required this.status,
    required this.onMarkLoaded,
    required this.onMarkNeedsReview,
    required this.onDispense,
  });

  final CarouselSlotStatus status;
  final VoidCallback? onMarkLoaded;
  final VoidCallback? onMarkNeedsReview;
  final VoidCallback? onDispense;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      CarouselSlotStatus.assigned => TextButton(
        onPressed: onMarkLoaded,
        child: const Text('Mark loaded'),
      ),
      CarouselSlotStatus.needsReview => TextButton(
        onPressed: onMarkLoaded,
        child: const Text('Mark loaded'),
      ),
      CarouselSlotStatus.loaded => TextButton(
        onPressed: onDispense,
        child: const Text('Dispense slot'),
      ),
      CarouselSlotStatus.dispensed => TextButton(
        onPressed: onMarkNeedsReview,
        child: const Text('Review refill'),
      ),
    };
  }
}
