enum ConnectivityState { offline, wifi, cellular, other }

abstract interface class ConnectivityGateway {
  Stream<ConnectivityState> watchConnectivity();

  Future<ConnectivityState> currentConnectivity();
}
