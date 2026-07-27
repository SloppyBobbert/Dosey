import 'dart:async';

import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/features/shell/external_action_resume_guard.dart';
import 'package:flutter/material.dart';

class RobotPhoneSetupScreen extends StatefulWidget {
  const RobotPhoneSetupScreen({
    super.key,
    required this.gateway,
    required this.externalActionResumeGuard,
  });

  final RobotPhoneSetupGateway gateway;
  final ExternalActionResumeGuard<String> externalActionResumeGuard;

  @override
  State<RobotPhoneSetupScreen> createState() => _RobotPhoneSetupScreenState();
}

class _RobotPhoneSetupScreenState extends State<RobotPhoneSetupScreen>
    with WidgetsBindingObserver {
  Map<RobotPhoneSetupItem, SetupReadiness>? _status;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.gateway.readStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _open(RobotPhoneSetupAction action) async {
    final lease = widget.externalActionResumeGuard.begin('settings');
    try {
      final result = await widget.gateway.open(action);
      if (!mounted || result == SetupActionResult.opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This Android settings page is unavailable.'),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Android settings.')),
      );
    } finally {
      lease.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Robot phone setup')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Status is checked from Android when this screen opens and when you return. Dosey does not change these settings for you.',
            ),
            const SizedBox(height: 16),
            if (_status == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && _status == null)
              _SetupErrorCard(onRetry: _refresh)
            else
              for (final item in RobotPhoneSetupItem.values) ...[
                _SetupItemCard(
                  item: item,
                  readiness: _status?[item] ?? SetupReadiness.unsupported,
                  onOpen: _open,
                ),
                const SizedBox(height: 12),
              ],
            const Text(
              'A secure screen lock is recommended for a mounted phone. Dosey does not use device-owner, lock-task, or privileged kiosk controls.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupItemCard extends StatelessWidget {
  const _SetupItemCard({
    required this.item,
    required this.readiness,
    required this.onOpen,
  });

  final RobotPhoneSetupItem item;
  final SetupReadiness readiness;
  final Future<void> Function(RobotPhoneSetupAction action) onOpen;

  @override
  Widget build(BuildContext context) {
    final details = switch (item) {
      RobotPhoneSetupItem.bluetooth => const _SetupItemDetails(
        'Bluetooth',
        'Open Bluetooth',
        RobotPhoneSetupAction.bluetoothSettings,
      ),
      RobotPhoneSetupItem.wifi => const _SetupItemDetails(
        'Wi-Fi',
        'Open Wi-Fi',
        RobotPhoneSetupAction.wifiSettings,
      ),
      RobotPhoneSetupItem.notifications => const _SetupItemDetails(
        'Notifications',
        'Open notifications',
        RobotPhoneSetupAction.notificationSettings,
      ),
      RobotPhoneSetupItem.batteryOptimization => const _SetupItemDetails(
        'Battery optimization',
        'Open battery settings',
        RobotPhoneSetupAction.batteryOptimizationSettings,
      ),
      RobotPhoneSetupItem.secureLock => const _SetupItemDetails(
        'Secure lock',
        'Open security',
        RobotPhoneSetupAction.securitySettings,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_statusLabel(details.title, readiness)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onOpen(details.action),
                  child: Text(details.buttonLabel),
                ),
                if (item == RobotPhoneSetupItem.bluetooth &&
                    readiness == SetupReadiness.permissionRequired)
                  TextButton(
                    onPressed: () => onOpen(RobotPhoneSetupAction.appDetails),
                    child: const Text('Open app permissions'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String title, SetupReadiness readiness) {
    return switch (readiness) {
      SetupReadiness.ready => '$title ready',
      SetupReadiness.actionRequired => '$title need attention',
      SetupReadiness.permissionRequired => '$title permission required',
      SetupReadiness.unsupported => '$title status unavailable',
    };
  }
}

class _SetupErrorCard extends StatelessWidget {
  const _SetupErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Robot phone status could not be checked.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _SetupItemDetails {
  const _SetupItemDetails(this.title, this.buttonLabel, this.action);

  final String title;
  final String buttonLabel;
  final RobotPhoneSetupAction action;
}
