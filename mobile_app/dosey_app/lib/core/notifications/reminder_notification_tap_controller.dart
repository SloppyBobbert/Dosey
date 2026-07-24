import 'dart:async';

/// Broadcasts reminder notification taps to the shell.
///
/// If a cold-start tap arrives before the shell subscribes, the controller keeps
/// the latest pending tap and emits it to the first listener. Later pre-listener
/// taps replace earlier ones because only the latest launch intent can be acted
/// upon.
class ReminderNotificationTapController {
  late final _controller = StreamController<ReminderNotificationTap>.broadcast(
    onListen: _emitPendingTap,
  );
  ReminderNotificationTap? _pendingTap;

  Stream<ReminderNotificationTap> get taps => _controller.stream;

  void handleTap(String payload) {
    final tap = ReminderNotificationTap.fromPayload(payload);
    if (tap == null) return;
    if (_controller.isClosed) {
      return;
    }
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

enum ReminderNotificationTapKind { doseReminder, shortage }

class ReminderNotificationTap {
  const ReminderNotificationTap.doseReminder(String doseId)
    : kind = ReminderNotificationTapKind.doseReminder,
      targetId = doseId;

  const ReminderNotificationTap.shortage(String alertId)
    : kind = ReminderNotificationTapKind.shortage,
      targetId = alertId;

  final ReminderNotificationTapKind kind;
  final String targetId;

  static ReminderNotificationTap? fromPayload(String payload) {
    final trimmedPayload = payload.trim();
    if (trimmedPayload.isEmpty) return null;

    const shortagePrefix = 'shortage:';
    if (!trimmedPayload.startsWith(shortagePrefix)) {
      return ReminderNotificationTap.doseReminder(trimmedPayload);
    }

    final metadataStart = trimmedPayload.indexOf('|');
    final alertId = trimmedPayload.substring(
      shortagePrefix.length,
      metadataStart < 0 ? trimmedPayload.length : metadataStart,
    );
    if (alertId.isEmpty) return null;
    return ReminderNotificationTap.shortage(alertId);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderNotificationTap &&
      other.kind == kind &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(kind, targetId);
}
