import 'package:dosey_app/features/guided_trial/guided_trial.dart';
import 'package:flutter/material.dart';

class GuidedTrialScreen extends StatelessWidget {
  const GuidedTrialScreen({
    super.key,
    required this.controller,
    required this.exitTrial,
  });

  final GuidedTrialController controller;
  final Future<void> Function() exitTrial;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Guided Trial Run',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Step ${state.isComplete ? state.totalSteps : state.completedSteps + 1} of ${state.totalSteps}',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.completedSteps / state.totalSteps,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      state.isComplete
                          ? Icons.check_circle_outline
                          : Icons.fact_check_outlined,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.step.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(state.step.body),
                  ],
                ),
              ),
            ),
            if (state.failureReason != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs attention',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(state.failureReason!),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!state.isComplete)
              FilledButton.icon(
                onPressed: state.isRunning || state.isPaused
                    ? null
                    : state.failureReason == null
                    ? controller.next
                    : controller.retry,
                icon: state.isRunning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  state.failureReason != null
                      ? 'Retry step'
                      : state.step == GuidedTrialStep.historyAndInventory
                      ? 'Continue after review'
                      : 'Next step',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!state.isComplete)
                  OutlinedButton.icon(
                    onPressed: state.isRunning
                        ? null
                        : state.isPaused
                        ? controller.resume
                        : controller.pause,
                    icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(state.isPaused ? 'Resume' : 'Pause'),
                  ),
                OutlinedButton.icon(
                  onPressed: state.isRunning
                      ? null
                      : () => _confirmRestart(context),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restart'),
                ),
                OutlinedButton.icon(
                  onPressed: state.isRunning ? null : () => _exit(context),
                  icon: const Icon(Icons.exit_to_app),
                  label: Text(
                    state.isComplete ? 'Return to Dosey' : 'Exit trial',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRestart(BuildContext context) async {
    if (controller.state.completedSteps == 0) {
      await controller.restart();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart guided trial?'),
        content: const Text('This resets the fake trial data and progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.restart();
  }

  Future<void> _exit(BuildContext context) async {
    if (!controller.state.isComplete && controller.state.completedSteps > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit guided trial?'),
          content: const Text('Your current trial progress will be discarded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep practicing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit trial'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await exitTrial();
  }
}
