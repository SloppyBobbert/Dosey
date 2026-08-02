import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

enum ReminderOccurrencePhase { upcoming, ready, missed, taken, skipped }

class ReminderOccurrenceReadState {
  const ReminderOccurrenceReadState._({
    required this.occurrence,
    required this.phase,
    required this.asOfUtc,
    required this.countdown,
    required this.missedElapsed,
  });

  final ReminderOccurrence occurrence;
  final ReminderOccurrencePhase phase;
  final DateTime asOfUtc;
  final Duration? countdown;
  final Duration? missedElapsed;

  bool get terminal =>
      phase == ReminderOccurrencePhase.taken ||
      phase == ReminderOccurrencePhase.skipped;
}

class ReminderOccurrenceReadStateProjection {
  const ReminderOccurrenceReadStateProjection();

  ReminderOccurrenceReadState project({
    required ReminderOccurrence occurrence,
    required Iterable<PhoneDoseActionEventRow> actions,
    required DateTime asOfUtc,
  }) {
    if (!asOfUtc.isUtc) {
      throw ArgumentError.value(asOfUtc, 'asOfUtc', 'Must be UTC.');
    }
    final canonicalAsOfUtc = DateTime.fromMicrosecondsSinceEpoch(
      asOfUtc.microsecondsSinceEpoch,
      isUtc: true,
    );
    PhoneDoseActionEventRow? latestTerminal;
    PhoneDoseActionEventRow? earliestMissed;

    for (final action in actions) {
      if (action.occurrenceId != occurrence.id) continue;
      if (_isTerminal(action.kind)) {
        if (_isLaterTerminal(action, latestTerminal)) {
          latestTerminal = action;
        }
      } else if (action.kind == 'missed' &&
          (earliestMissed == null ||
              action.occurredAt.isBefore(earliestMissed.occurredAt))) {
        earliestMissed = action;
      }
    }

    if (latestTerminal != null) {
      return ReminderOccurrenceReadState._(
        occurrence: occurrence,
        phase: latestTerminal.kind == 'taken_confirmed'
            ? ReminderOccurrencePhase.taken
            : ReminderOccurrencePhase.skipped,
        asOfUtc: canonicalAsOfUtc,
        countdown: null,
        missedElapsed: null,
      );
    }
    if (earliestMissed != null) {
      final elapsed = canonicalAsOfUtc.difference(earliestMissed.occurredAt);
      return ReminderOccurrenceReadState._(
        occurrence: occurrence,
        phase: ReminderOccurrencePhase.missed,
        asOfUtc: canonicalAsOfUtc,
        countdown: null,
        missedElapsed: elapsed.isNegative ? Duration.zero : elapsed,
      );
    }
    if (canonicalAsOfUtc.isBefore(occurrence.scheduledAtUtc)) {
      return ReminderOccurrenceReadState._(
        occurrence: occurrence,
        phase: ReminderOccurrencePhase.upcoming,
        asOfUtc: canonicalAsOfUtc,
        countdown: occurrence.scheduledAtUtc.difference(canonicalAsOfUtc),
        missedElapsed: null,
      );
    }
    return ReminderOccurrenceReadState._(
      occurrence: occurrence,
      phase: ReminderOccurrencePhase.ready,
      asOfUtc: canonicalAsOfUtc,
      countdown: null,
      missedElapsed: null,
    );
  }

  static bool _isTerminal(String kind) =>
      kind == 'taken_confirmed' || kind == 'skipped';

  static bool _isLaterTerminal(
    PhoneDoseActionEventRow candidate,
    PhoneDoseActionEventRow? selected,
  ) {
    if (selected == null) return true;
    if (candidate.occurredAt.isAfter(selected.occurredAt)) return true;
    return candidate.occurredAt.isAtSameMomentAs(selected.occurredAt) &&
        candidate.kind == 'taken_confirmed';
  }
}
