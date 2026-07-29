import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/carousel/carousel_hub_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';
import '../../support/simulator_scenario_harness.dart';

void main() {
  testWidgets(
    'scope-owned SystemAppClock cancels its periodic timer on unmount',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(database.close);
      });

      await tester.pumpWidget(
        DoseyAppScope(
          database: database,
          bleGateway: FakeBleGateway(),
          connectivityGateway: FakeConnectivityGateway(),
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
    },
  );

  test(
    'composes a happy dispense through visible and taken confirmation',
    () async {
      final harness = await StandaloneSimulatorScenarioHarness.create();
      addTearDown(harness.close);

      await harness.select(DemoScenarioId.happyPath);
      await harness.next(count: 7);
      final beforeTaken = await harness.doseEvents();
      expect(beforeTaken.map((event) => event.kind), [
        DoseLogEventKind.controllerDispenseSucceeded,
        DoseLogEventKind.doseVisibleConfirmed,
      ]);
      expect(beforeTaken.where((event) => event.marksDoseTaken), isEmpty);
      expect(await harness.inventory(), (
        available: 13,
        loaded: 1,
        used: 0,
        review: 0,
      ));

      await harness.next();
      final afterTaken = await harness.doseEvents();
      expect(afterTaken.map((event) => event.kind), [
        DoseLogEventKind.controllerDispenseSucceeded,
        DoseLogEventKind.doseVisibleConfirmed,
        DoseLogEventKind.doseTakenConfirmed,
      ]);
      expect(afterTaken.where((event) => event.marksDoseTaken), hasLength(1));
      expect(await harness.inventory(), (
        available: 13,
        loaded: 0,
        used: 1,
        review: 0,
      ));
      expect(
        await harness.commandEventCount(ControllerCommandEventType.commandSent),
        1,
      );
    },
  );

  testWidgets('DoseyAppScope shutdown completes after shell unmount', (
    tester,
  ) async {
    final harness = await ShellSimulatorScenarioHarness.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);
      await tester.runAsync(harness.close);
    });

    await tester.pumpWidget(harness.buildShell(startOnController: true));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    await tester.runAsync(
      () => harness.close().timeout(const Duration(seconds: 2)),
    );
  });

  testWidgets(
    'accepted jam remains unchanged across real Robot Mode pause and resume',
    (tester) async {
      final harness = await ShellSimulatorScenarioHarness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
        await tester.runAsync(harness.close);
      });
      await tester.pumpWidget(harness.buildShell(startOnController: true));
      await _settle(tester);

      final shellContext = tester.element(find.byType(DoseyShell));
      final scenarios = harness.demoScenarios(shellContext);
      await scenarios.select(DemoScenarioId.jam);
      await scenarios.next();
      await _settle(tester);

      final beforePause = await harness.snapshot();
      final session = (await harness.commandSessions()).single;
      expect(session.state, 'failed');
      expect(session.failureReason, 'jam');
      expect(session.acceptedAt, isNotNull);
      expect((await harness.commandEvents()).map((event) => event.eventType), [
        'commandSent',
        'ack',
        'moveStarted',
        'controllerError',
      ]);
      expect(await harness.inventory(), (
        available: 13,
        loaded: 0,
        used: 0,
        review: 1,
      ));
      expect(await harness.slotStatus(), 'needs_review');

      expect(find.byType(ControllerScreen), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RobotFaceScreen && widget.isActive,
          skipOffstage: false,
        ),
        findsNothing,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(find.byType(ControllerScreen), findsOneWidget);
      expect(await harness.slotStatus(), 'needs_review');
      final afterResume = await harness.snapshot();
      expect(afterResume.sameAs(beforePause), isTrue);
      expect(await harness.commandSessions(), hasLength(1));
    },
  );

  testWidgets(
    'missed notification routes the real shell to Robot Face and acknowledgement is seen-only',
    (tester) async {
      final harness = await ShellSimulatorScenarioHarness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
        await tester.runAsync(harness.close);
      });
      await tester.pumpWidget(harness.buildShell(startOnController: true));
      await _settle(tester);

      expect(find.byType(ControllerScreen), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RobotFaceScreen && widget.isActive,
          skipOffstage: false,
        ),
        findsNothing,
      );

      harness.clock.set(DateTime.utc(2040, 1, 2, 10, 31));
      await tester.runAsync(() => harness.reconciliation.reconcile());
      await _settle(tester);
      expect((await harness.doseEvents()).map((event) => event.kind), [
        DoseLogEventKind.doseMissed,
      ]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      harness.notificationTaps.handleTap(harness.doseId);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RobotFaceScreen && widget.isActive,
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.byType(CarouselHubScreen), findsNothing);
      expect((await harness.doseEvents()).map((event) => event.kind), [
        DoseLogEventKind.doseMissed,
      ]);

      final beforeRecognition = await harness.snapshot();
      await tester.tap(
        find.byKey(RobotFaceScreen.recognizeMissedDoseButtonKey),
      );
      await _settle(tester);
      final events = await harness.doseEvents();
      expect(events.map((event) => event.kind), [
        DoseLogEventKind.doseMissed,
        DoseLogEventKind.doseMissedRecognized,
      ]);
      expect(events.where((event) => event.marksDoseTaken), isEmpty);
      final afterRecognition = await harness.snapshot();
      expect(afterRecognition.inventory, beforeRecognition.inventory);
      expect(afterRecognition.sessions, beforeRecognition.sessions);
      expect(afterRecognition.commandEvents, beforeRecognition.commandEvents);
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
