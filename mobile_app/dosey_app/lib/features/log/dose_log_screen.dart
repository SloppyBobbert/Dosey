import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:flutter/material.dart';

class DoseLogScreen extends StatelessWidget {
  const DoseLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doseLog = DoseyAppScope.of(context).doseLog;

    return StreamBuilder<List<DoseLogEvent>>(
      stream: doseLog.watchEvents(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <DoseLogEvent>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Dose log', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No local dose log events yet.'),
                ),
              )
            else
              for (final event in events)
                ListTile(
                  title: Text(_labelFor(event.kind)),
                  subtitle: Text(event.doseId),
                  trailing: Icon(
                    event.marksDoseTaken
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                  ),
                ),
          ],
        );
      },
    );
  }

  static String _labelFor(DoseLogEventKind kind) {
    return switch (kind) {
      DoseLogEventKind.controllerDispenseSucceeded =>
        'Controller dispense succeeded',
      DoseLogEventKind.doseTakenConfirmed => 'Dose taken confirmed',
      DoseLogEventKind.error => 'Error',
    };
  }
}
