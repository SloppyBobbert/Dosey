import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:flutter/material.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reminders = DoseyAppScope.of(context).reminders;

    return StreamBuilder<List<ReminderSchedule>>(
      stream: reminders.watchSchedules(),
      builder: (context, snapshot) {
        final schedules = snapshot.data ?? const <ReminderSchedule>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Local reminders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showReminderSheet(context, reminders),
                  icon: const Icon(Icons.add),
                  label: const Text('Add reminder'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Stored on this phone only. Notifications will be wired up later.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (schedules.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No reminders yet.'),
                ),
              )
            else
              for (final schedule in schedules)
                _ReminderTile(schedule: schedule, reminders: reminders),
          ],
        );
      },
    );
  }

  static Future<void> _showReminderSheet(
    BuildContext context,
    ReminderRepository reminders, {
    ReminderSchedule? schedule,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ReminderSheet(reminders: reminders, schedule: schedule),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.schedule, required this.reminders});

  final ReminderSchedule schedule;
  final ReminderRepository reminders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(schedule.label),
        subtitle: Text(schedule.timeLabel),
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
              tooltip: 'Edit reminder',
              onPressed: () => RemindersScreen._showReminderSheet(
                context,
                reminders,
                schedule: schedule,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete reminder',
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
      ).showSnackBar(SnackBar(content: Text('Reminder update failed: $error')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await reminders.deleteSchedule(schedule.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reminder delete failed: $error')));
    }
  }
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.reminders, this.schedule});

  final ReminderRepository reminders;
  final ReminderSchedule? schedule;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late bool _isEnabled;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _labelController = TextEditingController(text: schedule?.label ?? '');
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
    _labelController.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.schedule == null ? 'Add reminder' : 'Edit reminder',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
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
                child: const Text('Save reminder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final label = _labelController.text.trim();
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());

    if (label.isEmpty) {
      setState(() => _errorText = 'Enter a reminder label.');
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
      id: existing?.id ?? 'reminder-${now.microsecondsSinceEpoch}',
      label: label,
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
        _errorText = 'Reminder save failed: $error';
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
