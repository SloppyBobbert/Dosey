import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FlutterBluePlusBleGateway implements DoseyBleGateway {
  FlutterBluePlusBleGateway({FlutterBluePlusPlugin? plugin})
    : _plugin = plugin ?? FlutterBluePlusPluginAdapter();

  final FlutterBluePlusPlugin _plugin;
  final _connectionController =
      StreamController<BleConnectionSnapshot>.broadcast();
  final _protocolController = StreamController<List<int>>.broadcast();

  StreamSubscription<PluginBleConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _protocolSubscription;
  Future<void>? _activeConnectAttempt;
  int _connectGeneration = 0;
  String? _protocolSetupDeviceId;
  int? _protocolSetupGeneration;
  BleConnectionSnapshot _connectionSnapshot =
      const BleConnectionSnapshot.disconnected();

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() async* {
    yield _mapAvailability(_plugin.currentAdapterState);
    yield* _plugin.adapterStates.map(_mapAvailability).distinct();
  }

  @override
  Stream<BleConnectionSnapshot> watchConnection() async* {
    yield _connectionSnapshot;
    yield* _connectionController.stream;
  }

  @override
  Stream<List<int>> watchProtocolBytes() => _protocolController.stream;

  @override
  Future<void> connectToDosey() {
    final activeAttempt = _activeConnectAttempt;
    if (activeAttempt != null) return activeAttempt;

    late final Future<void> attempt;
    final generation = _connectGeneration;
    attempt = _connectToDosey(generation).whenComplete(() {
      if (identical(_activeConnectAttempt, attempt)) {
        _activeConnectAttempt = null;
      }
    });
    _activeConnectAttempt = attempt;
    return attempt;
  }

  Future<void> _connectToDosey(int generation) async {
    final result = await _plugin.scanForService(
      D1Protocol.serviceUuid,
      D1Protocol.deviceName,
      const Duration(seconds: 10),
    );
    if (generation != _connectGeneration) {
      throw StateError('Dosey controller connection was cancelled.');
    }
    if (result == null) {
      throw StateError('Dosey controller was not found.');
    }

    _protocolSetupDeviceId = result.deviceId;
    _protocolSetupGeneration = generation;
    try {
      await connect(deviceId: result.deviceId, deviceName: result.deviceName);
      if (generation != _connectGeneration) {
        throw StateError('Dosey controller connection was cancelled.');
      }
      if (!await _plugin.discoverDoseyProtocol(result.deviceId)) {
        throw StateError('Dosey BLE protocol characteristics were not found.');
      }
      if (generation != _connectGeneration) {
        throw StateError('Dosey controller connection was cancelled.');
      }
      await _clearProtocolSubscription();
      _protocolSubscription = _plugin
          .protocolValuesFor(result.deviceId)
          .listen(_protocolController.add);
      await _plugin.setProtocolNotifications(result.deviceId, true);
      if (generation != _connectGeneration) {
        throw StateError('Dosey controller connection was cancelled.');
      }
      _setConnection(
        BleConnectionSnapshot.connected(
          deviceId: result.deviceId,
          deviceName: result.deviceName,
        ),
      );
    } on Object {
      if (generation != _connectGeneration) {
        await _cleanupCancelledSetup(generation, result.deviceId);
      } else {
        await disconnect();
      }
      rethrow;
    } finally {
      if (_protocolSetupGeneration == generation) {
        _protocolSetupDeviceId = null;
        _protocolSetupGeneration = null;
      }
    }
  }

  Future<void> _cleanupCancelledSetup(int generation, String deviceId) async {
    if (_protocolSetupGeneration != generation) return;
    try {
      await _plugin.disconnect(deviceId);
    } on Object {
      // Cancellation cleanup is best effort; the connection attempt still
      // reports its original cancellation.
    }
    if (_protocolSetupGeneration != generation) return;
    await _clearConnectionSubscription();
    await _clearProtocolSubscription();
    _setConnection(const BleConnectionSnapshot.disconnected());
  }

  @override
  Future<void> writeProtocolBytes(List<int> bytes) async {
    final deviceId = _connectionSnapshot.deviceId;
    if (deviceId == null || _protocolSubscription == null) {
      throw StateError('Dosey BLE protocol is not connected.');
    }
    for (final chunk in D1Protocol.chunk(bytes)) {
      await _plugin.writeProtocol(deviceId, chunk);
    }
  }

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {
    final activeDeviceId = _connectionSnapshot.deviceId;
    if (activeDeviceId != null && activeDeviceId != deviceId) {
      // Keep one controller connection active at a time so status streams do not
      // mix events from two BLE devices.
      await disconnect();
    }
    await _clearConnectionSubscription();
    _setConnection(
      BleConnectionSnapshot.connecting(
        deviceId: deviceId,
        deviceName: deviceName,
      ),
    );
    _connectionSubscription = _plugin.deviceConnectionStates(deviceId).listen((
      state,
    ) {
      // Mirror native connection changes into an app-owned snapshot stream.
      _setConnection(
        state == PluginBleConnectionState.connected &&
                _protocolSetupDeviceId == deviceId
            ? BleConnectionSnapshot.connecting(
                deviceId: deviceId,
                deviceName: deviceName,
              )
            : _mapConnectionState(state, deviceId, deviceName),
      );
    });
    try {
      await _plugin.connect(deviceId);
    } catch (_) {
      await _clearConnectionSubscription();
      _setConnection(const BleConnectionSnapshot.disconnected());
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _connectGeneration += 1;
    if (_activeConnectAttempt != null) {
      await _plugin.cancelScan();
    }
    final deviceId = _connectionSnapshot.deviceId;
    final deviceName = _connectionSnapshot.deviceName;

    if (deviceId == null) {
      await _clearProtocolSubscription();
      _setConnection(const BleConnectionSnapshot.disconnected());
      return;
    }

    _setConnection(
      BleConnectionSnapshot.disconnecting(
        deviceId: deviceId,
        deviceName: deviceName,
      ),
    );
    try {
      await _clearProtocolSubscription();
      await _plugin.disconnect(deviceId);
    } catch (_) {
      await _clearConnectionSubscription();
      _setConnection(const BleConnectionSnapshot.disconnected());
      rethrow;
    }
    await _clearConnectionSubscription();
    _setConnection(const BleConnectionSnapshot.disconnected());
  }

  @override
  Future<void> close() async {
    _connectGeneration += 1;
    if (_activeConnectAttempt != null) {
      await _plugin.cancelScan();
    }
    final activeDeviceId = _connectionSnapshot.deviceId;
    if (activeDeviceId != null) {
      try {
        await _plugin.disconnect(activeDeviceId);
      } catch (_) {
        // Closing is best effort; keep disposal from surfacing transport errors.
      }
    }
    await _clearConnectionSubscription();
    await _clearProtocolSubscription();
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
    if (!_protocolController.isClosed) {
      await _protocolController.close();
    }
  }

  Future<void> _clearConnectionSubscription() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  Future<void> _clearProtocolSubscription() async {
    await _protocolSubscription?.cancel();
    _protocolSubscription = null;
  }

  void _setConnection(BleConnectionSnapshot snapshot) {
    _connectionSnapshot = snapshot;
    if (!_connectionController.isClosed) {
      _connectionController.add(snapshot);
    }
  }

  static BleAvailabilitySnapshot _mapAvailability(PluginBleAdapterState state) {
    // Treat unauthorized the same as unavailable for now; permissions UI can
    // explain why scanning/connecting is blocked.
    return switch (state) {
      PluginBleAdapterState.on => const BleAvailabilitySnapshot.available(),
      PluginBleAdapterState.off ||
      PluginBleAdapterState.unavailable ||
      PluginBleAdapterState.unauthorized =>
        const BleAvailabilitySnapshot.unavailable(),
      PluginBleAdapterState.unknown => const BleAvailabilitySnapshot.unknown(),
    };
  }

  static BleConnectionSnapshot _mapConnectionState(
    PluginBleConnectionState state,
    String deviceId,
    String? deviceName,
  ) {
    return switch (state) {
      PluginBleConnectionState.disconnected =>
        const BleConnectionSnapshot.disconnected(),
      PluginBleConnectionState.connecting => BleConnectionSnapshot.connecting(
        deviceId: deviceId,
        deviceName: deviceName,
      ),
      PluginBleConnectionState.connected => BleConnectionSnapshot.connected(
        deviceId: deviceId,
        deviceName: deviceName,
      ),
      PluginBleConnectionState.disconnecting =>
        BleConnectionSnapshot.disconnecting(
          deviceId: deviceId,
          deviceName: deviceName,
        ),
    };
  }
}

enum PluginBleAdapterState { unknown, unavailable, unauthorized, off, on }

enum PluginBleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class PluginBleScanResult {
  const PluginBleScanResult({required this.deviceId, this.deviceName});

  final String deviceId;
  final String? deviceName;
}

abstract interface class FlutterBluePlusPlugin {
  Stream<PluginBleAdapterState> get adapterStates;

  PluginBleAdapterState get currentAdapterState;

  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId);

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);

  Future<PluginBleScanResult?> scanForService(
    String serviceUuid,
    String deviceName,
    Duration timeout,
  );

  Future<void> cancelScan();

  Future<bool> discoverDoseyProtocol(String deviceId);

  Stream<List<int>> protocolValuesFor(String deviceId);

  Future<void> setProtocolNotifications(String deviceId, bool enabled);

  Future<void> writeProtocol(String deviceId, List<int> bytes);
}

