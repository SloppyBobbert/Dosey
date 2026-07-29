import 'dart:async';

abstract interface class AppClock {
  DateTime now();

  Stream<DateTime> get ticks;
}

class SystemAppClock implements AppClock {
  SystemAppClock({this.tickInterval = const Duration(seconds: 30)}) {
    _timer = Timer.periodic(tickInterval, (_) => _ticks.add(now()));
  }

  final Duration tickInterval;
  final StreamController<DateTime> _ticks =
      StreamController<DateTime>.broadcast();
  late final Timer _timer;
  Future<void>? _closeFuture;

  @override
  DateTime now() => DateTime.now();

  @override
  Stream<DateTime> get ticks => _ticks.stream;

  void stop() {
    _timer.cancel();
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    stop();
    await _ticks.close();
  }
}

class ControllableAppClock implements AppClock {
  ControllableAppClock(DateTime initial) : _value = initial.toUtc();

  final StreamController<DateTime> _ticks =
      StreamController<DateTime>.broadcast(sync: true);
  DateTime _value;
  Future<void>? _closeFuture;

  @override
  DateTime now() => _value;

  @override
  Stream<DateTime> get ticks => _ticks.stream;

  void advance(Duration duration) => set(_value.add(duration));

  void set(DateTime value) {
    _value = value.toUtc();
    _ticks.add(_value);
  }

  Future<void> close() => _closeFuture ??= _ticks.close();
}
