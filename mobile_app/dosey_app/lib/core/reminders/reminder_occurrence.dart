class ReminderOccurrence {
  ReminderOccurrence({
    required this.scheduleId,
    required this.scheduleRevision,
    required DateTime scheduledAt,
    required this.localDate,
    required this.timezoneId,
  }) : scheduledAt = DateTime.fromMillisecondsSinceEpoch(
         scheduledAt.toUtc().millisecondsSinceEpoch,
         isUtc: true,
       );

  final String scheduleId;
  final int scheduleRevision;
  final DateTime scheduledAt;
  final String localDate;
  final String timezoneId;

  String get occurrenceId =>
      '$scheduleId:$scheduleRevision:${scheduledAt.toIso8601String()}';
}
