import 'package:flutter/material.dart';

class DoseyHomeScreen extends StatelessWidget {
  const DoseyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dosey')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SafetyCard(),
          SizedBox(height: 12),
          _StatusCard(),
          SizedBox(height: 12),
          _ManualDispenseCard(),
          SizedBox(height: 12),
          _BuildStepsCard(),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return _DoseyCard(
      icon: Icons.health_and_safety_outlined,
      title: 'Prototype safety',
      children: const [
        Text('Use candy, beads, dry beans, vitamins, or fake pills.'),
        SizedBox(height: 8),
        Text('Never mark a dose taken because the servo moved.'),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return const _DoseyCard(
      icon: Icons.bluetooth_disabled_outlined,
      title: 'Controller disconnected',
      children: [
        Text('Connect the XIAO ESP32-C6 after the BLE protocol demo exists.'),
      ],
    );
  }
}

class _ManualDispenseCard extends StatelessWidget {
  const _ManualDispenseCard();

  @override
  Widget build(BuildContext context) {
    return _DoseyCard(
      icon: Icons.motion_photos_pause_outlined,
      title: 'Manual dispense test',
      children: [
        const Text('Locked until a controller is connected'),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: null,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Dispense disabled'),
        ),
      ],
    );
  }
}

class _BuildStepsCard extends StatelessWidget {
  const _BuildStepsCard();

  @override
  Widget build(BuildContext context) {
    return const _DoseyCard(
      icon: Icons.checklist_outlined,
      title: 'Next build steps',
      children: [
        Text('1. Grove electronics bring-up'),
        Text('2. BLE command/status demo'),
        Text('3. Carousel one-slot test'),
      ],
    );
  }
}

class _DoseyCard extends StatelessWidget {
  const _DoseyCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
