import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ble availability and connection snapshots expose safe defaults', () {
    const availability = BleAvailabilitySnapshot.unavailable();
    const connection = BleConnectionSnapshot.disconnected();

    expect(availability.state, BleAvailabilityState.unavailable);
    expect(availability.isAvailable, isFalse);
    expect(connection.state, BleConnectionState.disconnected);
    expect(connection.deviceId, isNull);
    expect(connection.deviceName, isNull);
  });

  test('plugin wrapper maps adapter state and connection state', () async {
    final adapterStates = StreamController<PluginBleAdapterState>.broadcast();
    final connectionStates =
        StreamController<PluginBleConnectionState>.broadcast();
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: adapterStates.stream,
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': connectionStates.stream},
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    expect(
      await gateway.watchAvailability().first,
      const BleAvailabilitySnapshot.available(),
    );

    final connectedSnapshot = gateway.watchConnection().firstWhere(
      (snapshot) => snapshot.state == BleConnectionState.connected,
    );

    await gateway.connect(deviceId: 'dosey-1', deviceName: 'Dosey Proto');
    await Future<void>.delayed(Duration.zero);
    connectionStates.add(PluginBleConnectionState.connected);
    expect(
      await connectedSnapshot,
      const BleConnectionSnapshot.connected(
        deviceId: 'dosey-1',
        deviceName: 'Dosey Proto',
      ),
    );
    expect(plugin.connectCalls, ['dosey-1']);

    await gateway.disconnect();
    expect(plugin.disconnectCalls, ['dosey-1']);

    await gateway.close();
    await connectionStates.close();
    await adapterStates.close();
  });

  test('connect failure restores disconnected state and rethrows', () async {
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
      connectError: StateError('connect failed'),
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    await expectLater(
      gateway.connect(deviceId: 'dosey-1', deviceName: 'Dosey Proto'),
      throwsStateError,
    );

    expect(
      await gateway.watchConnection().first,
      const BleConnectionSnapshot.disconnected(),
    );

    await gateway.close();
  });

  test('disconnect failure restores disconnected state and rethrows', () async {
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
      disconnectError: StateError('disconnect failed'),
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    await gateway.connect(deviceId: 'dosey-1', deviceName: 'Dosey Proto');

    await expectLater(gateway.disconnect(), throwsStateError);

    expect(
      await gateway.watchConnection().first,
      const BleConnectionSnapshot.disconnected(),
    );

    await gateway.close();
  });
}

class _FakeFlutterBluePlusPlugin implements FlutterBluePlusPlugin {
  _FakeFlutterBluePlusPlugin({
    required this.adapterStates,
    required this.currentAdapterState,
    required this.connectionStatesByDeviceId,
    this.connectError,
    this.disconnectError,
  });

  @override
  final Stream<PluginBleAdapterState> adapterStates;

  @override
  final PluginBleAdapterState currentAdapterState;

  final Map<String, Stream<PluginBleConnectionState>>
  connectionStatesByDeviceId;
  final Object? connectError;
  final Object? disconnectError;
  final List<String> connectCalls = [];
  final List<String> disconnectCalls = [];

  @override
  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId) {
    return connectionStatesByDeviceId[deviceId] ?? const Stream.empty();
  }

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    if (connectError case final Error error) {
      throw error;
    }
    if (connectError case final Exception exception) {
      throw exception;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectCalls.add(deviceId);
    if (disconnectError case final Error error) {
      throw error;
    }
    if (disconnectError case final Exception exception) {
      throw exception;
    }
  }
}
