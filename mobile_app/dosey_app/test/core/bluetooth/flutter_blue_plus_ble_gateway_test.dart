import 'dart:async';

import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/controller/d1_protocol.dart';
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

  test(
    'connecting to a different device disconnects the active device first',
    () async {
      final plugin = _FakeFlutterBluePlusPlugin(
        adapterStates: const Stream.empty(),
        currentAdapterState: PluginBleAdapterState.on,
        connectionStatesByDeviceId: {
          'dosey-1': const Stream.empty(),
          'dosey-2': const Stream.empty(),
        },
      );
      final gateway = FlutterBluePlusBleGateway(plugin: plugin);

      await gateway.connect(deviceId: 'dosey-1', deviceName: 'Dosey One');
      await gateway.connect(deviceId: 'dosey-2', deviceName: 'Dosey Two');

      expect(plugin.connectCalls, ['dosey-1', 'dosey-2']);
      expect(plugin.disconnectCalls, ['dosey-1']);

      await gateway.close();
    },
  );

  test('close disconnects the active device before shutting down', () async {
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    await gateway.connect(deviceId: 'dosey-1', deviceName: 'Dosey One');
    await gateway.close();

    expect(plugin.disconnectCalls, ['dosey-1']);
  });

  test(
    'Dosey connect discovers, subscribes, and chunks protocol writes',
    () async {
      final notifications = StreamController<List<int>>.broadcast();
      final plugin = _FakeFlutterBluePlusPlugin(
        adapterStates: const Stream.empty(),
        currentAdapterState: PluginBleAdapterState.on,
        connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
        scanResult: const PluginBleScanResult(
          deviceId: 'dosey-1',
          deviceName: 'Dosey-XIAO-C6',
        ),
        protocolValues: notifications.stream,
      );
      final gateway = FlutterBluePlusBleGateway(plugin: plugin);

      final received = gateway.watchProtocolBytes().first;
      await gateway.connectToDosey();
      notifications.add([1, 2, 3]);
      await gateway.writeProtocolBytes(
        List<int>.generate(43, (index) => index),
      );

      expect(await received, [1, 2, 3]);
      expect(plugin.scanServiceUuids, [D1Protocol.serviceUuid]);
      expect(plugin.scanDeviceNames, [D1Protocol.deviceName]);
      expect(plugin.discoveryCalls, ['dosey-1']);
      expect(plugin.notifyCalls, [('dosey-1', true)]);
      expect(plugin.writes.map((write) => write.$2.length), [20, 20, 3]);

      await gateway.close();
      await notifications.close();
    },
  );

  test('overlapping Dosey connects share one protocol setup attempt', () async {
    final notificationSetup = Completer<void>();
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
      scanResult: const PluginBleScanResult(
        deviceId: 'dosey-1',
        deviceName: 'Dosey-XIAO-C6',
      ),
      notificationSetup: notificationSetup,
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    final first = gateway.connectToDosey();
    final second = gateway.connectToDosey();
    await Future<void>.delayed(Duration.zero);

    expect(plugin.scanServiceUuids, [D1Protocol.serviceUuid]);
    expect(plugin.connectCalls, ['dosey-1']);

    notificationSetup.complete();
    await Future.wait([first, second]);

    await gateway.close();
  });

  test(
    'disconnect cancels an active scan and prevents a late connection',
    () async {
      final scanGate = Completer<void>();
      final plugin = _FakeFlutterBluePlusPlugin(
        adapterStates: const Stream.empty(),
        currentAdapterState: PluginBleAdapterState.on,
        connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
        scanResult: const PluginBleScanResult(
          deviceId: 'dosey-1',
          deviceName: 'Dosey-XIAO-C6',
        ),
        scanGate: scanGate,
      );
      final gateway = FlutterBluePlusBleGateway(plugin: plugin);

      final connection = gateway.connectToDosey();
      await Future<void>.delayed(Duration.zero);
      await gateway.disconnect();
      scanGate.complete();
      await connection;

      expect(plugin.cancelScanCalls, 1);
      expect(plugin.connectCalls, isEmpty);
      expect(
        await gateway.watchConnection().first,
        const BleConnectionSnapshot.disconnected(),
      );

      await gateway.close();
    },
  );

  test('disconnect cleans up a physical connect that completes late', () async {
    final connectGate = Completer<void>();
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
      scanResult: const PluginBleScanResult(
        deviceId: 'dosey-1',
        deviceName: 'Dosey-XIAO-C6',
      ),
      connectGate: connectGate,
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    final connection = gateway.connectToDosey();
    await Future<void>.delayed(Duration.zero);
    expect(plugin.connectCalls, ['dosey-1']);

    await gateway.disconnect();
    connectGate.complete();
    await connection;

    expect(plugin.connectedDeviceIds, isEmpty);
    expect(plugin.disconnectCalls, ['dosey-1', 'dosey-1']);

    await gateway.close();
  });

  test('close cancels an active scan and prevents a late connection', () async {
    final scanGate = Completer<void>();
    final plugin = _FakeFlutterBluePlusPlugin(
      adapterStates: const Stream.empty(),
      currentAdapterState: PluginBleAdapterState.on,
      connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
      scanResult: const PluginBleScanResult(
        deviceId: 'dosey-1',
        deviceName: 'Dosey-XIAO-C6',
      ),
      scanGate: scanGate,
    );
    final gateway = FlutterBluePlusBleGateway(plugin: plugin);

    final connection = gateway.connectToDosey();
    await Future<void>.delayed(Duration.zero);
    await gateway.close();
    scanGate.complete();
    await connection;

    expect(plugin.cancelScanCalls, 1);
    expect(plugin.connectCalls, isEmpty);
  });

  test(
    'Dosey connection is not ready before protocol setup completes',
    () async {
      final connectionStates =
          StreamController<PluginBleConnectionState>.broadcast();
      final notificationSetup = Completer<void>();
      final plugin = _FakeFlutterBluePlusPlugin(
        adapterStates: const Stream.empty(),
        currentAdapterState: PluginBleAdapterState.on,
        connectionStatesByDeviceId: {'dosey-1': connectionStates.stream},
        scanResult: const PluginBleScanResult(
          deviceId: 'dosey-1',
          deviceName: 'Dosey-XIAO-C6',
        ),
        notificationSetup: notificationSetup,
      );
      final gateway = FlutterBluePlusBleGateway(plugin: plugin);
      final snapshots = <BleConnectionSnapshot>[];
      final subscription = gateway.watchConnection().listen(snapshots.add);

      final connecting = gateway.connectToDosey();
      await Future<void>.delayed(Duration.zero);
      connectionStates.add(PluginBleConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(
        snapshots.where(
          (snapshot) => snapshot.state == BleConnectionState.connected,
        ),
        isEmpty,
      );

      notificationSetup.complete();
      await connecting;
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.state, BleConnectionState.connected);

      await subscription.cancel();
      await gateway.close();
      await connectionStates.close();
    },
  );

  test(
    'Dosey connect fails when required characteristics are absent',
    () async {
      final plugin = _FakeFlutterBluePlusPlugin(
        adapterStates: const Stream.empty(),
        currentAdapterState: PluginBleAdapterState.on,
        connectionStatesByDeviceId: {'dosey-1': const Stream.empty()},
        scanResult: const PluginBleScanResult(
          deviceId: 'dosey-1',
          deviceName: 'Dosey-XIAO-C6',
        ),
        protocolDiscovered: false,
      );
      final gateway = FlutterBluePlusBleGateway(plugin: plugin);

      await expectLater(gateway.connectToDosey(), throwsStateError);
      expect(plugin.disconnectCalls, ['dosey-1']);

      await gateway.close();
    },
  );
}

