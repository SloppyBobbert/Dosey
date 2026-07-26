import 'package:dosey_app/core/controller/controller_diagnostics.dart';
import 'package:flutter/material.dart';

class ControllerDiagnosticsCard extends StatefulWidget {
  const ControllerDiagnosticsCard({required this.runDiagnostics, super.key});

  final Future<ControllerDiagnosticReport> Function() runDiagnostics;

  @override
  State<ControllerDiagnosticsCard> createState() =>
      _ControllerDiagnosticsCardState();
}

class _ControllerDiagnosticsCardState extends State<ControllerDiagnosticsCard> {
  ControllerDiagnosticReport? _report;
  Object? _error;
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final report = await widget.runDiagnostics();
      if (!mounted) return;
      setState(() => _report = report);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hardware diagnostics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Read-only snapshot. Raw signal levels are not interpreted until the hardware is calibrated.',
            ),
            if (_error case final error) ...[
              const SizedBox(height: 10),
              Text(
                'Diagnostics failed: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (report != null) ...[
              const SizedBox(height: 16),
              for (final section in report.sections)
                _DiagnosticSection(section: section),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'No report yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('controller-diagnostics-run'),
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _running
                    ? 'Reading controller...'
                    : report == null
                    ? 'Run diagnostics'
                    : 'Refresh diagnostics',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticSection extends StatelessWidget {
  const _DiagnosticSection({required this.section});

  final ControllerDiagnosticReportSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionLabel(section.section),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          for (final reading in section.readings)
            _DiagnosticRow(reading: reading),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.reading});

  final ControllerDiagnosticReading reading;

  @override
  Widget build(BuildContext context) {
    final color = switch (reading.status) {
      ControllerDiagnosticStatus.ok => Colors.green.shade700,
      ControllerDiagnosticStatus.informational => Theme.of(
        context,
      ).colorScheme.primary,
      ControllerDiagnosticStatus.attention => Colors.orange.shade800,
      ControllerDiagnosticStatus.unavailable => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    final icon = switch (reading.status) {
      ControllerDiagnosticStatus.ok => Icons.check_circle_outline,
      ControllerDiagnosticStatus.informational => Icons.info_outline,
      ControllerDiagnosticStatus.attention => Icons.warning_amber_rounded,
      ControllerDiagnosticStatus.unavailable => Icons.remove_circle_outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(reading.label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              reading.value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _sectionLabel(ControllerDiagnosticSection section) => switch (section) {
  ControllerDiagnosticSection.system => 'System',
  ControllerDiagnosticSection.safety => 'Safety limits',
  ControllerDiagnosticSection.sensors => 'Sensors',
  ControllerDiagnosticSection.inputs => 'Inputs',
  ControllerDiagnosticSection.movement => 'Movement',
  ControllerDiagnosticSection.actuators => 'Actuators',
  ControllerDiagnosticSection.capabilities => 'Capabilities',
  ControllerDiagnosticSection.reliability => 'Reliability',
  ControllerDiagnosticSection.uncatalogued => 'Uncatalogued',
};
