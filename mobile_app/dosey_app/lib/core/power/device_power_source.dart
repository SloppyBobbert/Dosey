import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

enum ExternalPowerState { present, absent, unknown }

class DevicePowerSnapshot {
  const DevicePowerSnapshot({
    required this.batteryLevel,
    required this.externalPower,
  }) : assert(
         batteryLevel == null || (batteryLevel >= 0 && batteryLevel <= 100),
       );

  final int? batteryLevel;
  final ExternalPowerState externalPower;

  @override
  bool operator ==(Object other) {
    return other is DevicePowerSnapshot &&
        batteryLevel == other.batteryLevel &&
        externalPower == other.externalPower;
  }

  @override
  int get hashCode => Object.hash(batteryLevel, externalPower);
}

abstract interface class DevicePowerSource {
  DevicePowerSnapshot get currentSnapshot;

  Stream<DevicePowerSnapshot> get snapshots;

  /// Starts source-specific initialization and returns the first refreshed value.
  Future<DevicePowerSnapshot> initialize();

  /// Performs one-time reads of the available power information.
  ///
  /// This does not establish continuous monitoring.
  Future<DevicePowerSnapshot> refresh();

  Future<void> dispose();
}

class BatteryPlusDevicePowerSource implements DevicePowerSource {
  factory BatteryPlusDevicePowerSource() {
    final battery = Battery();
    return BatteryPlusDevicePowerSource.withOperations(
      batteryLevel: () => battery.batteryLevel,
      batteryState: () => battery.batteryState,
      batteryStateChanges: battery.onBatteryStateChanged,
    );
  }

  BatteryPlusDevicePowerSource.withOperations({
    required Future<int> Function() batteryLevel,
    required Future<BatteryState> Function() batteryState,
    required Stream<BatteryState> batteryStateChanges,
  }) : this._(batteryLevel, batteryState, batteryStateChanges);

  BatteryPlusDevicePowerSource._(
    this._batteryLevel,
    this._batteryState,
    this._batteryStateChanges,
  );

  final Future<int> Function() _batteryLevel;
  final Future<BatteryState> Function() _batteryState;
  final Stream<BatteryState> _batteryStateChanges;
  final StreamController<DevicePowerSnapshot> _snapshots =
      StreamController<DevicePowerSnapshot>.broadcast();

  DevicePowerSnapshot _currentSnapshot = const DevicePowerSnapshot(
    batteryLevel: null,
    externalPower: ExternalPowerState.unknown,
  );
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Future<DevicePowerSnapshot>? _initialization;
  Future<DevicePowerSnapshot>? _refreshInFlight;
  bool _isDisposed = false;
  int _batteryLevelRevision = 0;
  int _externalPowerRevision = 0;

  @override
  DevicePowerSnapshot get currentSnapshot => _currentSnapshot;

  @override
  Stream<DevicePowerSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<DevicePowerSnapshot> initialize() {
    if (_isDisposed) return Future<DevicePowerSnapshot>.value(_currentSnapshot);
    return _initialization ??= _initialize();
  }

  Future<DevicePowerSnapshot> _initialize() async {
    _batteryStateSubscription = _batteryStateChanges.listen(
      _onBatteryStateChanged,
      onError: _onBatteryStateError,
    );
    return refresh();
  }

  @override
  Future<DevicePowerSnapshot> refresh() {
    if (_isDisposed) return Future<DevicePowerSnapshot>.value(_currentSnapshot);
    return _refreshInFlight ??= _refresh();
  }

  Future<DevicePowerSnapshot> _refresh() async {
    final batteryLevelRevision = ++_batteryLevelRevision;
    final externalPowerRevision = ++_externalPowerRevision;
    try {
      final values = await Future.wait<Object?>([
        _loadBatteryLevel(),
        _loadBatteryState(),
      ]);
      if (_isDisposed) {
        return _currentSnapshot;
      }
      _publishSnapshot(
        DevicePowerSnapshot(
          batteryLevel: batteryLevelRevision == _batteryLevelRevision
              ? values[0] as int?
              : _currentSnapshot.batteryLevel,
          externalPower: externalPowerRevision == _externalPowerRevision
              ? values[1]! as ExternalPowerState
              : _currentSnapshot.externalPower,
        ),
      );
      return _currentSnapshot;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<int?> _loadBatteryLevel() async {
    try {
      final level = await _batteryLevel();
      return level >= 0 && level <= 100 ? level : null;
    } on Object {
      return null;
    }
  }

  Future<ExternalPowerState> _loadBatteryState() async {
    try {
      return externalPowerFor(await _batteryState());
    } on Object {
      return ExternalPowerState.unknown;
    }
  }

  void _onBatteryStateChanged(BatteryState batteryState) {
    if (_isDisposed) return;
    _externalPowerRevision++;
    _publish(externalPower: externalPowerFor(batteryState));
  }

  void _onBatteryStateError(Object error, StackTrace stackTrace) {
    if (_isDisposed) return;
    _externalPowerRevision++;
    _publish(externalPower: ExternalPowerState.unknown);
  }

  void _publish({int? batteryLevel, ExternalPowerState? externalPower}) {
    _publishSnapshot(
      DevicePowerSnapshot(
        batteryLevel: batteryLevel ?? _currentSnapshot.batteryLevel,
        externalPower: externalPower ?? _currentSnapshot.externalPower,
      ),
    );
  }

  void _publishSnapshot(DevicePowerSnapshot next) {
    if (next == _currentSnapshot) return;
    _currentSnapshot = next;
    if (!_snapshots.isClosed) _snapshots.add(next);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _batteryLevelRevision++;
    _externalPowerRevision++;
    await _batteryStateSubscription?.cancel();
    await _snapshots.close();
  }

  static ExternalPowerState externalPowerFor(BatteryState batteryState) {
    return switch (batteryState) {
      BatteryState.charging ||
      BatteryState.full ||
      BatteryState.connectedNotCharging => ExternalPowerState.present,
      BatteryState.discharging => ExternalPowerState.absent,
      BatteryState.unknown => ExternalPowerState.unknown,
    };
  }
}

class FakeDevicePowerSource implements DevicePowerSource {
  FakeDevicePowerSource({
    this.initialSnapshot = const DevicePowerSnapshot(
      batteryLevel: null,
      externalPower: ExternalPowerState.unknown,
    ),
  }) : _currentSnapshot = initialSnapshot;

  final DevicePowerSnapshot initialSnapshot;
  final StreamController<DevicePowerSnapshot> _snapshots =
      StreamController<DevicePowerSnapshot>.broadcast();
  DevicePowerSnapshot _currentSnapshot;
  bool _isDisposed = false;

  @override
  DevicePowerSnapshot get currentSnapshot => _currentSnapshot;

  @override
  Stream<DevicePowerSnapshot> get snapshots => _snapshots.stream;

  void emit(DevicePowerSnapshot snapshot) {
    if (_isDisposed || snapshot == _currentSnapshot) return;
    _currentSnapshot = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  Future<DevicePowerSnapshot> initialize() {
    return Future<DevicePowerSnapshot>.value(_currentSnapshot);
  }

  @override
  Future<DevicePowerSnapshot> refresh() {
    return Future<DevicePowerSnapshot>.value(_currentSnapshot);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _snapshots.close();
  }
}
