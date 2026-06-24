import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Prescriptions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () =>
                              _showPrescriptionSheet(context, prescriptions),
                          icon: const Icon(Icons.add),
                          label: const Text('Add prescription'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter what is on your prescription label.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dosey does not verify prescriptions or identify pills.',
                      style: Theme.of(context).textTheme.bodySmall,
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
                          reminders: dependencies.reminders,
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
    required this.reminders,
  });

  final Prescription prescription;
  final List<Prescription> allPrescriptions;
  final String activeProfileId;
  final _PrescriptionScheduleSummary scheduleSummary;
  final PrescriptionRepository prescriptions;
  final ReminderRepository reminders;

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
            if (scheduleSummary.hasSchedules)
              Text(scheduleSummary.activeTimesLabel),
            Text(scheduleSummary.coverageLabel),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
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
      reminders,
      allPrescriptions,
      initialPrescriptionId: prescription.id,
      profileId: activeProfileId,
    );
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await prescriptions.deletePrescription(prescription.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription delete failed: $error')),
      );
    }
  }
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
    return Padding(
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
  late PillType _pillType;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final prescription = widget.prescription;
    _nameController = TextEditingController(text: prescription?.name ?? '');
    _pillType = prescription?.pillType ?? PillType.pill;
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  /// Validates the label copy, then persists the local prescription entry.
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a medication name.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final existing = widget.prescription;
    final prescription = Prescription(
      id: existing?.id ?? 'prescription-${now.microsecondsSinceEpoch}',
      name: name,
      pillType: _pillType,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.prescriptions.upsertPrescription(prescription);
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
