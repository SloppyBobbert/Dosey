import 'dart:async';

class ReminderNotificationTapController {
  final _controller = StreamController<ReminderNotificationTap>.broadcast();

  Stream<ReminderNotificationTap> get taps => _controller.stream;

  void handleTap(String doseId) {
    final trimmedDoseId = doseId.trim();
    if (trimmedDoseId.isEmpty) {
      return;
    }
    _controller.add(ReminderNotificationTap(doseId: trimmedDoseId));
  }

  void dispose() {
    _controller.close();
  }
}

class ReminderNotificationTap {
  const ReminderNotificationTap({required this.doseId});

  final String doseId;
}
