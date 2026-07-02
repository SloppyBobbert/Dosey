import 'dart:async';

/// Broadcasts reminder notification taps to the shell.
///
/// If a cold-start tap arrives before the shell subscribes, the controller keeps
/// the latest pending tap and emits it to the first listener. Later pre-listener
/// taps replace earlier ones because every reminder tap routes to the same Today
/// destination.
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
