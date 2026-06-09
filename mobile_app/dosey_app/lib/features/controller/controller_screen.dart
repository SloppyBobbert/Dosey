import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/material.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.settings.watchDeviceRole(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? AppDeviceRole.androidPersonal;
        return StreamBuilder<ControllerSnapshot>(
          stream: dependencies.controller.watchController(),
          builder: (context, controllerSnapshot) {
            final controller =
                controllerSnapshot.data ??
                const ControllerSnapshot.disconnected();
            final canDispense =
                role.canHostRobot && controller.canRequestDispense;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.statusLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo simulator only. Real BLE comes after protocol work.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: dependencies.controller.connect,
                              child: const Text('Connect simulator'),
                            ),
                            OutlinedButton(
                              onPressed: dependencies.controller.disconnect,
                              child: const Text('Disconnect'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual dispense test',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Locked until Android robot mode and a controller connection are active.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Never mark a dose taken because the servo moved.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: canDispense
                              ? () => dependencies.controller.requestDispense(
                                  doseId: 'manual-test',
                                )
                              : null,
                          icon: Icon(
                            canDispense ? Icons.play_arrow : Icons.lock_outline,
                          ),
                          label: Text(
                            canDispense
                                ? 'Run simulated dispense'
                                : 'Dispense disabled',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
