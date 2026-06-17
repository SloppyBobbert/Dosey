import 'dart:async';

import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'connectivity wrapper maps plugin results to app-owned states',
    () async {
      final updates = StreamController<List<PluginConnectivityType>>();
      final plugin = _FakeConnectivityPlusPlugin(
        initialTypes: const [PluginConnectivityType.none],
        updates: updates.stream,
      );
      final gateway = ConnectivityPlusGateway(plugin: plugin);
      addTearDown(updates.close);

      expect(await gateway.currentConnectivity(), ConnectivityState.offline);

      final states = gateway.watchConnectivity().take(4).toList();
      updates.add(const [PluginConnectivityType.wifi]);
      updates.add(const [PluginConnectivityType.mobile]);
      updates.add(const [PluginConnectivityType.vpn]);

      expect(await states, [
        ConnectivityState.offline,
        ConnectivityState.wifi,
        ConnectivityState.cellular,
        ConnectivityState.other,
      ]);
    },
  );
}

class _FakeConnectivityPlusPlugin implements ConnectivityPlusPlugin {
  _FakeConnectivityPlusPlugin({
    required this.initialTypes,
    required this.updates,
  });

  final List<PluginConnectivityType> initialTypes;

  @override
  Future<List<PluginConnectivityType>> currentTypes() async => initialTypes;

  @override
  final Stream<List<PluginConnectivityType>> updates;
}
