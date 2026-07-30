import 'package:dosey_app/core/settings/personal_setup_step.dart';
import 'package:flutter/material.dart';

class PersonalSetupGate extends StatefulWidget {
  const PersonalSetupGate({
    super.key,
    required this.steps,
    required this.saveStep,
    required this.today,
    required this.medications,
    required this.pairing,
  });

  final Stream<PersonalSetupStep> steps;
  final Future<void> Function(PersonalSetupStep step) saveStep;
  final Widget today;
  final Widget Function(Future<void> Function() completeSetup) medications;
  final Widget Function(Future<void> Function() completeSetup) pairing;

  @override
  State<PersonalSetupGate> createState() => _PersonalSetupGateState();
}

class _PersonalSetupGateState extends State<PersonalSetupGate> {
  Widget? _launchedFlow;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final launchedFlow = _launchedFlow;
    if (launchedFlow != null) return launchedFlow;

    return StreamBuilder<PersonalSetupStep>(
      stream: widget.steps,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _PersonalSetupError();
        }
        final step = snapshot.data;
        if (step == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return switch (step) {
          PersonalSetupStep.chooseNextAction => _choicePage(),
          PersonalSetupStep.orientThenAddMedication => _orientationPage(
            actionLabel: 'Continue to medications',
            destination: widget.medications,
          ),
          PersonalSetupStep.orientThenPairRobot => _orientationPage(
            actionLabel: 'Continue to pairing',
            destination: widget.pairing,
          ),
          PersonalSetupStep.complete => widget.today,
        };
      },
    );
  }

  Widget _choicePage() {
    return _PersonalSetupFrame(
      title: 'What would you like to do first?',
      subtitle:
          'Use Dosey’s existing medication or Robot pairing flow. You can return to either later.',
      error: _error,
      children: [
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () => _save(PersonalSetupStep.orientThenAddMedication),
          icon: const Icon(Icons.medication_outlined),
          label: const Text('Add medication'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving
              ? null
              : () => _save(PersonalSetupStep.orientThenPairRobot),
          icon: const Icon(Icons.link_outlined),
          label: const Text('Pair Robot'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _orientationPage({
    required String actionLabel,
    required Widget Function(Future<void> Function() completeSetup) destination,
  }) {
    return _PersonalSetupFrame(
      title: 'A quick map of Dosey',
      subtitle:
          'Today shows what is due. Schedules control reminder times. History records explicit actions such as Taken, Snoozed, Skipped, and Help.',
      error: _error,
      children: [
        FilledButton(
          onPressed: _saving ? null : () => _launch(destination),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(actionLabel),
        ),
      ],
    );
  }

  Future<void> _save(PersonalSetupStep step) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.saveStep(step);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Setup could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _launch(
    Widget Function(Future<void> Function() completeSetup) destination,
  ) {
    setState(() {
      _error = null;
      _launchedFlow = destination(_complete);
    });
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.saveStep(PersonalSetupStep.complete);
      if (mounted) setState(() => _launchedFlow = widget.today);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Setup could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PersonalSetupFrame extends StatelessWidget {
  const _PersonalSetupFrame({
    required this.title,
    required this.subtitle,
    required this.error,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.route_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center),
            if (error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PersonalSetupError extends StatelessWidget {
  const _PersonalSetupError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Personal setup could not load.')),
    );
  }
}
