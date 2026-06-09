abstract interface class ReminderScheduler {
  Future<void> requestPermission();

  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
  });

  Future<void> cancelDoseReminder(String doseId);
}
