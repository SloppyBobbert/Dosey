import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/caregiver/caregiver_status_projection.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter/material.dart';

import 'dosey_web_dependencies.dart';
import 'web_routes.dart';

class CaregiverShell extends StatefulWidget {
  const CaregiverShell({
    super.key,
    required this.dependencies,
    required this.installation,
    required this.route,
  });

  final DoseyWebDependencies dependencies;
  final RobotInstallation installation;
  final String route;

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  late final CaregiverSnapshotController _snapshot =
      CaregiverSnapshotController(
        householdId: widget.installation.id,
        gateway: widget.dependencies.caregiver,
        now: widget.dependencies.now,
      );

  @override
  void initState() {
    super.initState();
    _snapshot.load();
  }

  @override
  void dispose() {
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _snapshot,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(widget.installation.displayName),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _snapshot.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _CareNavigation(currentRoute: widget.route),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() => switch (_snapshot.state) {
    CaregiverLoading() => const Center(child: CircularProgressIndicator()),
    CaregiverUnavailable(:final message) => _SyncMessage(
      title: 'Care information is unavailable.',
      detail: message,
      onRetry: _snapshot.refresh,
    ),
    CaregiverFresh(:final snapshot) => _page(snapshot),
    CaregiverRefreshing(:final snapshot, :final lastUpdatedAt) => Column(
      children: [
        _SyncBanner(
          message: 'Refreshing · last updated ${_time(lastUpdatedAt)}',
        ),
        Expanded(child: _page(snapshot)),
      ],
    ),
    CaregiverStale(
      :final snapshot,
      :final lastUpdatedAt,
      :final message,
      :final isConflict,
    ) =>
      Column(
        children: [
          _SyncBanner(
            message: isConflict
                ? 'Update conflict · refresh before trying again.'
                : 'Offline · showing data from ${_time(lastUpdatedAt)}. $message',
          ),
          Expanded(child: _page(snapshot)),
        ],
      ),
  };

  Widget _page(CaregiverSnapshot value) => switch (widget.route) {
    WebRoutes.medications => _MedicationPage(
      value: value,
      canEdit: widget.installation.isCurrentAccountOwner,
      push: _snapshot.push,
      now: widget.dependencies.now,
    ),
    WebRoutes.schedules => _SchedulePage(
      value: value,
      canEdit: widget.installation.isCurrentAccountOwner,
      push: _snapshot.push,
      now: widget.dependencies.now,
    ),
    _ => _TodayPage(
      value: value,
      now: widget.dependencies.now(),
      push: _snapshot.push,
      recordTerminal: _snapshot.recordTerminalDose,
      terminalActionsAvailable:
          _snapshot.state is CaregiverFresh &&
          !_snapshot.isTerminalMutationPending,
    ),
  };
}

class _CareNavigation extends StatelessWidget {
  const _CareNavigation({required this.currentRoute});
  final String currentRoute;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        _link(context, 'Today', WebRoutes.today),
        _link(context, 'Medications', WebRoutes.medications),
        _link(context, 'Schedules', WebRoutes.schedules),
        _link(context, 'Household', WebRoutes.household),
        _link(context, 'Account', WebRoutes.account),
      ],
    ),
  );

  Widget _link(BuildContext context, String label, String route) => TextButton(
    onPressed: currentRoute == route
        ? null
        : () => Navigator.pushReplacementNamed(context, route),
    child: Text(label),
  );
}

class _TodayPage extends StatefulWidget {
  const _TodayPage({
    required this.value,
    required this.now,
    required this.push,
    required this.recordTerminal,
    required this.terminalActionsAvailable,
  });
  final CaregiverSnapshot value;
  final DateTime now;
  final Future<void> Function(CaregiverMutation) push;
  final Future<void> Function({
    required CaregiverOccurrence occurrence,
    required CaregiverDoseAction action,
  })
  recordTerminal;
  final bool terminalActionsAvailable;

