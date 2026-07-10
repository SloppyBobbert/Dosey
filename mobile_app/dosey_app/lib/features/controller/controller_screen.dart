import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
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
        final platform = currentAppDevicePlatform();
        final fallbackRole = AppDeviceRole.defaultFor(platform);
        final storedRole = roleSnapshot.data;
        final role = storedRole != null && storedRole.isAllowedOn(platform)
            ? storedRole
            : fallbackRole;
        return StreamBuilder<ControllerSnapshot>(
          stream: dependencies.controller.watchController(),
          builder: (context, controllerSnapshot) {
            final controller =
                controllerSnapshot.data ??
                const ControllerSnapshot.disconnected();
            // Manual commands are allowed only from a robot-capable phone with
            // a connected controller; Personal Mode stays read-only here.
            final canDispense =
                role.canHostRobot && controller.canRequestDispense;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ControllerHeroCard(
                  controller: controller,
                  role: role,
                  onConnect: () => _runControllerAction(
                    context,
                    dependencies.controller.connect,
                  ),
                  onDisconnect: () => _runControllerAction(
                    context,
                    dependencies.controller.disconnect,
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
                              ? () => _runControllerAction(
                                  context,
                                  () => dependencies.controller.requestDispense(
                                    doseId: 'manual-test',
                                  ),
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

  Future<void> _runControllerAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Controller action failed: $error')),
      );
    }
  }
}

class _ControllerHeroCard extends StatelessWidget {
  const _ControllerHeroCard({
    required this.controller,
    required this.role,
    required this.onConnect,
    required this.onDisconnect,
  });

  final ControllerSnapshot controller;
  final AppDeviceRole role;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isConnected =
        controller.connectionState == ControllerConnectionState.connected;
    final connectionLabel = isConnected
        ? 'Controller connected'
        : 'Controller offline';
    final roleLabel = role.canHostRobot ? 'Robot phone' : 'Personal phone';

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.onPrimaryContainer,
                  foregroundColor: colorScheme.primaryContainer,
                  child: const Icon(Icons.memory_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hardware bench',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'XIAO ESP32-C6',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              controller.statusLabel,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Demo simulator only. Real BLE comes after protocol work.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ControllerHeroChip(
                  icon: isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  label: connectionLabel,
                ),
                _ControllerHeroChip(
                  icon: Icons.smartphone_outlined,
                  label: roleLabel,
                ),
                const _ControllerHeroChip(
                  icon: Icons.lock_outline,
                  label: 'Manual safety lock',
                ),
                const _ControllerHeroChip(
                  icon: Icons.schema_outlined,
                  label: 'BLE protocol pending',
                ),
                const _ControllerHeroChip(
                  icon: Icons.cable_outlined,
                  label: 'Simulator bridge',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onConnect,
                  child: const Text('Connect simulator'),
                ),
                OutlinedButton(
                  onPressed: onDisconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControllerHeroChip extends StatelessWidget {
  const _ControllerHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
