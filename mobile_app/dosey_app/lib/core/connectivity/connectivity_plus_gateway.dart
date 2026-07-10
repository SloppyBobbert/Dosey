import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';

class ConnectivityPlusGateway implements ConnectivityGateway {
  ConnectivityPlusGateway({ConnectivityPlusPlugin? plugin})
    : _plugin = plugin ?? ConnectivityPlusPluginAdapter();

  final ConnectivityPlusPlugin _plugin;

  @override
  Future<ConnectivityState> currentConnectivity() async {
    return _mapConnectivity(await _plugin.currentTypes());
  }

  @override
  Stream<ConnectivityState> watchConnectivity() async* {
    // Seed listeners with the current state; plugin streams only emit changes.
    yield await currentConnectivity();
    yield* _plugin.updates.map(_mapConnectivity).distinct();
  }

  static ConnectivityState _mapConnectivity(
    List<PluginConnectivityType> types,
  ) {
    if (types.contains(PluginConnectivityType.wifi)) {
      return ConnectivityState.wifi;
    }
    if (types.contains(PluginConnectivityType.mobile)) {
      return ConnectivityState.cellular;
    }
    if (types.isEmpty || types.contains(PluginConnectivityType.none)) {
      return ConnectivityState.offline;
    }
    return ConnectivityState.other;
  }
}

enum PluginConnectivityType { none, wifi, mobile, other, vpn }

abstract interface class ConnectivityPlusPlugin {
  Future<List<PluginConnectivityType>> currentTypes();

  Stream<List<PluginConnectivityType>> get updates;
}

class ConnectivityPlusPluginAdapter implements ConnectivityPlusPlugin {
  final Connectivity _connectivity = Connectivity();

  @override
  Future<List<PluginConnectivityType>> currentTypes() async {
    final results = await _connectivity.checkConnectivity();
    return results.map(_mapType).toList(growable: false);
  }

  @override
  Stream<List<PluginConnectivityType>> get updates {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.map(_mapType).toList(growable: false),
    );
  }

  static PluginConnectivityType _mapType(ConnectivityResult result) {
    return switch (result) {
      ConnectivityResult.none => PluginConnectivityType.none,
      ConnectivityResult.wifi => PluginConnectivityType.wifi,
      ConnectivityResult.mobile => PluginConnectivityType.mobile,
      ConnectivityResult.vpn => PluginConnectivityType.vpn,
      _ => PluginConnectivityType.other,
    };
  }
}
