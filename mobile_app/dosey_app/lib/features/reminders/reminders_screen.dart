import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
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
        return StreamBuilder<List<ReminderSchedule>>(
          stream: dependencies.reminders.watchSchedules(),
          builder: (context, scheduleSnapshot) {
            final schedules =
                scheduleSnapshot.data ?? const <ReminderSchedule>[];
            final prescriptionsById = {
              for (final prescription in prescriptions)
                prescription.id: prescription,
            };

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: prescriptions.isEmpty
                          ? null
                          : () => showScheduleSheet(
                              context,
                              dependencies.reminders,
                              prescriptions,
                            ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add schedule'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create schedules from prescriptions you entered. Dosey does not verify dosing instructions.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (prescriptions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Add a prescription before creating a schedule.',
                      ),
                    ),
                  )
                else if (schedules.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No schedules yet.'),
                    ),
                  )
                else
                  for (final schedule in schedules)
                    _ScheduleTile(
                      schedule: schedule,
                      prescription: prescriptionsById[schedule.prescriptionId],
                      prescriptions: prescriptions,
                      reminders: dependencies.reminders,
                    ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> showScheduleSheet(
    BuildContext context,
    ReminderRepository reminders,
    List<Prescription> prescriptions, {
    ReminderSchedule? schedule,
    String? initialPrescriptionId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ScheduleSheet(
        reminders: reminders,
        prescriptions: prescriptions,
        schedule: schedule,
        initialPrescriptionId: initialPrescriptionId,
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.prescription,
    required this.prescriptions,
    required this.reminders,
  });

  final ReminderSchedule schedule;
  final Prescription? prescription;
  final List<Prescription> prescriptions;
  final ReminderRepository reminders;

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
                reminders,
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
      await reminders.upsertSchedule(
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
      await reminders.deleteSchedule(schedule.id);
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
    required this.reminders,
    required this.prescriptions,
    this.schedule,
    this.initialPrescriptionId,
  });

  final ReminderRepository reminders;
  final List<Prescription> prescriptions;
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
      hour: hour,
      minute: minute,
      isEnabled: _isEnabled,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.reminders.upsertSchedule(schedule);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Schedule save failed: $error';
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
}
