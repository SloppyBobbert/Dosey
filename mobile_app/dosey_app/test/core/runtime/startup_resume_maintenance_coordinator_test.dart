import 'dart:async';

import 'package:dosey_app/core/runtime/startup_resume_maintenance_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs stages in order', () async {
    final events = <String>[];
    final coordinator = _coordinator(events);
    await coordinator.request();
    expect(events, ['identity', 'timezone', 'notifications', 'reconciliation']);
  });

  test('identity failure reports and stops downstream work', () async {
    final events = <String>[];
    final failures = <StartupMaintenanceFailure>[];
    final coordinator = _coordinator(
      events,
      identity: () async => throw StateError('bad'),
      report: failures.add,
    );
    await coordinator.request();
    expect(events, isEmpty);
    expect(failures.single.stage, StartupMaintenanceStage.identity);
  });

  test('notification failure reports and reconciliation continues', () async {
    final events = <String>[];
    final failures = <StartupMaintenanceFailure>[];
    final coordinator = _coordinator(
      events,
      notifications: () async => throw StateError('bad'),
      report: failures.add,
    );
    await coordinator.request();
    expect(events, ['identity', 'timezone', 'reconciliation']);
    expect(failures.single.stage, StartupMaintenanceStage.notifications);
  });

  test('timezone failure reports and stops downstream work', () async {
    final events = <String>[];
    final failures = <StartupMaintenanceFailure>[];
    final coordinator = StartupResumeMaintenanceCoordinator(
      initializeIdentity: () async => events.add('identity'),
      refreshTimezone: () async => throw StateError('timezone'),
      syncNotifications: () async => events.add('notifications'),
      reconcile: () async => events.add('reconciliation'),
      reportFailure: failures.add,
    );
    await coordinator.request();
    expect(events, ['identity']);
    expect(failures.single.stage, StartupMaintenanceStage.timezone);
  });

  test('reconciliation failure reports and request completes', () async {
    final failures = <StartupMaintenanceFailure>[];
    final coordinator = _coordinator(
      <String>[],
      reconcile: () async => throw StateError('reconcile'),
      report: failures.add,
    );
    await coordinator.request();
    expect(failures.single.stage, StartupMaintenanceStage.reconciliation);
  });

  test(
    'reporter failure is swallowed and later requests remain usable',
    () async {
      var runs = 0;
      final coordinator = _coordinator(
        <String>[],
        identity: () async {
          runs += 1;
          throw StateError('identity');
        },
        report: (_) => throw StateError('reporter'),
      );
      await coordinator.request();
      await coordinator.request();
      expect(runs, 2);
    },
  );

  test('coalesces active overlaps into one trailing run', () async {
    final gate = Completer<void>();
    var calls = 0;
    final coordinator = StartupResumeMaintenanceCoordinator(
      initializeIdentity: () async {
        calls += 1;
        if (calls == 1) await gate.future;
      },
      refreshTimezone: () async {},
      syncNotifications: () async {},
      reconcile: () async {},
    );
    final first = coordinator.request();
    final second = coordinator.request();
    final third = coordinator.request();
    gate.complete();
    await Future.wait<void>([first, second, third]);
    expect(calls, 2);
  });

  test('first caller completes before blocked trailing callers', () async {
    final firstGate = Completer<void>();
    final trailingGate = Completer<void>();
    var calls = 0;
    final coordinator = _coordinator(
      <String>[],
      identity: () async {
        calls += 1;
        if (calls == 1) await firstGate.future;
        if (calls == 2) await trailingGate.future;
      },
    );
    final first = coordinator.request();
    final trailing = coordinator.request();
    var trailingDone = false;
    trailing.whenComplete(() => trailingDone = true);
    firstGate.complete();
    await first;
    expect(trailingDone, isFalse);
    trailingGate.complete();
    await trailing;
  });

  test(
    'request during trailing queues one later run without concurrency',
    () async {
      final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
      var calls = 0;
      var active = 0;
      var maximum = 0;
      final coordinator = _coordinator(
        <String>[],
        identity: () async {
          active += 1;
          maximum = maximum > active ? maximum : active;
          final call = calls++;
          await gates[call].future;
          active -= 1;
        },
      );
      final first = coordinator.request();
      final second = coordinator.request();
      gates[0].complete();
      await first;
      final third = coordinator.request();
      gates[1].complete();
      await second;
      gates[2].complete();
      await third;
      expect(calls, 3);
      expect(maximum, 1);
    },
  );

  test('dispose cancels queued work and waits for active work', () async {
    final gate = Completer<void>();
    var calls = 0;
    final coordinator = _coordinator(
      <String>[],
      identity: () async {
        calls += 1;
        await gate.future;
      },
    );
    final active = coordinator.request();
    final queued = coordinator.request();
    final disposal = coordinator.dispose();
    await expectLater(coordinator.request(), completes);
    expect(disposal, same(coordinator.dispose()));
    expect(queued, completes);
    gate.complete();
    await Future.wait([active, queued, disposal]);
    expect(calls, 1);
  });
}

StartupResumeMaintenanceCoordinator _coordinator(
  List<String> events, {
  Future<void> Function()? identity,
  Future<void> Function()? notifications,
  Future<void> Function()? reconcile,
  void Function(StartupMaintenanceFailure)? report,
}) => StartupResumeMaintenanceCoordinator(
  initializeIdentity: identity ?? () async => events.add('identity'),
  refreshTimezone: () async => events.add('timezone'),
  syncNotifications: notifications ?? () async => events.add('notifications'),
  reconcile: reconcile ?? () async => events.add('reconciliation'),
  reportFailure: report,
);