  @override
  State<_TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<_TodayPage> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final doses = projectCaregiverDay(snapshot: widget.value, now: widget.now);
    final terminalActionsAvailable =
        widget.terminalActionsAvailable && !_dialogOpen;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Today', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (doses.isEmpty) const Text('No doses scheduled today.'),
        for (final dose in doses)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dose.medication.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_clock(dose.scheduledFor)} · ${_status(dose.status)}',
                  ),
                  if (dose.medication.instructions.isNotEmpty)
                    Text(dose.medication.instructions),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!dose.hasTerminalOutcome && terminalActionsAvailable)
                        FilledButton(
                          onPressed: () => _confirm(
                            context,
                            dose,
                            CaregiverDoseAction.taken,
                            'Confirm this dose was taken?',
                          ),
                          child: const Text('Confirm taken'),
                        ),
                      if (!dose.hasTerminalOutcome && terminalActionsAvailable)
                        OutlinedButton(
                          onPressed: () => _confirm(
                            context,
                            dose,
                            CaregiverDoseAction.skipped,
                            'Confirm this dose should be skipped?',
                          ),
                          child: const Text('Skip dose'),
                        ),
                      TextButton(
                        onPressed: () => _confirm(
                          context,
                          dose,
                          CaregiverDoseAction.helpRequested,
                          'Send a help request to the household?',
                        ),
                        child: const Text('Request help'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
        if (widget.value.events.isEmpty) const Text('No dose activity yet.'),
        for (final event in widget.value.events.reversed)
          ListTile(
            title: Text(_action(event.action)),
            subtitle: Text('${_clock(event.scheduledFor)} scheduled dose'),
          ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    CaregiverDoseProjection dose,
    CaregiverDoseAction action,
    String prompt,
  ) async {
    if (_dialogOpen) return;
    setState(() => _dialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prompt),
        content: Text(dose.medication.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _dialogOpen = false);
    if (confirmed != true) return;
    if (action == CaregiverDoseAction.taken ||
        action == CaregiverDoseAction.skipped) {
      await widget.recordTerminal(occurrence: dose.occurrence, action: action);
      return;
    }
    await widget.push(
      CaregiverMutation.recordDose(occurrence: dose.occurrence, action: action),
    );
  }
}

class _MedicationPage extends StatelessWidget {
  const _MedicationPage({
    required this.value,
    required this.canEdit,
    required this.push,
    required this.now,
  });
  final CaregiverSnapshot value;
  final bool canEdit;
  final Future<void> Function(CaregiverMutation) push;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Medications', style: Theme.of(context).textTheme.headlineMedium),
      if (!canEdit)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Only the household owner can edit medications.'),
        ),
      for (final medication in value.medications)
        ListTile(
          title: Text(medication.name),
          subtitle: Text(medication.instructions),
          trailing: canEdit
              ? Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Edit ${medication.name}',
                      onPressed: () => _edit(context, medication),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete ${medication.name}',
                      onPressed: () =>
                          push(CaregiverMutation.deleteMedication(medication)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                )
              : null,
        ),
      if (canEdit)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Add medication'),
          ),
        ),
    ],
  );

  Future<void> _edit(
    BuildContext context,
    CaregiverMedication? medication,
  ) async {
    var name = medication?.name ?? '';
    var instructions = medication?.instructions ?? '';
    final result = await showDialog<CaregiverMedication>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medication == null ? 'Add medication' : 'Edit medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: 'Medication name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: instructions,
                onChanged: (value) => instructions = value,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isEmpty) return;
              Navigator.pop(
                context,
                CaregiverMedication(
                  id:
                      medication?.id ??
                      'medication-${now().microsecondsSinceEpoch}',
                  name: name,
                  pillType: medication?.pillType ?? CaregiverPillType.pill,
                  instructions: instructions.trim(),
                  active: medication?.active ?? true,
                  version: medication?.version ?? 0,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await push(CaregiverMutation.upsertMedication(result));
  }
}

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({
    required this.value,
    required this.canEdit,
    required this.push,
    required this.now,
  });
  final CaregiverSnapshot value;
  final bool canEdit;
  final Future<void> Function(CaregiverMutation) push;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Schedules', style: Theme.of(context).textTheme.headlineMedium),
      if (!canEdit)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Only the household owner can edit schedules.'),
        ),
      for (final schedule in value.schedules)
        ListTile(
          title: Text(schedule.label),
          subtitle: Text(
            '${_medicationName(value, schedule.medicationId)} · ${_two(schedule.hour)}:${_two(schedule.minute)} ${schedule.timezoneId}',
          ),
          trailing: canEdit
              ? Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Edit ${schedule.label}',
                      onPressed: () => _edit(context, schedule),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete ${schedule.label}',
                      onPressed: () =>
                          push(CaregiverMutation.deleteSchedule(schedule)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                )
              : null,
        ),
      if (canEdit && value.medications.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Add schedule'),
          ),
        ),
    ],
  );

  Future<void> _edit(BuildContext context, CaregiverSchedule? schedule) async {
    var label = schedule?.label ?? '';
    var selectedTime = schedule == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: schedule.hour, minute: schedule.minute);
    var selectedMedicationId =
        schedule?.medicationId ?? value.medications.first.id;
    final result = await showDialog<CaregiverSchedule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(schedule == null ? 'Add schedule' : 'Edit schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: label,
                  onChanged: (value) => label = value,
                  decoration: const InputDecoration(
                    labelText: 'Schedule label',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMedicationId,
                  decoration: const InputDecoration(labelText: 'Medication'),
                  items: [
                    for (final medication in value.medications)
                      DropdownMenuItem(
                        value: medication.id,
                        child: Text(medication.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) selectedMedicationId = value;
                  },
                ),
                const SizedBox(height: 12),
                Text('Times use ${schedule?.timezoneId ?? 'UTC'}.'),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(selectedTime.format(context)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (label.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  CaregiverSchedule(
                    id:
                        schedule?.id ??
                        'schedule-${now().microsecondsSinceEpoch}',
                    medicationId: selectedMedicationId,
                    label: label,
                    hour: selectedTime.hour,
                    minute: selectedTime.minute,
                    timezoneId: schedule?.timezoneId ?? 'UTC',
                    enabled: schedule?.enabled ?? true,
                    version: schedule?.version ?? 0,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await push(CaregiverMutation.upsertSchedule(result));
  }
}

class _SyncMessage extends StatelessWidget {
  const _SyncMessage({
    required this.title,
    required this.detail,
    required this.onRetry,
  });
  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(detail),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Text(message),
    actions: const [SizedBox.shrink()],
  );
}

String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';
String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${_two(value.minute)} ${value.hour < 12 ? 'AM' : 'PM'}';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _medicationName(CaregiverSnapshot value, String id) =>
    value.medications
        .where((medication) => medication.id == id)
        .map((medication) => medication.name)
        .firstOrNull ??
    'Unknown medication';
String _status(CaregiverDoseStatus value) => switch (value) {
  CaregiverDoseStatus.upcoming => 'Upcoming',
  CaregiverDoseStatus.due => 'Due now',
  CaregiverDoseStatus.missed => 'Missed',
  CaregiverDoseStatus.taken => 'Taken',
  CaregiverDoseStatus.skipped => 'Skipped',
  CaregiverDoseStatus.snoozed => 'Snoozed',
  CaregiverDoseStatus.helpRequested => 'Help requested',
};
String _action(CaregiverDoseAction value) => switch (value) {
  CaregiverDoseAction.taken => 'Dose confirmed taken',
  CaregiverDoseAction.skipped => 'Dose skipped',
  CaregiverDoseAction.snoozed => 'Dose snoozed',
  CaregiverDoseAction.helpRequested => 'Help requested',
};
