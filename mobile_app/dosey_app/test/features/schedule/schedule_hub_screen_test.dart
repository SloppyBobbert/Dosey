import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/schedule/schedule_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('defaults to Schedule and preserves a selected segment', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Prescriptions'), findsWidgets);
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.byType(PrescriptionsScreen), findsNothing);

    await tester.tap(find.text('Prescriptions').last);
    await tester.pumpAndSettle();
    expect(find.byType(PrescriptionsScreen), findsOneWidget);

    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();
    expect(find.byType(PrescriptionsScreen), findsOneWidget);
  });

  testWidgets('can open Prescriptions directly', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      _TestApp(
        database: database,
        initialSegment: ScheduleHubSegment.prescriptions,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrescriptionsScreen), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.database, this.initialSegment});

  final DoseyDatabase database;
  final ScheduleHubSegment? initialSegment;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        home: Scaffold(
          body: ScheduleHubScreen(
            initialSegment: initialSegment ?? ScheduleHubSegment.schedule,
          ),
        ),
      ),
    );
  }
}
