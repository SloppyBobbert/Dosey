import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class FlutterBluePlusBleGateway implements BleGateway {
  FlutterBluePlusBleGateway({FlutterBluePlusPlugin? plugin})
    : _plugin = plugin ?? FlutterBluePlusPluginAdapter();

  final FlutterBluePlusPlugin _plugin;
  final _connectionController =
      StreamController<BleConnectionSnapshot>.broadcast();

  StreamSubscription<PluginBleConnectionState>? _connectionSubscription;
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
      _setConnection(_mapConnectionState(state, deviceId, deviceName));
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
    final deviceId = _connectionSnapshot.deviceId;
    final deviceName = _connectionSnapshot.deviceName;

    if (deviceId == null) {
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
    final activeDeviceId = _connectionSnapshot.deviceId;
    if (activeDeviceId != null) {
      try {
        await _plugin.disconnect(activeDeviceId);
      } catch (_) {
        // Closing is best effort; keep disposal from surfacing transport errors.
      }
    }
    await _clearConnectionSubscription();
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
  }

  Future<void> _clearConnectionSubscription() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  void _setConnection(BleConnectionSnapshot snapshot) {
    _connectionSnapshot = snapshot;
    _connectionController.add(snapshot);
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

abstract interface class FlutterBluePlusPlugin {
  Stream<PluginBleAdapterState> get adapterStates;

  PluginBleAdapterState get currentAdapterState;

  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId);

  Future<void> connect(String deviceId);

  Future<void> disconnect(String deviceId);
}

class FlutterBluePlusPluginAdapter implements FlutterBluePlusPlugin {
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
    return BluetoothDevice.fromId(deviceId).disconnect();
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
