import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:flutter/material.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<List<Prescription>>(
      stream: dependencies.prescriptions.watchPrescriptions(),
      builder: (context, prescriptionSnapshot) {
        final prescriptions =
            prescriptionSnapshot.data ?? const <Prescription>[];
        return StreamBuilder<List<ScheduleProfile>>(
          stream: dependencies.scheduleProfiles.watchProfiles(),
          builder: (context, profileSnapshot) {
            final profiles = profileSnapshot.data ?? const <ScheduleProfile>[];
            final activeProfile = _activeProfile(profiles);
            return StreamBuilder<List<ReminderSchedule>>(
              stream: dependencies.reminders.watchSchedules(),
              builder: (context, allSchedulesSnapshot) {
                final allSchedules =
                    allSchedulesSnapshot.data ?? const <ReminderSchedule>[];
                final profileScheduleCounts = _profileScheduleCounts(
                  allSchedules,
                );

                return StreamBuilder<List<ReminderSchedule>>(
                  stream: _activeSchedulesStream(
                    dependencies.reminders,
                    activeProfile,
                  ),
                  builder: (context, scheduleSnapshot) {
                    final schedules =
                        scheduleSnapshot.data ?? const <ReminderSchedule>[];
                    final prescriptionsById = {
                      for (final prescription in prescriptions)
                        prescription.id: prescription,
                    };

                    final canAddSchedule =
                        prescriptions.isNotEmpty && activeProfile != null;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _ScheduleHeroCard(
                          activeProfile: activeProfile,
                          schedules: schedules,
                          hasPrescriptions: prescriptions.isNotEmpty,
                          canAddSchedule: canAddSchedule,
                          onAddSchedule: canAddSchedule
                              ? () => showScheduleSheet(
                                  context,
                                  dependencies.reminderSchedules,
                                  prescriptions,
                                  profileId: activeProfile.id,
                                )
                              : null,
                        ),
                        const _NotificationPermissionBanner(),
                        const SizedBox(height: 16),
                        _ScheduleProfileSection(
                          profiles: profiles,
                          activeProfile: activeProfile,
                          profileScheduleCounts: profileScheduleCounts,
                          profilesRepository: dependencies.scheduleProfiles,
                        ),
                        const SizedBox(height: 16),
                        if (schedules.isNotEmpty)
                          for (final schedule in schedules)
                            _ScheduleTile(
                              schedule: schedule,
                              prescription:
                                  prescriptionsById[schedule.prescriptionId],
                              prescriptions: prescriptions,
                              reminderSchedules: dependencies.reminderSchedules,
                            )
                        else
                          const SizedBox.shrink(),
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
  }

  static ScheduleProfile? _activeProfile(List<ScheduleProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isActive) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  static Stream<List<ReminderSchedule>> _activeSchedulesStream(
    ReminderRepository reminders,
    ScheduleProfile? activeProfile,
  ) {
    if (activeProfile == null) {
      return Stream<List<ReminderSchedule>>.value(const <ReminderSchedule>[]);
    }
    return reminders.watchSchedules(profileId: activeProfile.id);
  }

  /// Counts schedules per profile so saved routines show their scope even when
  /// only one profile is active in the main Schedule list.
  static Map<String, int> _profileScheduleCounts(
    List<ReminderSchedule> schedules,
  ) {
    final counts = <String, int>{};
    for (final schedule in schedules) {
      counts.update(
        schedule.profileId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  static Future<void> showScheduleSheet(
    BuildContext context,
    ReminderScheduleService reminderSchedules,
    List<Prescription> prescriptions, {
    ReminderSchedule? schedule,
    String? initialPrescriptionId,
    String profileId = ReminderSchedule.defaultProfileId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ScheduleSheet(
        reminderSchedules: reminderSchedules,
        prescriptions: prescriptions,
        schedule: schedule,
        initialPrescriptionId: initialPrescriptionId,
        profileId: profileId,
      ),
    );
  }
}

class _NotificationPermissionBanner extends StatefulWidget {
  const _NotificationPermissionBanner();

  @override
  State<_NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<_NotificationPermissionBanner> {
  AppPermissionState _status = AppPermissionState.unknown;
  bool _isChecking = true;
  bool _hasCheckedPermission = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedPermission && TickerMode.valuesOf(context).enabled) {
      _hasCheckedPermission = true;
      _checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status != AppPermissionState.denied) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        elevation: 0,
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notification alerts are blocked',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Schedules still save locally, but this phone may not show reminder alerts until notifications are allowed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isChecking ? null : _requestPermission,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  _isChecking ? 'Checking...' : 'Check notification permission',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkPermission() async {
    final permissions = DoseyAppScope.of(context).permissions;
    final status = await permissions.check(AppPermission.notifications);
    if (!mounted) return;
    setState(() {
      _status = status;
      _isChecking = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _isChecking = true);
    try {
      final status = await DoseyAppScope.of(
        context,
      ).permissions.request(AppPermission.notifications);
      if (!mounted) return;
      setState(() {
        _status = status;
        _isChecking = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification permission check failed: $error')),
      );
    }
  }
}

class _ScheduleHeroCard extends StatelessWidget {
  const _ScheduleHeroCard({
    required this.activeProfile,
    required this.schedules,
    required this.hasPrescriptions,
    required this.canAddSchedule,
    required this.onAddSchedule,
  });

  final ScheduleProfile? activeProfile;
  final List<ReminderSchedule> schedules;
  final bool hasPrescriptions;
  final bool canAddSchedule;
  final VoidCallback? onAddSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabledCount = schedules
        .where((schedule) => schedule.isEnabled)
        .length;
    final scheduledCount = schedules.length;
    final emptyHint = scheduledCount == 0
        ? hasPrescriptions
              ? 'No schedules yet.'
              : 'Add a prescription before creating a schedule.'
        : null;

    return Card(
      color: colorScheme.primaryContainer,
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
                        'Routine builder',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeProfile?.name ?? 'No active schedule',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddSchedule,
                  icon: const Icon(Icons.add),
                  label: const Text('Add schedule'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              emptyHint ??
                  'Create schedules from prescriptions you entered. Dosey does not verify dosing instructions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _ScheduleHeroChip(
                  icon: Icons.event_available_outlined,
                  label: 'Active routine',
                ),
                _ScheduleHeroChip(
                  icon: Icons.notifications_active_outlined,
                  label: '$enabledCount enabled / $scheduledCount scheduled',
                ),
                const _ScheduleHeroChip(
                  icon: Icons.timeline_outlined,
                  label: 'Feeds Today timeline',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleHeroChip extends StatelessWidget {
  const _ScheduleHeroChip({required this.icon, required this.label});

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

class _ScheduleProfileSection extends StatelessWidget {
  const _ScheduleProfileSection({
    required this.profiles,
    required this.activeProfile,
    required this.profileScheduleCounts,
    required this.profilesRepository,
  });

  final List<ScheduleProfile> profiles;
  final ScheduleProfile? activeProfile;
  final Map<String, int> profileScheduleCounts;
  final ScheduleProfileRepository profilesRepository;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active schedule',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(activeProfile?.name ?? 'No active schedule'),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showProfileSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add schedule profile'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final profile in profiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(profile.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profileCountLabel(profile)),
                    Text(profile.isActive ? 'Active' : 'Saved'),
                  ],
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tooltip(
                      message: 'Edit ${profile.name} schedule',
                      child: IconButton(
                        onPressed: () =>
                            _showProfileSheet(context, profile: profile),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                    if (profile.isActive)
                      const Icon(Icons.check_circle_outline)
                    else
                      Tooltip(
                        message: 'Use ${profile.name} schedule',
                        child: TextButton(
                          onPressed: () => _setActive(context, profile.id),
                          child: Text('Use ${profile.name}'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _profileCountLabel(ScheduleProfile profile) {
    final count = profileScheduleCounts[profile.id] ?? 0;
    final noun = count == 1 ? 'schedule' : 'schedules';
    return '${profile.name} · $count $noun';
  }

  Future<void> _showProfileSheet(
    BuildContext context, {
    ScheduleProfile? profile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ScheduleProfileSheet(profiles: profilesRepository, profile: profile),
    );
  }

  /// Switches the robot to one active schedule profile without deleting any
  /// saved schedules in other profiles.
  Future<void> _setActive(BuildContext context, String id) async {
    try {
      await profilesRepository.setActiveProfile(id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Schedule profile update failed: $error')),
      );
    }
  }
}

class _ScheduleProfileSheet extends StatefulWidget {
  const _ScheduleProfileSheet({required this.profiles, this.profile});

  final ScheduleProfileRepository profiles;
  final ScheduleProfile? profile;

  @override
  State<_ScheduleProfileSheet> createState() => _ScheduleProfileSheetState();
}

class _ScheduleProfileSheetState extends State<_ScheduleProfileSheet> {
  final _nameController = TextEditingController();
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile?.name ?? '';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.profile == null
                ? 'Add schedule profile'
                : 'Rename schedule profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Schedule name',
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
                child: const Text('Save schedule profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Saves a named routine profile that can become the one active robot schedule.
  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Schedule name is required.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final existing = widget.profile;
    try {
      await widget.profiles.upsertProfile(
        ScheduleProfile(
          id: existing?.id ?? 'schedule-profile-${now.microsecondsSinceEpoch}',
          name: name,
          isActive: existing?.isActive ?? false,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Schedule profile save failed: $error';
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.prescription,
    required this.prescriptions,
    required this.reminderSchedules,
  });

  final ReminderSchedule schedule;
  final Prescription? prescription;
  final List<Prescription> prescriptions;
  final ReminderScheduleService reminderSchedules;

  @override
  Widget build(BuildContext context) {
    final title = prescription?.name ?? schedule.label;
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(schedule.timeLabel),
            if (prescription != null) Text(prescription!.pillType.label),
          ],
        ),
        leading: Icon(
          schedule.isEnabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Switch(
              value: schedule.isEnabled,
              onChanged: (value) => _setEnabled(context, value),
            ),
            IconButton(
              tooltip: 'Edit schedule',
              onPressed: () => RemindersScreen.showScheduleSheet(
                context,
                reminderSchedules,
                prescriptions,
                schedule: schedule,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete schedule',
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(BuildContext context, bool value) async {
    try {
      await reminderSchedules.saveSchedule(
        schedule.copyWith(isEnabled: value, updatedAt: DateTime.now().toUtc()),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Schedule update failed: $error')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await reminderSchedules.deleteSchedule(schedule.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Schedule delete failed: $error')));
    }
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.reminderSchedules,
    required this.prescriptions,
    required this.profileId,
    this.schedule,
    this.initialPrescriptionId,
  });

  final ReminderScheduleService reminderSchedules;
  final List<Prescription> prescriptions;
  final String profileId;
  final ReminderSchedule? schedule;
  final String? initialPrescriptionId;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late String? _selectedPrescriptionId;
  late bool _isEnabled;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _selectedPrescriptionId = _initialPrescriptionId(schedule);
    _hourController = TextEditingController(
      text: schedule == null ? '' : schedule.hour.toString(),
    );
    _minuteController = TextEditingController(
      text: schedule == null ? '' : schedule.minute.toString(),
    );
    _isEnabled = schedule?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
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
              widget.schedule == null ? 'Add schedule' : 'Edit schedule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the medication details you already entered. Dosey does not confirm your dose is correct.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Which prescription?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final prescription in widget.prescriptions)
              Card.outlined(
                child: ListTile(
                  selected: _selectedPrescriptionId == prescription.id,
                  title: Text(prescription.name),
                  subtitle: Text(prescription.pillType.label),
                  trailing: _selectedPrescriptionId == prescription.id
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: () => setState(() {
                    _selectedPrescriptionId = prescription.id;
                  }),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hourController,
                    decoration: const InputDecoration(
                      labelText: 'Hour',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minuteController,
                    decoration: const InputDecoration(
                      labelText: 'Minute',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              value: _isEnabled,
              onChanged: (value) => setState(() => _isEnabled = value),
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
                  child: const Text('Save schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a reminder schedule from a saved prescription, preserving legacy
  /// schedules by leaving their label-only display intact until edited.
  Future<void> _save() async {
    if (_isSaving) return;

    final prescription = _selectedPrescription();
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());

    if (prescription == null) {
      setState(() => _errorText = 'Choose a prescription.');
      return;
    }
    if (hour == null || hour < 0 || hour > 23) {
      setState(() => _errorText = 'Hour must be 0 through 23.');
      return;
    }
    if (minute == null || minute < 0 || minute > 59) {
      setState(() => _errorText = 'Minute must be 0 through 59.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final existing = widget.schedule;
    final schedule = ReminderSchedule(
      id: existing?.id ?? 'schedule-${now.microsecondsSinceEpoch}',
      label: prescription.name,
      prescriptionId: prescription.id,
      profileId: existing?.profileId ?? widget.profileId,
      hour: hour,
      minute: minute,
      isEnabled: _isEnabled,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.reminderSchedules.saveSchedule(schedule);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _scheduleSaveErrorMessage(error);
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String? _initialPrescriptionId(ReminderSchedule? schedule) {
    final savedId = schedule?.prescriptionId;
    if (savedId != null &&
        widget.prescriptions.any(
          (prescription) => prescription.id == savedId,
        )) {
      return savedId;
    }
    if (schedule != null) {
      return null;
    }
    final initialId = widget.initialPrescriptionId;
    if (initialId != null &&
        widget.prescriptions.any(
          (prescription) => prescription.id == initialId,
        )) {
      return initialId;
    }
    return widget.prescriptions.isEmpty ? null : widget.prescriptions.first.id;
  }

  Prescription? _selectedPrescription() {
    final selectedId = _selectedPrescriptionId;
    if (selectedId == null) return null;
    for (final prescription in widget.prescriptions) {
      if (prescription.id == selectedId) return prescription;
    }
    return null;
  }

  /// Keeps validation failures readable while preserving raw details for unknown errors.
  static String _scheduleSaveErrorMessage(Object error) {
    if (error is ArgumentError && error.message is String) {
      return error.message as String;
    }
    return 'Schedule save failed: $error';
  }
}
