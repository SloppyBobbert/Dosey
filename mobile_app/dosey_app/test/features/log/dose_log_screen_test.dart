import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('filters events into the expected categories', (tester) async {
    await _setDoseLogViewport(tester);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedEvents(database, [
      _event('taken', DoseLogEventKind.error, marksDoseTaken: true),
      _event('missed', DoseLogEventKind.doseMissed),
      _event('recognized', DoseLogEventKind.doseMissedRecognized),
      _event('skipped', DoseLogEventKind.doseSkipped),
      _event('help', DoseLogEventKind.caregiverHelpRequested),
      _event('error', DoseLogEventKind.error),
      _event('movement', DoseLogEventKind.controllerDispenseSucceeded),
      _event('visible', DoseLogEventKind.doseVisibleConfirmed),
      _event('snoozed', DoseLogEventKind.doseSnoozed),
    ]);

    await tester.pumpWidget(_doseLogApp(database));
    await tester.pumpAndSettle();

    expect(find.text('taken'), findsOneWidget);
    expect(find.text('movement'), findsOneWidget);

    await tester.tap(find.text('Confirmed taken'));
    await tester.pumpAndSettle();
    expect(find.text('taken'), findsOneWidget);
    expect(find.text('missed'), findsNothing);

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();
    expect(find.text('missed'), findsOneWidget);
    expect(find.text('recognized'), findsOneWidget);
    expect(find.text('skipped'), findsOneWidget);
    expect(find.text('help'), findsOneWidget);
    expect(find.text('error'), findsOneWidget);
    expect(find.text('taken'), findsNothing);
    expect(find.text('movement'), findsNothing);

    await tester.tap(find.text('Other activity'));
    await tester.pumpAndSettle();
    expect(find.text('movement'), findsOneWidget);
    expect(find.text('visible'), findsOneWidget);
    expect(find.text('snoozed'), findsOneWidget);
    expect(find.text('missed'), findsNothing);
  });

  testWidgets('hero counts continue to use all events after filtering', (
    tester,
  ) async {
    await _setDoseLogViewport(tester);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedEvents(database, [
      _event(
        'taken',
        DoseLogEventKind.doseTakenConfirmed,
        marksDoseTaken: true,
      ),
      _event('missed', DoseLogEventKind.doseMissed),
      _event('movement', DoseLogEventKind.controllerDispenseSucceeded),
    ]);

    await tester.pumpWidget(_doseLogApp(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed taken'));
    await tester.pumpAndSettle();

    expect(find.text('3 local events'), findsOneWidget);
    expect(find.text('1 confirmed taken'), findsOneWidget);
    expect(find.text('2 movement or review'), findsOneWidget);
    expect(find.text('missed'), findsNothing);
  });

  testWidgets('renders local event timestamps in 12-hour format', (
    tester,
  ) async {
    await _expectLocalEventSubtitle(tester, alwaysUse24HourFormat: false);
  });

  testWidgets('renders local event timestamps in 24-hour format', (
    tester,
  ) async {
    await _expectLocalEventSubtitle(tester, alwaysUse24HourFormat: true);
  });

  testWidgets('shows filtered empty state and local event details', (
    tester,
  ) async {
    await _setDoseLogViewport(tester);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedEvents(database, [
      _event(
        'morning:2026-07-24',
        DoseLogEventKind.controllerDispenseSucceeded,
      ),
    ]);

    await tester.pumpWidget(_doseLogApp(database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();

    expect(find.text('No needs attention events yet.'), findsOneWidget);
    expect(
      find.text('Try another filter to view the rest of your local log.'),
      findsOneWidget,
    );
    expect(find.text('No local dose log events yet.'), findsNothing);
  });
}

Future<void> _expectLocalEventSubtitle(
  WidgetTester tester, {
  required bool alwaysUse24HourFormat,
}) async {
  await _setDoseLogViewport(tester);
  final database = DoseyDatabase.inMemory();
  addTearDown(database.close);
  final occurredAt = DateTime.utc(2026, 7, 24, 12, 34);
  const doseId = 'morning:2026-07-24';
  await _seedEvents(database, [
    DoseLogEvent(
      kind: DoseLogEventKind.controllerDispenseSucceeded,
      doseId: doseId,
      occurredAt: occurredAt,
      marksDoseTaken: false,
    ),
  ]);

  await tester.pumpWidget(
    _doseLogApp(database, alwaysUse24HourFormat: alwaysUse24HourFormat),
  );
  await tester.pumpAndSettle();

  final doseIdFinder = find.text(doseId);
  expect(doseIdFinder, findsOneWidget);
  final context = tester.element(doseIdFinder);
  final local = occurredAt.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final expectedTimestamp =
      '${localizations.formatFullDate(local)} at '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: alwaysUse24HourFormat)}';

  expect(find.text(expectedTimestamp), findsOneWidget);
}

Future<void> _setDoseLogViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

DoseLogEvent _event(
  String doseId,
  DoseLogEventKind kind, {
  bool marksDoseTaken = false,
}) {
  return DoseLogEvent(
    kind: kind,
    doseId: doseId,
    occurredAt: DateTime(2026, 7, 24, 12, 34),
    marksDoseTaken: marksDoseTaken,
  );
}

Future<void> _seedEvents(
  DoseyDatabase database,
  List<DoseLogEvent> events,
) async {
  final log = DriftDoseLogRepository(database);
  for (var index = 0; index < events.length; index++) {
    final event = events[index];
    await log.addEvent(
      DoseLogEvent(
        kind: event.kind,
        doseId: event.doseId,
        occurredAt: event.occurredAt.add(Duration(seconds: index)),
        marksDoseTaken: event.marksDoseTaken,
      ),
    );
  }
}

Widget _doseLogApp(
  DoseyDatabase database, {
  bool alwaysUse24HourFormat = false,
}) {
  return DoseyAppScope(
    database: database,
    bleGateway: FakeBleGateway(),
    connectivityGateway: FakeConnectivityGateway(),
    missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: child!,
      ),
      home: const DoseLogScreen(),
    ),
  );
}
