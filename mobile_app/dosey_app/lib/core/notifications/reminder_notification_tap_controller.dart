import 'dart:async';

class ReminderNotificationTapController {
  late final _controller = StreamController<ReminderNotificationTap>.broadcast(
    onListen: _emitPendingTap,
  );
  ReminderNotificationTap? _pendingTap;

  Stream<ReminderNotificationTap> get taps => _controller.stream;

  void handleTap(String doseId) {
    final trimmedDoseId = doseId.trim();
    if (trimmedDoseId.isEmpty) {
      return;
    }
    if (_controller.isClosed) {
      return;
    }
    final tap = ReminderNotificationTap(doseId: trimmedDoseId);
    if (_controller.hasListener) {
      _controller.add(tap);
    } else {
      _pendingTap = tap;
    }
  }

  void _emitPendingTap() {
    final pendingTap = _pendingTap;
    if (pendingTap == null) {
      return;
    }
    _pendingTap = null;
    scheduleMicrotask(() {
      if (!_controller.isClosed) {
        _controller.add(pendingTap);
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}

class ReminderNotificationTap {
  const ReminderNotificationTap({required this.doseId});

  final String doseId;
}
