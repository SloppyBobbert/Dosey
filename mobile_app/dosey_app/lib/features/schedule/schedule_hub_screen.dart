import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';

enum ScheduleHubSegment { schedule, prescriptions }

class ScheduleHubScreen extends StatefulWidget {
  const ScheduleHubScreen({
    super.key,
    this.initialSegment = ScheduleHubSegment.schedule,
  });

  final ScheduleHubSegment initialSegment;

  @override
  State<ScheduleHubScreen> createState() => _ScheduleHubScreenState();
}

class _ScheduleHubScreenState extends State<ScheduleHubScreen> {
  late ScheduleHubSegment _segment = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<ScheduleHubSegment>(
            segments: const [
              ButtonSegment(
                value: ScheduleHubSegment.schedule,
                icon: Icon(Icons.alarm_outlined),
                label: Text('Schedule'),
              ),
              ButtonSegment(
                value: ScheduleHubSegment.prescriptions,
                icon: Icon(Icons.medication_outlined),
                label: Text('Prescriptions'),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (selection) {
              setState(() => _segment = selection.single);
            },
          ),
        ),
        Expanded(
          child: switch (_segment) {
            ScheduleHubSegment.schedule => const RemindersScreen(),
            ScheduleHubSegment.prescriptions => const PrescriptionsScreen(),
          },
        ),
      ],
    );
  }
}
