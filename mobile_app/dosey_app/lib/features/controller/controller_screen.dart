import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/demo/demo_mode_host.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/material.dart';

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final commandRepository = dependencies.controllerCommands;
    final demoMode = DemoModeHost.maybeOf(context);

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (dependencies.isDemo &&
                    dependencies.demoScenarios != null) ...[
                  _DemoScenarioCard(
                    scenarios: dependencies.demoScenarios!,
                    canPresent: role.canHostRobot,
                    onExit: demoMode?.exit,
                    runAction: (action) =>
                        _runControllerAction(context, action),
                  ),
                  const SizedBox(height: 12),
                ],
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
                StreamBuilder<ControllerCommandSession?>(
                  stream: commandRepository.watchLatestRelevantSession(),
                  builder: (context, sessionSnapshot) {
                    return _ControllerCommandStatusCard(
                      session: sessionSnapshot.data,
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (dependencies.isDemo) ...[
                  _ControllerBenchCard(
                    runCommand: (command) => _runControllerAction(
                      context,
                      () => dependencies.controllerBench.run(command),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                                  dependencies
                                      .controllerLifecycle
                                      .requestManualDispenseTest,
                                  requiresPin: true,
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
                const SizedBox(height: 12),
                StreamBuilder<List<ControllerCommandHistoryEntry>>(
                  stream: commandRepository.watchRecentHistory(),
                  builder: (context, historySnapshot) {
                    return _ControllerHistoryCard(
                      history: historySnapshot.data ?? const [],
                    );
                  },
                ),
                if (!dependencies.isDemo && demoMode != null) ...[
                  const SizedBox(height: 12),
                  _EnterDemoCard(
                    onEnter: () =>
                        _runControllerAction(context, demoMode.enter),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runControllerAction(
    BuildContext context,
    Future<void> Function() action, {
    bool requiresPin = false,
  }) async {
    if (requiresPin && !await authorizeActionPin(context)) {
      return;
    }
    if (!context.mounted) return;
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

class _EnterDemoCard extends StatelessWidget {
  const _EnterDemoCard({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deterministic demo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Run fake controller and dose scenarios in a separate database. Your real local data is not changed.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEnter,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Enter demo mode'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoScenarioCard extends StatelessWidget {
  const _DemoScenarioCard({
    required this.scenarios,
    required this.canPresent,
    required this.onExit,
    required this.runAction,
  });

  final DemoScenarioService scenarios;
  final bool canPresent;
  final Future<void> Function(Future<void> Function() action) runAction;
  final Future<void> Function()? onExit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DemoScenarioState>(
      stream: scenarios.states,
      initialData: scenarios.state,
      builder: (context, snapshot) {
        final state = snapshot.requireData;
        return Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo scenario runner',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(state.scenario.description),
                const SizedBox(height: 12),
                DropdownButtonFormField<DemoScenarioId>(
                  initialValue: state.scenario.id,
                  decoration: const InputDecoration(labelText: 'Scenario'),
                  items: [
                    for (final scenario in demoScenarioCatalog)
                      DropdownMenuItem(
                        value: scenario.id,
                        child: Text(scenario.title),
                      ),
                  ],
                  onChanged: state.isPlaying
                      ? null
                      : (id) {
                          if (id != null) {
                            runAction(() => scenarios.select(id));
                          }
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  '${state.completedSteps} of ${state.scenario.steps.length} steps complete',
                ),
                const SizedBox(height: 4),
                Text(
                  state.nextStep == null
                      ? 'Scenario complete'
                      : 'Next: ${state.nextStep!.label}',
                ),
                if (state.lastMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(state.lastMessage!),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canPresent)
                      FilledButton.icon(
                        onPressed: state.isPlaying
                            ? null
                            : () => runAction(scenarios.startPresentation),
                        icon: const Icon(Icons.present_to_all_outlined),
                        label: const Text('Start presentation'),
                      ),
                    FilledButton.icon(
                      onPressed: state.isPlaying || state.isComplete
                          ? null
                          : () => runAction(scenarios.next),
                      icon: const Icon(Icons.skip_next_outlined),
                      label: const Text('Next step'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: state.isComplete
                          ? null
                          : state.isPlaying
                          ? scenarios.pause
                          : () => runAction(scenarios.play),
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(state.isPlaying ? 'Pause' : 'Auto-play'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => runAction(scenarios.restart),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restart'),
                    ),
                    if (onExit != null)
                      OutlinedButton.icon(
                        onPressed: () => runAction(onExit!),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Exit demo mode'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ControllerBenchCard extends StatelessWidget {
  const _ControllerBenchCard({required this.runCommand});

  final Future<void> Function(ControllerBenchCommand command) runCommand;

  @override
  Widget build(BuildContext context) {
    const commands = [
      ControllerBenchCommand.status,
      ControllerBenchCommand.heartbeat,
      ControllerBenchCommand.servoTest,
      ControllerBenchCommand.dispenseTest,
      ControllerBenchCommand.pirStatus,
      ControllerBenchCommand.ledTest,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bench commands',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Movement tests create controller history only. They never mark a dose taken or change inventory.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final command in commands)
                  OutlinedButton(
                    onPressed: () => runCommand(command),
                    child: Text(_commandLabel(command)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControllerHistoryCard extends StatelessWidget {
  const _ControllerHistoryCard({required this.history});

  final List<ControllerCommandHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Command history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('No command sessions yet.'),
              )
            else
              for (final entry in history)
                ExpansionTile(
                  title: Text(_commandTypeLabel(entry.session.commandType)),
                  subtitle: Text(_sessionStateLabel(entry.session)),
                  children: [
                    for (final event in entry.events)
                      ListTile(
                        dense: true,
                        title: Text(_eventLabel(event.eventType)),
                        subtitle: event.details == null
                            ? null
                            : Text(event.details!),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

String _commandLabel(ControllerBenchCommand command) => switch (command) {
  ControllerBenchCommand.status => 'STATUS',
  ControllerBenchCommand.heartbeat => 'HEARTBEAT',
  ControllerBenchCommand.servoTest => 'SERVO_TEST',
  ControllerBenchCommand.dispenseTest => 'DISPENSE_TEST',
  ControllerBenchCommand.pirStatus => 'PIR_STATUS',
  ControllerBenchCommand.ledTest => 'LED_TEST',
};

String _commandTypeLabel(ControllerCommandType command) => switch (command) {
  ControllerCommandType.dispenseNext => 'DISPENSE_NEXT',
  ControllerCommandType.dispenseTest => 'DISPENSE_TEST',
  ControllerCommandType.servoTest => 'SERVO_TEST',
  ControllerCommandType.heartbeat => 'HEARTBEAT',
  ControllerCommandType.status => 'STATUS',
  ControllerCommandType.pirStatus => 'PIR_STATUS',
  ControllerCommandType.ledTest => 'LED_TEST',
};

String _sessionStateLabel(ControllerCommandSession session) {
  final failure = session.failureReason;
  return failure == null
      ? session.state.name
      : '${session.state.name}: ${failure.name}';
}

String _eventLabel(ControllerCommandEventType event) => switch (event) {
  ControllerCommandEventType.commandSent => 'COMMAND SENT',
  ControllerCommandEventType.ack => 'ACK',
  ControllerCommandEventType.nack => 'NACK',
  ControllerCommandEventType.moveStarted => 'MOVEMENT STARTED',
  ControllerCommandEventType.servoDone => 'SERVO DONE',
  ControllerCommandEventType.controllerError => 'CONTROLLER ERROR',
  ControllerCommandEventType.heartbeatOk => 'HEARTBEAT OK',
  ControllerCommandEventType.heartbeatMissed => 'HEARTBEAT MISSED',
  ControllerCommandEventType.offline => 'OFFLINE',
  ControllerCommandEventType.reconnected => 'RECONNECTED',
};

class _ControllerCommandStatusCard extends StatelessWidget {
  const _ControllerCommandStatusCard({required this.session});

  final ControllerCommandSession? session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _ControllerCommandStatusViewData.fromSession(session);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controller command status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(status.icon, color: status.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: status.color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        status.headline,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.detail,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

class _ControllerCommandStatusViewData {
  const _ControllerCommandStatusViewData({
    required this.label,
    required this.headline,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String headline;
  final String detail;
  final IconData icon;
  final Color color;

  static _ControllerCommandStatusViewData fromSession(
    ControllerCommandSession? session,
  ) {
    if (session == null) {
      return const _ControllerCommandStatusViewData(
        label: 'No activity',
        headline: 'No controller command yet.',
        detail: 'Movement stays separate from dose taken confirmation.',
        icon: Icons.hourglass_empty,
        color: Colors.grey,
      );
    }

    switch (session.state) {
      case ControllerCommandSessionState.pending:
        return const _ControllerCommandStatusViewData(
          label: 'Waiting',
          headline: 'The last controller command was sent.',
          detail: 'Waiting for the controller to respond.',
          icon: Icons.schedule,
          color: Colors.orange,
        );
      case ControllerCommandSessionState.accepted:
        return const _ControllerCommandStatusViewData(
          label: 'In progress',
          headline: 'The controller accepted the last command.',
          detail: 'Waiting for movement to finish.',
          icon: Icons.motion_photos_on_outlined,
          color: Colors.orange,
        );
      case ControllerCommandSessionState.succeeded:
        return const _ControllerCommandStatusViewData(
          label: 'Completed',
          headline: 'The last controller command completed.',
          detail: 'Movement stays separate from dose taken confirmation.',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        );
      case ControllerCommandSessionState.failed:
        return switch (session.failureReason) {
          ControllerCommandFailureReason.nack =>
            const _ControllerCommandStatusViewData(
              label: 'Rejected',
              headline: 'The last controller command was rejected.',
              detail: 'No dose should be treated as taken from this result.',
              icon: Icons.block_outlined,
              color: Colors.red,
            ),
          ControllerCommandFailureReason.offline =>
            const _ControllerCommandStatusViewData(
              label: 'Offline',
              headline:
                  'The last controller command could not reach the controller.',
              detail: 'Reconnect before trying again.',
              icon: Icons.wifi_off_outlined,
              color: Colors.red,
            ),
          ControllerCommandFailureReason.jam =>
            const _ControllerCommandStatusViewData(
              label: 'Needs review',
              headline: 'The last controller command reported a jam.',
              detail: 'Check the dispenser before trying again.',
              icon: Icons.error_outline,
              color: Colors.red,
            ),
          ControllerCommandFailureReason.timeout =>
            const _ControllerCommandStatusViewData(
              label: 'Timed out',
              headline: 'The last controller command timed out.',
              detail: 'Check the command history before trying again.',
              icon: Icons.timer_off_outlined,
              color: Colors.red,
            ),
          ControllerCommandFailureReason.disconnect ||
          null => const _ControllerCommandStatusViewData(
            label: 'Failed',
            headline:
                'The last controller command failed before movement was confirmed.',
            detail: 'Check the dispenser before trying again.',
            icon: Icons.error_outline,
            color: Colors.red,
          ),
        };
      case ControllerCommandSessionState.timedOut:
        return const _ControllerCommandStatusViewData(
          label: 'Needs review',
          headline: 'The last controller command timed out after acceptance.',
          detail: 'Check the dispenser before trying again.',
          icon: Icons.error_outline,
          color: Colors.red,
        );
      case ControllerCommandSessionState.cancelled:
        return const _ControllerCommandStatusViewData(
          label: 'Cancelled',
          headline: 'The last controller command was cancelled.',
          detail: 'Movement stays separate from dose taken confirmation.',
          icon: Icons.cancel_outlined,
          color: Colors.grey,
        );
      case ControllerCommandSessionState.interrupted:
        return const _ControllerCommandStatusViewData(
          label: 'Needs review',
          headline:
              'The last controller command was interrupted after it may have started.',
          detail: 'Check the dispenser before trying again.',
          icon: Icons.error_outline,
          color: Colors.red,
        );
    }
  }
}