class FlutterBluePlusPluginAdapter implements FlutterBluePlusPlugin {
  final Map<String, BluetoothCharacteristic> _commandCharacteristics = {};
  final Map<String, BluetoothCharacteristic> _eventCharacteristics = {};

  @override
  Stream<PluginBleAdapterState> get adapterStates {
    return FlutterBluePlus.adapterState.map(_mapAdapterState);
  }

  @override
  PluginBleAdapterState get currentAdapterState {
    return _mapAdapterState(FlutterBluePlus.adapterStateNow);
  }

  @override
  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId) {
    return BluetoothDevice.fromId(
      deviceId,
    ).connectionState.map(_mapConnectionState);
  }

  @override
  Future<void> connect(String deviceId) {
    return BluetoothDevice.fromId(deviceId).connect();
  }

  @override
  Future<void> disconnect(String deviceId) {
    _commandCharacteristics.remove(deviceId);
    _eventCharacteristics.remove(deviceId);
    return BluetoothDevice.fromId(deviceId).disconnect();
  }

  @override
  Future<PluginBleScanResult?> scanForService(
    String serviceUuid,
    String deviceName,
    Duration timeout,
  ) async {
    final result = Completer<PluginBleScanResult?>();
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (result.isCompleted) return;
      for (final match in results) {
        if (match.advertisementData.advName != deviceName) continue;
        result.complete(
          PluginBleScanResult(
            deviceId: match.device.remoteId.str,
            deviceName: deviceName,
          ),
        );
        return;
      }
    }, onError: result.completeError);
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(serviceUuid)],
        timeout: timeout,
      );
      return await result.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await subscription.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<void> cancelScan() => FlutterBluePlus.stopScan();

  @override
  Future<bool> discoverDoseyProtocol(String deviceId) async {
    final services = await BluetoothDevice.fromId(deviceId).discoverServices();
    BluetoothCharacteristic? command;
    BluetoothCharacteristic? events;
    for (final service in services) {
      if (service.uuid != Guid(D1Protocol.serviceUuid)) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == Guid(D1Protocol.commandCharacteristicUuid)) {
          command = characteristic;
        } else if (characteristic.uuid ==
            Guid(D1Protocol.eventCharacteristicUuid)) {
          events = characteristic;
        }
      }
    }
    if (command == null || events == null) return false;
    _commandCharacteristics[deviceId] = command;
    _eventCharacteristics[deviceId] = events;
    return true;
  }

  @override
  Stream<List<int>> protocolValuesFor(String deviceId) {
    final characteristic = _eventCharacteristics[deviceId];
    if (characteristic == null) {
      throw StateError('Dosey event characteristic is not discovered.');
    }
    return characteristic.onValueReceived;
  }

  @override
  Future<void> setProtocolNotifications(String deviceId, bool enabled) async {
    final characteristic = _eventCharacteristics[deviceId];
    if (characteristic == null) {
      throw StateError('Dosey event characteristic is not discovered.');
    }
    await characteristic.setNotifyValue(enabled);
  }

  @override
  Future<void> writeProtocol(String deviceId, List<int> bytes) async {
    final characteristic = _commandCharacteristics[deviceId];
    if (characteristic == null) {
      throw StateError('Dosey command characteristic is not discovered.');
    }
    await characteristic.write(bytes, withoutResponse: false);
  }

  static PluginBleAdapterState _mapAdapterState(BluetoothAdapterState state) {
    return switch (state) {
      BluetoothAdapterState.unknown => PluginBleAdapterState.unknown,
      BluetoothAdapterState.unavailable => PluginBleAdapterState.unavailable,
      BluetoothAdapterState.unauthorized => PluginBleAdapterState.unauthorized,
      BluetoothAdapterState.off => PluginBleAdapterState.off,
      BluetoothAdapterState.on => PluginBleAdapterState.on,
      _ => PluginBleAdapterState.unknown,
    };
  }

  static PluginBleConnectionState _mapConnectionState(
    BluetoothConnectionState state,
  ) {
    if (state == BluetoothConnectionState.connected) {
      return PluginBleConnectionState.connected;
    }
    return PluginBleConnectionState.disconnected;
  }
}
