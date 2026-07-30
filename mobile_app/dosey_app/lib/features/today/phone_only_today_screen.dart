import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/active_profile_schedules_stream.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/material.dart';

class PhoneOnlyTodayScreen extends StatefulWidget {
  const PhoneOnlyTodayScreen({super.key});

  @override
  State<PhoneOnlyTodayScreen> createState() => _PhoneOnlyTodayScreenState();
}

class _PhoneOnlyTodayScreenState extends State<PhoneOnlyTodayScreen> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return StreamBuilder<ScheduleProfile?>(
      key: ValueKey(_reload),
      stream: dependencies.scheduleProfiles.watchActiveProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.hasError) return _errorView();
        return StreamBuilder<List<ReminderSchedule>>(
          stream: watchActiveProfileSchedules(
            dependencies.reminders,
            profileSnapshot.data,
          ),
          builder: (context, scheduleSnapshot) {
            if (scheduleSnapshot.hasError) return _errorView();
            final schedules = scheduleSnapshot.data ?? const [];
            if (schedules.isEmpty) {
              return const Center(child: Text('No doses scheduled today.'));
            }
            return StreamBuilder<List<PhoneDoseActionEventRow>>(
              stream: dependencies.database
                  .select(dependencies.database.phoneDoseActionEvents)
                  .watch(),
              builder: (context, eventSnapshot) {
                if (eventSnapshot.hasError) return _errorView();
                final events = eventSnapshot.data ?? const [];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final schedule in schedules)
                      _PhoneDoseCard(schedule: schedule, events: events),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Today could not load your local schedule.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() => _reload += 1),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneDoseCard extends StatefulWidget {
  const _PhoneDoseCard({required this.schedule, required this.events});

  final ReminderSchedule schedule;
  final List<PhoneDoseActionEventRow> events;

  @override
  State<_PhoneDoseCard> createState() => _PhoneDoseCardState();
}

class _PhoneDoseCardState extends State<_PhoneDoseCard> {
  bool _recording = false;

  @override
  Widget build(BuildContext context) {
    final now = DoseyAppScope.of(context).appClock.now();
    final localDate = _localDate(now);
    final todayEvents = widget.events.where(
      (event) =>
          event.scheduleId == widget.schedule.id &&
          event.scheduleRevision == widget.schedule.revision &&
          event.localDate == localDate,
    );
    final hasTaken = todayEvents.any(
      (event) => event.kind == PhoneDoseActionKind.takenConfirmed.storageValue,
    );
    final hasMissed = todayEvents.any(
      (event) => event.kind == PhoneDoseActionKind.missed.storageValue,
    );
    final hasMissedAcknowledgement = todayEvents.any(
      (event) =>
          event.kind == PhoneDoseActionKind.missedAcknowledged.storageValue,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.schedule.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.schedule.timeLabel),
            if (hasTaken)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Taken recorded'),
              ),
            if (hasMissed && !hasMissedAcknowledgement)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  onPressed: _recording
                      ? null
                      : () => _record(PhoneDoseActionKind.missedAcknowledged),
                  child: const Text('Acknowledge missed dose'),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _recording
                      ? null
                      : () => _record(PhoneDoseActionKind.takenConfirmed),
                  child: const Text('Taken'),
                ),
                OutlinedButton(
                  onPressed: _recording
                      ? null
                      : () => _record(PhoneDoseActionKind.snoozed),
                  child: const Text('Snooze'),
                ),
                OutlinedButton(
                  onPressed: _recording
                      ? null
                      : () => _record(PhoneDoseActionKind.skipped),
                  child: const Text('Skip'),
                ),
                OutlinedButton(
                  onPressed: _recording
                      ? null
                      : () => _record(PhoneDoseActionKind.helpRequested),
                  child: const Text('Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(PhoneDoseActionKind kind) async {
    final dependencies = DoseyAppScope.of(context);
    final phone = dependencies.phone;
    if (phone == null) {
      throw StateError('Phone dose actions require phoneOnly.');
    }
    setState(() => _recording = true);
    try {
      final now = dependencies.appClock.now();
      final scheduledLocal = DateTime(
        now.year,
        now.month,
        now.day,
        widget.schedule.hour,
        widget.schedule.minute,
      );
      final occurrence = ReminderOccurrence(
        scheduleId: widget.schedule.id,
        scheduleRevision: widget.schedule.revision,
        scheduledAt: scheduledLocal.toUtc(),
        localDate: _localDate(scheduledLocal),
        timezoneId: await phone.timezoneId(),
      );
      await phone.doseActions.record(
        PhoneDoseActionRequest(
          occurrence: occurrence,
          medicationId: widget.schedule.prescriptionId ?? widget.schedule.id,
          kind: kind,
          occurredAt: now,
          deviceId: await phone.deviceIdentity.getOrCreate(),
        ),
      );
      if (kind == PhoneDoseActionKind.snoozed) {
        await dependencies.reminderScheduler.scheduleDoseReminder(
          doseId: 'snooze:${occurrence.occurrenceId}',
          scheduledFor: now.add(const Duration(minutes: 10)),
          label: widget.schedule.label,
          repeatsDaily: false,
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not record that action. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _recording = false);
      }
    }
  }

  static String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
