import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:dosey_app/features/today/unresolved_missed_dose_helper.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.showRobotFaceShortcut,
    required this.onOpenSchedule,
    required this.onOpenCarousel,
    required this.onOpenSettings,
    this.onOpenRobotFace,
  });

  final bool showRobotFaceShortcut;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenCarousel;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenRobotFace;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return StreamBuilder<List<ReminderSchedule>>(
      stream: dependencies.reminders.watchSchedules(),
      initialData: const [],
      builder: (context, schedulesSnapshot) {
        return StreamBuilder<List<DoseLogEvent>>(
          stream: dependencies.doseLog.watchEvents(),
          initialData: const [],
          builder: (context, eventsSnapshot) {
            return StreamBuilder<List<ControllerCommandSession>>(
              stream: dependencies.controllerCommands.watchUnresolvedSessions(),
              initialData: const [],
              builder: (context, sessionsSnapshot) {
                return StreamBuilder<List<CarouselSlot>>(
                  stream: dependencies.carouselSlots.watchSlots(),
                  initialData: const [],
                  builder: (context, slotsSnapshot) {
                    return StreamBuilder<List<ControllerHealthEvent>>(
                      stream: dependencies.controllerHealthEvents
                          .watchRecentEvents(),
                      initialData: const [],
                      builder: (context, healthSnapshot) {
                        return StreamBuilder<DateTime>(
                          stream: dependencies.appClock.ticks,
                          initialData: dependencies.appClock.now(),
                          builder: (context, clockSnapshot) {
                            return _DashboardContent(
                              schedules: schedulesSnapshot.data ?? const [],
                              events: eventsSnapshot.data ?? const [],
                              sessions: sessionsSnapshot.data ?? const [],
                              slots: slotsSnapshot.data ?? const [],
                              healthEvents: healthSnapshot.data ?? const [],
                              now:
                                  clockSnapshot.data ??
                                  dependencies.appClock.now(),
                              showRobotFaceShortcut: showRobotFaceShortcut,
                              onOpenSchedule: onOpenSchedule,
                              onOpenCarousel: onOpenCarousel,
                              onOpenSettings: onOpenSettings,
                              onOpenRobotFace: onOpenRobotFace,
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
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.schedules,
    required this.events,
    required this.sessions,
    required this.slots,
    required this.healthEvents,
    required this.now,
    required this.showRobotFaceShortcut,
    required this.onOpenSchedule,
    required this.onOpenCarousel,
    required this.onOpenSettings,
    required this.onOpenRobotFace,
  });

  final List<ReminderSchedule> schedules;
  final List<DoseLogEvent> events;
  final List<ControllerCommandSession> sessions;
  final List<CarouselSlot> slots;
  final List<ControllerHealthEvent> healthEvents;
  final DateTime now;
  final bool showRobotFaceShortcut;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenCarousel;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenRobotFace;

  @override
  Widget build(BuildContext context) {
    final activeSchedules =
        schedules.where((schedule) => schedule.isEnabled).toList()..sort(
          (a, b) => TodayNextDoseHelper.scheduledTimeForDate(
            a,
            now,
          ).compareTo(TodayNextDoseHelper.scheduledTimeForDate(b, now)),
        );
    final next = TodayNextDoseHelper.currentSchedule(
      activeSchedules,
      events,
      now: now,
    );
    final counts = _TodayCounts.from(activeSchedules, events, now);
    final unresolvedMissed = UnresolvedMissedDoseHelper.latest(
      activeSchedules,
      events,
      now: now,
    );
    final failedSessions = sessions.where(
      (session) => switch (session.state) {
        ControllerCommandSessionState.failed ||
        ControllerCommandSessionState.timedOut ||
        ControllerCommandSessionState.interrupted => true,
        _ => false,
      },
    );
    final reviewSlots = slots.where(
      (slot) => slot.status == CarouselSlotStatus.needsReview,
    );
    final latestHealth = healthEvents.firstOrNull;
    final hasHealthIssue =
        latestHealth != null &&
        switch (latestHealth.type) {
          ControllerHealthEventType.error ||
          ControllerHealthEventType.heartbeatMissed ||
          ControllerHealthEventType.offline => true,
          _ => false,
        };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Next dose', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text(next?.label ?? 'No upcoming dose'),
            subtitle: Text(
              next == null ? 'No active reminder' : next.timeLabel,
            ),
          ),
        ),
        if (unresolvedMissed != null ||
            failedSessions.isNotEmpty ||
            reviewSlots.isNotEmpty ||
            hasHealthIssue) ...[
          const SizedBox(height: 12),
          Text(
            'Needs attention',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (unresolvedMissed != null)
            const ListTile(
              dense: true,
              leading: Icon(Icons.warning_amber_rounded),
              title: Text('Missed dose needs attention'),
            ),
          if (failedSessions.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(Icons.error_outline),
              title: Text(
                '${failedSessions.length} controller command '
                'failure${failedSessions.length == 1 ? '' : 's'}',
              ),
            ),
          if (reviewSlots.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                '${reviewSlots.length} carousel '
                'slot${reviewSlots.length == 1 ? '' : 's'} need${reviewSlots.length == 1 ? 's' : ''} review',
              ),
            ),
          if (hasHealthIssue)
            const ListTile(
              dense: true,
              leading: Icon(Icons.bluetooth_disabled),
              title: Text('Controller connection needs attention'),
            ),
        ],
        const SizedBox(height: 12),
        Text('Shortcuts', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Schedule'),
              onPressed: onOpenSchedule,
            ),
            ActionChip(
              label: const Text('Carousel'),
              onPressed: onOpenCarousel,
            ),
            ActionChip(
              label: const Text('Settings'),
              onPressed: onOpenSettings,
            ),
            if (showRobotFaceShortcut)
              ActionChip(
                label: const Text('Robot Face'),
                onPressed: onOpenRobotFace,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Today')),
                  body: const TodayScreen(),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's doses",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('Taken ${counts.taken}'),
                      Text('Skipped ${counts.skipped}'),
                      Text('Upcoming ${counts.upcoming}'),
                      Text('Missed ${counts.missed}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayCounts {
  const _TodayCounts({
    required this.taken,
    required this.skipped,
    required this.upcoming,
    required this.missed,
  });

  factory _TodayCounts.from(
    List<ReminderSchedule> schedules,
    List<DoseLogEvent> events,
    DateTime now,
  ) {
    var taken = 0;
    var skipped = 0;
    var upcoming = 0;
    var missed = 0;
    for (final schedule in schedules) {
      final doseId = TodayNextDoseHelper.doseIdForDate(schedule.id, now);
      final latest = TodayNextDoseHelper.latestEventForDose(events, doseId);
      if (latest?.marksDoseTaken ?? false) {
        taken++;
      } else if (latest?.kind == DoseLogEventKind.doseSkipped) {
        skipped++;
      } else if (latest?.kind == DoseLogEventKind.doseMissed) {
        missed++;
      } else if (!TodayNextDoseHelper.scheduledTimeForDate(
        schedule,
        now,
      ).isBefore(now)) {
        upcoming++;
      }
    }
    return _TodayCounts(
      taken: taken,
      skipped: skipped,
      upcoming: upcoming,
      missed: missed,
    );
  }

  final int taken;
  final int skipped;
  final int upcoming;
  final int missed;
}
