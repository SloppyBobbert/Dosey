import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/features/shared/protected_admin_ui.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final prescriptions = dependencies.prescriptions;

    return StreamBuilder<List<Prescription>>(
      stream: prescriptions.watchPrescriptions(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Prescription>[];
        return StreamBuilder<List<ScheduleProfile>>(
          stream: dependencies.scheduleProfiles.watchProfiles(),
          builder: (context, profileSnapshot) {
            final profiles = profileSnapshot.data ?? const <ScheduleProfile>[];
            final activeProfileId = _activeProfileId(profiles);
            return StreamBuilder<List<ReminderSchedule>>(
              stream: dependencies.reminders.watchSchedules(),
              builder: (context, schedulesSnapshot) {
                final schedules =
                    schedulesSnapshot.data ?? const <ReminderSchedule>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _PrescriptionHeroCard(
                      prescriptionCount: items.length,
                      scheduledPrescriptionCount: _scheduledPrescriptionCount(
                        items,
                        schedules,
                      ),
                      onAddPrescription: () =>
                          _showPrescriptionSheet(context, prescriptions),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No prescriptions yet.'),
                              SizedBox(height: 6),
                              Text('Add your first prescription.'),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final prescription in items)
                        _PrescriptionTile(
                          prescription: prescription,
                          allPrescriptions: items,
                          activeProfileId: activeProfileId,
                          scheduleSummary: _scheduleSummaryFor(
                            prescription,
                            schedules,
                            profiles,
                            activeProfileId,
                          ),
                          prescriptions: prescriptions,
                          reminderSchedules: dependencies.reminderSchedules,
                        ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Summarizes schedule usage for one prescription without changing which
  /// profile is active for Today or robot-facing dose actions.
  static _PrescriptionScheduleSummary _scheduleSummaryFor(
    Prescription prescription,
    List<ReminderSchedule> schedules,
    List<ScheduleProfile> profiles,
    String activeProfileId,
  ) {
    final prescriptionSchedules = schedules
        .where((schedule) => schedule.prescriptionId == prescription.id)
        .toList();
    final activeSchedules =
        prescriptionSchedules
            .where((schedule) => schedule.profileId == activeProfileId)
            .toList()
          ..sort(_compareSchedulesByTime);
    final profileCount = prescriptionSchedules
        .map((schedule) => schedule.profileId)
        .toSet()
        .length;
    final details = _profileDetailsFor(
      prescriptionSchedules,
      profiles,
      activeProfileId,
    );

    return _PrescriptionScheduleSummary(
      activeTimes: [for (final schedule in activeSchedules) schedule.timeLabel],
      profileCount: profileCount,
      details: details,
    );
  }

  static String _activeProfileId(List<ScheduleProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isActive) return profile.id;
    }
    return profiles.isEmpty
        ? ReminderSchedule.defaultProfileId
        : profiles.first.id;
  }

  static int _scheduledPrescriptionCount(
    List<Prescription> prescriptions,
    List<ReminderSchedule> schedules,
  ) {
    final prescriptionIds = prescriptions.map((item) => item.id).toSet();
    // Count each prescription once even if it appears in several schedule
    // profiles or times.
    return schedules
        .where((schedule) => prescriptionIds.contains(schedule.prescriptionId))
        .map((schedule) => schedule.prescriptionId)
        .toSet()
        .length;
  }

  static List<_PrescriptionScheduleDetail> _profileDetailsFor(
    List<ReminderSchedule> schedules,
    List<ScheduleProfile> profiles,
    String activeProfileId,
  ) {
    final schedulesByProfile = <String, List<ReminderSchedule>>{};
    for (final schedule in schedules) {
      schedulesByProfile
          .putIfAbsent(schedule.profileId, () => [])
          .add(schedule);
    }

    final profileNames = {
      for (final profile in profiles) profile.id: profile.name,
    };
    final details = <_PrescriptionScheduleDetail>[];
    for (final entry in schedulesByProfile.entries) {
      final profileSchedules = entry.value..sort(_compareSchedulesByTime);
      details.add(
        _PrescriptionScheduleDetail(
          profileName: profileNames[entry.key] ?? entry.key,
          isActive: entry.key == activeProfileId,
          times: [for (final schedule in profileSchedules) schedule.timeLabel],
        ),
      );
    }

    details.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.profileName.compareTo(b.profileName);
    });
    return details;
  }

  static int _compareSchedulesByTime(ReminderSchedule a, ReminderSchedule b) {
    final hourComparison = a.hour.compareTo(b.hour);
    if (hourComparison != 0) return hourComparison;
    return a.minute.compareTo(b.minute);
  }

  static Future<void> _showPrescriptionSheet(
    BuildContext context,
    PrescriptionRepository prescriptions, {
    Prescription? prescription,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PrescriptionSheet(
        prescriptions: prescriptions,
        prescription: prescription,
      ),
    );
  }
}

class _PrescriptionHeroCard extends StatelessWidget {
  const _PrescriptionHeroCard({
    required this.prescriptionCount,
    required this.scheduledPrescriptionCount,
    required this.onAddPrescription,
  });

  final int prescriptionCount;
  final int scheduledPrescriptionCount;
  final VoidCallback onAddPrescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medication cabinet',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prescriptions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddPrescription,
                  icon: const Icon(Icons.add),
                  label: const Text('Add prescription'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter what is on your prescription label.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dosey does not verify prescriptions or identify pills.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PrescriptionHeroChip(
                  icon: Icons.medication_outlined,
                  label: '$prescriptionCount entered',
                ),
                _PrescriptionHeroChip(
                  icon: Icons.event_available_outlined,
                  label: '$scheduledPrescriptionCount scheduled',
                ),
                const _PrescriptionHeroChip(
                  icon: Icons.route_outlined,
                  label: 'Feeds schedule builder',
                ),
                const _PrescriptionHeroChip(
                  icon: Icons.fact_check_outlined,
                  label: 'Local label reference',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionHeroChip extends StatelessWidget {
  const _PrescriptionHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionScheduleSummary {
  const _PrescriptionScheduleSummary({
    required this.activeTimes,
    required this.profileCount,
    required this.details,
  });

  final List<String> activeTimes;
  final int profileCount;
  final List<_PrescriptionScheduleDetail> details;

  bool get hasSchedules => profileCount > 0;

  String get activeTimesLabel => activeTimes.isEmpty
      ? 'Active: no times in this schedule'
      : 'Active: ${activeTimes.join(', ')}';

  String get coverageLabel {
    if (!hasSchedules) return 'No schedules yet';
    return profileCount == 1
        ? 'Used in 1 schedule'
        : 'Used in $profileCount schedules';
  }
}

class _PrescriptionScheduleDetail {
  const _PrescriptionScheduleDetail({
    required this.profileName,
    required this.isActive,
    required this.times,
  });

  final String profileName;
  final bool isActive;
  final List<String> times;

  String get timesLabel => times.join(', ');
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.allPrescriptions,
    required this.activeProfileId,
    required this.scheduleSummary,
    required this.prescriptions,
    required this.reminderSchedules,
  });

  final Prescription prescription;
  final List<Prescription> allPrescriptions;
  final String activeProfileId;
  final _PrescriptionScheduleSummary scheduleSummary;
  final PrescriptionRepository prescriptions;
  final ReminderScheduleService reminderSchedules;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _PillTypeBadge(pillType: prescription.pillType),
        title: Text(prescription.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prescription.pillType.label),
            const SizedBox(height: 4),
            _InventorySummary(prescription: prescription),
            const SizedBox(height: 4),
            if (scheduleSummary.hasSchedules)
              Text(scheduleSummary.activeTimesLabel),
            Text(scheduleSummary.coverageLabel),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Add refill doses',
              onPressed: () => _showRefillSheet(context),
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: 'View schedule details',
              onPressed: scheduleSummary.hasSchedules
                  ? () => _showScheduleDetails(context)
                  : null,
              icon: const Icon(Icons.list_alt_outlined),
            ),
            IconButton(
              tooltip: 'Schedule prescription',
              onPressed: () => _schedule(context),
              icon: const Icon(Icons.event_available_outlined),
            ),
            IconButton(
              tooltip: 'Edit prescription',
              onPressed: () => PrescriptionsScreen._showPrescriptionSheet(
                context,
                prescriptions,
                prescription: prescription,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete prescription',
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows where this medication appears across saved schedule profiles while
  /// reinforcing that Today only follows the single active profile.
  Future<void> _showScheduleDetails(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PrescriptionScheduleDetailsSheet(
        prescription: prescription,
        summary: scheduleSummary,
      ),
    );
  }

  /// Opens the schedule builder with this prescription already selected so
  /// users can move from medication entry to routine setup without retyping.
  Future<void> _schedule(BuildContext context) {
    return RemindersScreen.showScheduleSheet(
      context,
      reminderSchedules,
      allPrescriptions,
      initialPrescriptionId: prescription.id,
      profileId: activeProfileId,
    );
  }

  Future<void> _delete(BuildContext context) async {
    final dependencies = DoseyAppScope.of(context);
    try {
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
          final db = dependencies.database;
          final scheduleCount =
              await (db.select(
                    db.reminderSchedules,
                  )..where((row) => row.prescriptionId.equals(prescription.id)))
                  .get()
                  .then((rows) => rows.length);
          final slotCount =
              await (db.select(
                    db.carouselSlots,
                  )..where((row) => row.prescriptionId.equals(prescription.id)))
                  .get()
                  .then((rows) => rows.length);
          final refillCount =
              await (db.select(
                    db.prescriptionRefills,
                  )..where((row) => row.prescriptionId.equals(prescription.id)))
                  .get()
                  .then((rows) => rows.length);
          await prescriptions.deletePrescription(
            prescription.id,
            auditEvent: const AdminAuditEventFactory().prescriptionDeleted(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: prescription.id,
              summary: 'Deleted prescription ${prescription.name}.',
              details: {
                'name': prescription.name,
                'deletedSchedules': scheduleCount,
                'deletedSlots': slotCount,
                'deletedRefills': refillCount,
              },
            ),
          );
        },
      );
      if (!result.isSuccess) return;
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription delete failed: $error')),
      );
    }
  }

  Future<void> _showRefillSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RefillSheet(
        prescriptions: prescriptions,
        prescription: prescription,
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.prescription});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warningColor = prescription.needsRefill
        ? colorScheme.error
        : colorScheme.primary;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InventoryChip(
          icon: Icons.inventory_2_outlined,
          label: _doseCountLabel(prescription.remainingDoses, suffix: 'left'),
          color: warningColor,
        ),
        _InventoryChip(
          icon: prescription.needsRefill
              ? Icons.warning_amber_outlined
              : Icons.notifications_active_outlined,
          label: prescription.needsRefill
              ? 'Refill soon'
              : 'Warn at ${prescription.refillThreshold}',
          color: warningColor,
        ),
        Text(
          'Count changes only after manual taken confirmation.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InventoryChip extends StatelessWidget {
  const _InventoryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _doseCountLabel(int count, {String? suffix}) {
  final unit = count == 1 ? 'dose' : 'doses';
  return suffix == null ? '$count $unit' : '$count $unit $suffix';
}

class _PrescriptionScheduleDetailsSheet extends StatelessWidget {
  const _PrescriptionScheduleDetailsSheet({
    required this.prescription,
    required this.summary,
  });

  final Prescription prescription;
  final _PrescriptionScheduleSummary summary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${prescription.name} schedules',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Only the active schedule is used by Today.'),
            const SizedBox(height: 16),
            for (final detail in summary.details) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  detail.isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(detail.profileName),
                subtitle: Text(detail.timesLabel),
                trailing: detail.isActive ? const Text('Active') : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrescriptionSheet extends StatefulWidget {
  const _PrescriptionSheet({required this.prescriptions, this.prescription});

  final PrescriptionRepository prescriptions;
  final Prescription? prescription;

  @override
  State<_PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _PrescriptionSheetState extends State<_PrescriptionSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _remainingDosesController;
  late final TextEditingController _refillThresholdController;
  late PillType _pillType;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final prescription = widget.prescription;
    _nameController = TextEditingController(text: prescription?.name ?? '');
    _remainingDosesController = TextEditingController(
      text: (prescription?.remainingDoses ?? 0).toString(),
    );
    _refillThresholdController = TextEditingController(
      text: (prescription?.refillThreshold ?? 3).toString(),
    );
    _pillType = prescription?.pillType ?? PillType.pill;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remainingDosesController.dispose();
    _refillThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.prescription == null
                  ? 'Add prescription'
                  : 'Edit prescription',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medication name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Text(
              'What does it look like?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pillType in PillType.values)
                  ChoiceChip(
                    avatar: Icon(_iconFor(pillType), size: 18),
                    label: Text(pillType.label),
                    selected: _pillType == pillType,
                    onSelected: (_) => setState(() => _pillType = pillType),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Refill tracking',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _remainingDosesController,
                    decoration: const InputDecoration(
                      labelText: 'Remaining doses',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _refillThresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Low warning at',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dosey subtracts only after you confirm a dose was taken.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('Save prescription'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Save local label, count, pill graphic, and refill settings only. The app
  // does not verify prescriptions or identify pills.
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a medication name.');
      return;
    }
    final remainingDoses = _parseDoseField(_remainingDosesController.text);
    final refillThreshold = _parseDoseField(_refillThresholdController.text);
    if (remainingDoses == null || refillThreshold == null) {
      setState(
        () => _errorText =
            'Enter zero or more doses for both refill tracking fields.',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final existing = widget.prescription;
    final prescriptions = widget.prescriptions;
    final prescription = Prescription(
      id: existing?.id ?? 'prescription-${now.microsecondsSinceEpoch}',
      name: name,
      pillType: _pillType,
      remainingDoses: remainingDoses,
      refillThreshold: refillThreshold,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
          await prescriptions.upsertPrescription(
            prescription,
            auditEvent: const AdminAuditEventFactory().prescriptionSaved(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: prescription.id,
              summary:
                  '${existing == null ? 'Added' : 'Updated'} prescription ${prescription.name}.',
              details: {
                'name': prescription.name,
                'pillType': prescription.pillType.storageValue,
                'remainingDoses': prescription.remainingDoses,
                'refillThreshold': prescription.refillThreshold,
              },
            ),
          );
        },
      );
      if (!result.isSuccess) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Prescription save failed: $error';
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static int? _parseDoseField(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }
}

class _RefillSheet extends StatefulWidget {
  const _RefillSheet({required this.prescriptions, required this.prescription});

  final PrescriptionRepository prescriptions;
  final Prescription prescription;

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  final _doseCountController = TextEditingController();
  final _noteController = TextEditingController();
  var _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _doseCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add refill doses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _doseCountLabel(
                widget.prescription.remainingDoses,
                suffix: 'left now',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doseCountController,
              decoration: const InputDecoration(
                labelText: 'Doses added',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('Save refill'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final doseCount = int.tryParse(_doseCountController.text.trim());
    if (doseCount == null || doseCount <= 0) {
      setState(() => _errorText = 'Enter one or more doses.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final prescriptions = widget.prescriptions;
    final prescription = widget.prescription;
    final note = _noteController.text;

    try {
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
          await prescriptions.addRefill(
            prescriptionId: prescription.id,
            doseCount: doseCount,
            occurredAt: DateTime.now().toUtc(),
            note: note,
            auditEvent: const AdminAuditEventFactory().prescriptionRefillAdded(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: prescription.id,
              summary: 'Added refill doses for ${prescription.name}.',
              details: {
                'doseCount': doseCount,
                'hasNote': note.trim().isNotEmpty,
              },
            ),
          );
        },
      );
      if (!result.isSuccess) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Refill save failed: $error';
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _PillTypeBadge extends StatelessWidget {
  const _PillTypeBadge({required this.pillType});

  final PillType pillType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Icon(_iconFor(pillType)),
    );
  }
}

IconData _iconFor(PillType pillType) {
  return switch (pillType) {
    PillType.pill => Icons.circle_outlined,
    PillType.capsule => Icons.medication_outlined,
    PillType.tablet => Icons.crop_square_outlined,
  };
}