class _FakeFlutterBluePlusPlugin implements FlutterBluePlusPlugin {
  _FakeFlutterBluePlusPlugin({
    required this.adapterStates,
    required this.currentAdapterState,
    required this.connectionStatesByDeviceId,
    this.connectError,
    this.disconnectError,
    this.scanResult,
    this.protocolValues = const Stream.empty(),
    this.protocolDiscovered = true,
    this.notificationSetup,
    this.scanGate,
    this.connectGate,
  });

  @override
  final Stream<PluginBleAdapterState> adapterStates;

  @override
  final PluginBleAdapterState currentAdapterState;

  final Map<String, Stream<PluginBleConnectionState>>
  connectionStatesByDeviceId;
  final Object? connectError;
  final Object? disconnectError;
  final PluginBleScanResult? scanResult;
  final Stream<List<int>> protocolValues;
  final bool protocolDiscovered;
  final Completer<void>? notificationSetup;
  final Completer<void>? scanGate;
  final Completer<void>? connectGate;
  final List<String> connectCalls = [];
  final List<String> disconnectCalls = [];
  final Set<String> connectedDeviceIds = {};
  final List<String> scanServiceUuids = [];
  final List<String> scanDeviceNames = [];
  final List<String> discoveryCalls = [];
  final List<(String, bool)> notifyCalls = [];
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
  Future<bool> discoverDoseyProtocol(String deviceId) async {
    discoveryCalls.add(deviceId);
    return protocolDiscovered;
  }

  @override
  Stream<List<int>> protocolValuesFor(String deviceId) => protocolValues;

  @override
  Future<void> setProtocolNotifications(String deviceId, bool enabled) async {
    notifyCalls.add((deviceId, enabled));
    await notificationSetup?.future;
  }

  @override
  Future<void> writeProtocol(String deviceId, List<int> bytes) async {
    writes.add((deviceId, bytes));
  }

  @override
  Stream<PluginBleConnectionState> deviceConnectionStates(String deviceId) {
    return connectionStatesByDeviceId[deviceId] ?? const Stream.empty();
  }

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    await connectGate?.future;
    if (connectError case final Error error) {
      throw error;
    }
    if (connectError case final Exception exception) {
      throw exception;
    }
    connectedDeviceIds.add(deviceId);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectCalls.add(deviceId);
    connectedDeviceIds.remove(deviceId);
    if (disconnectError case final Error error) {
      throw error;
    }
    if (disconnectError case final Exception exception) {
      throw exception;
    }
  }
}
