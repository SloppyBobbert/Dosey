import 'dart:async';
import 'dart:convert';

import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';

class FakeFlutterBluePlusPlugin implements FlutterBluePlusPlugin {
  FakeFlutterBluePlusPlugin({
    this._currentAdapterState = PluginBleAdapterState.on,
    this.scanResult = const PluginBleScanResult(
      deviceId: deviceId,
      deviceName: D1Protocol.deviceName,
    ),
  });

  static const deviceId = 'dosey-test-controller';

  final _adapterController =
      StreamController<PluginBleAdapterState>.broadcast();
  final _connectionController =
      StreamController<PluginBleConnectionState>.broadcast();
  final _protocolController = StreamController<List<int>>.broadcast();

  PluginBleAdapterState _currentAdapterState;

  @override
  PluginBleAdapterState get currentAdapterState => _currentAdapterState;

  @override
  Stream<PluginBleAdapterState> get adapterStates => _adapterController.stream;

  PluginBleScanResult? scanResult;
  bool protocolDiscovered = true;
  Completer<void>? scanGate;
  Completer<void>? connectGate;
  Completer<void>? notificationGate;
  Completer<void>? writeGate;
  Object? connectError;
  Object? disconnectError;
  Object? writeError;

  final List<String> scanServiceUuids = [];
  final List<String> scanDeviceNames = [];
  final List<String> connectCalls = [];
  final List<String> disconnectCalls = [];
  final List<String> discoveryCalls = [];
  final List<(String, bool)> notificationCalls = [];
  final List<(String, List<int>)> writes = [];
  int cancelScanCalls = 0;

  @override
  Future<PluginBleScanResult?> scanForService(
    String serviceUuid,
    String deviceName,
    Duration timeout,
  ) async {
    scanServiceUuids.add(serviceUuid);
    scanDeviceNames.add(deviceName);
    await scanGate?.future;
    return scanResult;
  }

  @override
  Future<void> cancelScan() async {
    cancelScanCalls += 1;
  }

  @override
  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId) {
    return _connectionController.stream;
  }

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    await connectGate?.future;
    _throwIfPresent(connectError);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectCalls.add(deviceId);
    _throwIfPresent(disconnectError);
  }

  @override
  Future<bool> discoverDoseyProtocol(String deviceId) async {
    discoveryCalls.add(deviceId);
    return protocolDiscovered;
  }

  @override
  Stream<List<int>> protocolValuesFor(String deviceId) {
    return _protocolController.stream;
  }

  @override
  Future<void> setProtocolNotifications(String deviceId, bool enabled) async {
    notificationCalls.add((deviceId, enabled));
    await notificationGate?.future;
  }

  @override
  Future<void> writeProtocol(String deviceId, List<int> bytes) async {
    await writeGate?.future;
    _throwIfPresent(writeError);
    writes.add((deviceId, List<int>.from(bytes)));
  }

  void emitAdapter(PluginBleAdapterState state) {
    _currentAdapterState = state;
    _adapterController.add(state);
  }

  void emitConnection(PluginBleConnectionState state) {
    _connectionController.add(state);
  }

  void emitDisconnected() {
    emitConnection(PluginBleConnectionState.disconnected);
  }

  void emitProtocolBytes(List<int> bytes) {
    _protocolController.add(List<int>.from(bytes));
  }

  List<int> get writtenBytes => [for (final write in writes) ...write.$2];

  List<String> get writtenLines => ascii
      .decode(writtenBytes)
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  void clearWrites() => writes.clear();

  Future<void> close() async {
    await _adapterController.close();
    await _connectionController.close();
    await _protocolController.close();
  }

  void _throwIfPresent(Object? error) {
    if (error == null) return;
    Error.throwWithStackTrace(error, StackTrace.current);
  }
}
