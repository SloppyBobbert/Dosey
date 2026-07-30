import 'dart:async';

import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter/material.dart';

import 'caregiver_shell.dart';
import 'dosey_web_dependencies.dart';
import 'web_routes.dart';

class WebHouseholdGate extends StatefulWidget {
  const WebHouseholdGate({
    super.key,
    required this.dependencies,
    required this.route,
  });

  final DoseyWebDependencies dependencies;
  final String route;

  @override
  State<WebHouseholdGate> createState() => _WebHouseholdGateState();
}

class _WebHouseholdGateState extends State<WebHouseholdGate> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => StreamBuilder<RobotInstallation?>(
    key: ValueKey(_attempt),
    stream: widget.dependencies.household.watchRobot(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _HouseholdMessage(
          message: 'Household status is offline.',
          actionLabel: 'Try again',
          onAction: () => setState(() => _attempt += 1),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final installation = snapshot.data;
      if (installation == null) {
        return _HouseholdEnrollment(dependencies: widget.dependencies);
      }
      if (widget.route == WebRoutes.household) {
        return _HouseholdSummary(
          installation: installation,
          onContinue: () =>
              Navigator.pushReplacementNamed(context, WebRoutes.today),
        );
      }
      return CaregiverShell(
        key: ValueKey('${installation.id}:${widget.route}'),
        dependencies: widget.dependencies,
        installation: installation,
        route: widget.route,
      );
    },
  );
}

class _HouseholdEnrollment extends StatefulWidget {
  const _HouseholdEnrollment({required this.dependencies});
  final DoseyWebDependencies dependencies;

  @override
  State<_HouseholdEnrollment> createState() => _HouseholdEnrollmentState();
}

class _HouseholdEnrollmentState extends State<_HouseholdEnrollment> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.dependencies.household.refreshRobot();
    } on HouseholdManagementException catch (error) {
      if (mounted) setState(() => _error = _message(error.reason));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Household setup is unavailable. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(28),
            shrinkWrap: true,
            children: [
              Text(
                'Set up your household',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a household for a new Dosey, or join one using an invitation code.',
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Household name'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _submit(() async {
                        await widget.dependencies.householdManagement
                            .createRobot(_name.text);
                      }),
                child: const Text('Create a household'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Invitation code'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _submit(() async {
                        await widget.dependencies.householdManagement
                            .acceptInvitation(_code.text);
                      }),
                child: const Text('Join with a code'),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  String _message(HouseholdManagementFailureReason reason) => switch (reason) {
    HouseholdManagementFailureReason.householdFull =>
      'That household already has the maximum number of people.',
    HouseholdManagementFailureReason.invalidInvitation ||
    HouseholdManagementFailureReason.invitationExpired =>
      'That invitation code is invalid or expired.',
    HouseholdManagementFailureReason.emailMismatch =>
      'Sign in with the email address that received this invitation.',
    _ => 'Household setup is unavailable. Try again.',
  };
}

class _HouseholdSummary extends StatelessWidget {
  const _HouseholdSummary({
    required this.installation,
    required this.onContinue,
  });
  final RobotInstallation installation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                installation.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text('${installation.humanAccountCount} household member(s)'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onContinue,
                child: const Text('Open today’s care'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HouseholdMessage extends StatelessWidget {
  const _HouseholdMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
