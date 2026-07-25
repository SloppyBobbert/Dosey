enum BleAvailabilityState { unknown, unavailable, available }

enum BleConnectionState { disconnected, connecting, connected, disconnecting }

class BleAvailabilitySnapshot {
  const BleAvailabilitySnapshot(this.state);

  const BleAvailabilitySnapshot.unknown()
    : state = BleAvailabilityState.unknown;

  const BleAvailabilitySnapshot.unavailable()
    : state = BleAvailabilityState.unavailable;

  const BleAvailabilitySnapshot.available()
    : state = BleAvailabilityState.available;

  final BleAvailabilityState state;

  bool get isAvailable => state == BleAvailabilityState.available;

  @override
  bool operator ==(Object other) {
    return other is BleAvailabilitySnapshot && other.state == state;
  }

  @override
  int get hashCode => state.hashCode;
}

class BleConnectionSnapshot {
  const BleConnectionSnapshot({
    required this.state,
    this.deviceId,
    this.deviceName,
  });

  const BleConnectionSnapshot.disconnected()
    : state = BleConnectionState.disconnected,
      deviceId = null,
      deviceName = null;

  const BleConnectionSnapshot.connecting({
    required this.deviceId,
    this.deviceName,
  }) : state = BleConnectionState.connecting;

  const BleConnectionSnapshot.connected({
    required this.deviceId,
    this.deviceName,
  }) : state = BleConnectionState.connected;

  const BleConnectionSnapshot.disconnecting({
    required this.deviceId,
    this.deviceName,
  }) : state = BleConnectionState.disconnecting;

  final BleConnectionState state;
  final String? deviceId;
  final String? deviceName;

  @override
  bool operator ==(Object other) {
    return other is BleConnectionSnapshot &&
        other.state == state &&
        other.deviceId == deviceId &&
        other.deviceName == deviceName;
  }

  @override
  int get hashCode => Object.hash(state, deviceId, deviceName);
}

abstract interface class BleGateway {
  Stream<BleAvailabilitySnapshot> watchAvailability();

  Stream<BleConnectionSnapshot> watchConnection();

  Future<void> connect({required String deviceId, String? deviceName});

  Future<void> disconnect();

  Future<void> close();
}

abstract interface class DoseyBleTransport {
  Stream<List<int>> watchProtocolBytes();

  Future<void> connectToDosey();

  Future<void> writeProtocolBytes(List<int> bytes);
}

abstract interface class DoseyBleGateway
    implements BleGateway, DoseyBleTransport {}
