import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const readyState = RobotFaceState(
    mode: RobotFaceMode.doseReady,
    nextEventLabel: 'Now · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    actionDoseId: 'dose-1',
    availableActions: {RobotFaceActionKind.confirmTaken},
  );
  const helpState = RobotFaceState(
    mode: RobotFaceMode.waitingForConfirmation,
    nextEventLabel: 'Taken? · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    actionDoseId: 'dose-1',
    availableActions: {RobotFaceActionKind.askForHelp},
  );
  for (final helpFinishesFirst in <bool>[false, true]) {
    testWidgets(
      'Help during terminal authorization, help finishes first=$helpFinishesFirst',
      (tester) async {
        final states = StreamController<RobotFaceState>.broadcast();
        addTearDown(states.close);
        final authorizer = _DelayedActionAuthorizer();
        final help = _DelayedDoseActionLogger();
        final taken = _DelayedVisibleAndTakenLogger();
        await tester.pumpWidget(
          _ActionHostTestApp(
            stateStream: states.stream,
            actionAuthorizer: authorizer.call,
            doseActionLogger: help.call,
            visibleAndTakenLogger: taken.call,
          ),
        );
        states.add(
          readyState.copyWith(
            availableActions: const {
              RobotFaceActionKind.confirmTaken,
              RobotFaceActionKind.askForHelp,
            },
          ),
        );
        await tester.pump();
        final terminalCallback = tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed!;
        terminalCallback();
        await tester.pump();
        tester
            .widget<FilledButton>(find.byKey(RobotFaceScreen.needHelpButtonKey))
            .onPressed!();
        await tester.pump();
        expect(help.calls, 1);
        expect(
          taken.calls,
          0,
        ); // Help and movement are never Taken confirmation.
        authorizer.complete();
        await tester.pump();
        expect(taken.calls, 1);
        terminalCallback();
        expect(authorizer.calls, 1);
        if (helpFinishesFirst) {
          help.complete();
        } else {
          taken.complete();
        }
        await tester.pump();
        terminalCallback();
        if (helpFinishesFirst) {
          taken.complete();
        } else {
          help.complete();
        }
        await tester.pump();
        expect(help.calls, 1);
        expect(taken.calls, 1);
        expect(authorizer.calls, 1);
      },
    );
  }

  for (final terminal in <RobotFaceActionKind>[
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    for (final throws in <bool>[false, true]) {
      for (final helpFinishesFirst in <bool>[false, true]) {
        testWidgets('submission ownership ${terminal.name}, throws=$throws, '
            'help first=$helpFinishesFirst', (tester) async {
          final states = StreamController<RobotFaceState>.broadcast();
          addTearDown(states.close);
          final authorization = Completer<bool>();
          final help = Completer<bool>();
          final terminalLog = Completer<bool>();
          var helpCalls = 0;
          var terminalCalls = 0;
          await tester.pumpWidget(
            _ActionHostTestApp(
              stateStream: states.stream,
              actionAuthorizer: (_) => authorization.future,
              doseActionLogger: (_, event, _) {
                if (event.kind == DoseLogEventKind.caregiverHelpRequested) {
                  helpCalls++;
                  return helpCalls == 1 ? help.future : Future.value(true);
                }
                terminalCalls++;
                return terminalCalls == 1
                    ? terminalLog.future
                    : Future.value(true);
              },
              visibleAndTakenLogger:
                  (
                    _, {
                    required doseId,
                    required occurredAt,
                    required successMessage,
                  }) {
                    terminalCalls++;
                    return terminalCalls == 1
                        ? terminalLog.future
                        : Future.value(true);
                  },
            ),
          );
          states.add(
            readyState.copyWith(
              availableActions: {terminal, RobotFaceActionKind.askForHelp},
            ),
          );
          await tester.pump();
          final terminalKey = terminal == RobotFaceActionKind.confirmTaken
              ? RobotFaceScreen.confirmTakenButtonKey
              : RobotFaceScreen.skipDoseButtonKey;
          final terminalCallback = tester
              .widget<FilledButton>(find.byKey(terminalKey))
              .onPressed!;
          terminalCallback();
          await tester.pump();
          // Help remains available while PIN authorization is pending.
          final helpCallback = tester
              .widget<FilledButton>(
                find.byKey(RobotFaceScreen.needHelpButtonKey),
              )
              .onPressed!;
          helpCallback();
          await tester.pump();
          expect(helpCalls, 1);
          expect(terminalCalls, 0);
          authorization.complete(true);
          await tester.pump();
          expect(terminalCalls, 1);
          if (helpFinishesFirst) {
            help.complete(false);
          } else if (throws) {
            terminalLog.completeError(StateError('terminal failure'));
          } else {
            terminalLog.complete(false);
          }
          await tester.pump();
          // Exercise both the rendered button and a pre-rebuild callback.
          helpCallback();
          await tester.pump();
          expect(helpCalls, 1);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(RobotFaceScreen.needHelpButtonKey),
                )
                .onPressed,
            isNull,
          );
          if (!helpFinishesFirst) {
            help.complete(false);
          } else if (throws) {
            terminalLog.completeError(StateError('terminal failure'));
          } else {
            terminalLog.complete(false);
          }
          await tester.pump();
          // Both failures release their own lock, allowing genuine retries.
          tester
              .widget<FilledButton>(
                find.byKey(RobotFaceScreen.needHelpButtonKey),
              )
              .onPressed!();
          await tester.pump();
          expect(helpCalls, 2);
          tester.widget<FilledButton>(find.byKey(terminalKey)).onPressed!();
          await tester.pump();
          expect(terminalCalls, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  const skipState = RobotFaceState(
    mode: RobotFaceMode.waitingForConfirmation,
    nextEventLabel: 'Taken? · Morning meds',
    isFlipped: false,
    isLandscapeOnly: true,
    rampProgress: 1,
    isInAwakeWindow: true,
    actionDoseId: 'dose-1',
    availableActions: {RobotFaceActionKind.skipDose},
  );

  testWidgets(
    'retains one action host and panel through actionable follow-up and hidden idle states',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final semantics = tester.ensureSemantics();
      addTearDown(states.close);

      try {
        await tester.pumpWidget(_ActionHostTestApp(stateStream: states.stream));
        final hostFinder = find.byKey(
          RobotFaceScreen.actionHostKey,
          skipOffstage: false,
        );
        final panelFinder = find.byKey(
          RobotFaceScreen.actionPanelKey,
          skipOffstage: false,
        );
        final confirmFinder = find.byKey(
          RobotFaceScreen.confirmTakenButtonKey,
          skipOffstage: false,
        );

        states.add(readyState);
        await tester.pump();
        final panelState = tester.state(panelFinder);
        expect(hostFinder, findsOneWidget);
        expect(panelFinder, findsOneWidget);
        expect(tester.getSize(hostFinder).height, greaterThan(0));

        states.add(
          readyState.copyWith(
            mode: RobotFaceMode.missed,
            availableActions: const {RobotFaceActionKind.recognizeMissedDose},
          ),
        );
        await tester.pump();
        expect(hostFinder, findsOneWidget);
        expect(panelFinder, findsOneWidget);
        expect(tester.state(panelFinder), same(panelState));
        expect(tester.getSize(hostFinder).height, greaterThan(0));

        states.add(
          readyState.copyWith(mode: RobotFaceMode.idle, actionDoseId: null),
        );
        await tester.pump();
        final confirmFocus = Focus.of(
          tester.element(confirmFinder),
          scopeOk: false,
        );
        expect(hostFinder, findsOneWidget);
        expect(panelFinder, findsOneWidget);
        expect(tester.state(panelFinder), same(panelState));
        expect(tester.getSize(hostFinder), Size.zero);
        expect(confirmFinder, findsOneWidget);
        expect(confirmFinder.hitTestable(), findsNothing);
        expect(find.bySemanticsLabel('I can see it and took it'), findsNothing);
        expect(confirmFocus.canRequestFocus, isFalse);
        confirmFocus.requestFocus();
        await tester.pump();
        expect(confirmFocus.hasFocus, isFalse);

        states.add(readyState);
        await tester.pump();
        expect(hostFinder, findsOneWidget);
        expect(panelFinder, findsOneWidget);
        expect(tester.state(panelFinder), same(panelState));
        expect(tester.getSize(hostFinder).height, greaterThan(0));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'keeps the action panel State mounted while actions hide and show',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final semantics = tester.ensureSemantics();
      addTearDown(states.close);

      try {
        await tester.pumpWidget(_ActionHostTestApp(stateStream: states.stream));
        states.add(readyState);
        await tester.pump();

        final panelFinder = find.byKey(
          RobotFaceScreen.actionPanelKey,
          skipOffstage: false,
        );
        final hostFinder = find.byKey(RobotFaceScreen.actionHostKey);
        final initialState = tester.state(panelFinder);
        expect(hostFinder, findsOneWidget);
        expect(tester.getSize(hostFinder).height, greaterThan(0));
        expect(
          find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          findsOneWidget,
        );
        states.add(readyState.copyWith(availableActions: const {}));
        await tester.pump();

        expect(panelFinder, findsOneWidget);
        expect(tester.state(panelFinder), same(initialState));
        expect(tester.getSize(hostFinder), Size.zero);
        expect(
          find
              .byKey(RobotFaceScreen.confirmTakenButtonKey, skipOffstage: false)
              .hitTestable(),
          findsNothing,
        );
        expect(find.bySemanticsLabel('I can see it and took it'), findsNothing);
        states.add(readyState);
        await tester.pump();

        expect(tester.state(panelFinder), same(initialState));
        expect(
          find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('hidden retained Confirm cannot retain or receive focus', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);

    await tester.pumpWidget(_ActionHostTestApp(stateStream: states.stream));
    states.add(readyState);
    await tester.pump();

    final confirmFocus = Focus.of(
      tester.element(find.text('I can see it and took it')),
      scopeOk: false,
    );
    expect(confirmFocus.canRequestFocus, isTrue);
    confirmFocus.requestFocus();
    await tester.pump();
    expect(confirmFocus.hasFocus, isTrue);

    states.add(
      readyState.copyWith(actionDoseId: null, availableActions: const {}),
    );
    await tester.pump();

    expect(confirmFocus.hasFocus, isFalse);
    expect(confirmFocus.canRequestFocus, isFalse);
    confirmFocus.requestFocus();
    await tester.pump();
    expect(confirmFocus.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isNot(same(confirmFocus)));
  });

  testWidgets(
    'does not duplicate a nonterminal help submission before rebuild',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedDoseActionLogger();
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          doseActionLogger: logger.call,
        ),
      );
      states.add(helpState);
      await tester.pump();

      final help = find.byKey(RobotFaceScreen.needHelpButtonKey);
      final onPressed = tester.widget<FilledButton>(help).onPressed!;
      onPressed();
      onPressed();
      await tester.pump();

      expect(logger.calls, 1);
      logger.complete();
      await tester.pump();
    },
  );

  testWidgets('keeps confirm disabled after it completes while hidden', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(states.close);

    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    states.add(
      readyState.copyWith(actionDoseId: null, availableActions: const {}),
    );
    await tester.pump();

    logger.complete();
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('keeps an in-flight confirm submission locked across hiding', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(states.close);

    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    expect(logger.calls, 1);

    states.add(readyState.copyWith(availableActions: const {}));
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    final confirm = find.byKey(RobotFaceScreen.confirmTakenButtonKey);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(confirm);
    await tester.pump();
    expect(logger.calls, 1);

    logger.complete();
    await tester.pump();
  });

  testWidgets(
    'continues a PIN-authorized confirm after actions hide and show',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedVisibleAndTakenLogger();
      addTearDown(database.close);
      addTearDown(states.close);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      ).setActionPin('1234');

      await tester.pumpWidget(
        _ActionHostTestApp(
          database: database,
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      expect(find.text('Enter Action PIN'), findsOneWidget);

      states.add(
        readyState.copyWith(actionDoseId: null, availableActions: const {}),
      );
      await tester.pump();
      states.add(readyState);
      await tester.pump();

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(logger.calls, 1);
      logger.complete();
      await tester.pump();
      expect(logger.calls, 1);
    },
  );

  testWidgets('does not continue a PIN-authorized confirm after A-B-A', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedVisibleAndTakenLogger();
    addTearDown(database.close);
    addTearDown(states.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');

    await tester.pumpWidget(
      _ActionHostTestApp(
        database: database,
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();
    states.add(readyState.copyWith(actionDoseId: 'dose-2'));
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(logger.calls, 0);
  });

  testWidgets('does not continue a PIN-authorized skip after A-B-A', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _DelayedDoseActionLogger();
    addTearDown(database.close);
    addTearDown(states.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    ).setActionPin('1234');

    await tester.pumpWidget(
      _ActionHostTestApp(
        database: database,
        stateStream: states.stream,
        doseActionLogger: logger.call,
      ),
    );
    states.add(skipState);
    await tester.pump();

    await tester.tap(find.byKey(RobotFaceScreen.skipDoseButtonKey));
    await tester.pump();
    states.add(skipState.copyWith(actionDoseId: 'dose-2'));
    await tester.pump();
    states.add(skipState);
    await tester.pump();

    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(logger.calls, 0);
  });

  testWidgets(
    'does not continue a PIN-authorized confirm after it becomes unavailable',
    (tester) async {
      final database = DoseyDatabase.inMemory();
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedVisibleAndTakenLogger();
      addTearDown(database.close);
      addTearDown(states.close);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      ).setActionPin('1234');

      await tester.pumpWidget(
        _ActionHostTestApp(
          database: database,
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      states.add(readyState.copyWith(availableActions: const {}));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(logger.calls, 0);
    },
  );

  testWidgets(
    'keeps the panel State but resets completed actions for a new dose',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _ImmediateVisibleAndTakenLogger();
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();
      final panelFinder = find.byKey(
        RobotFaceScreen.actionPanelKey,
        skipOffstage: false,
      );
      final initialState = tester.state(panelFinder);

      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed,
        isNull,
      );

      states.add(readyState.copyWith(actionDoseId: 'dose-2'));
      await tester.pump();

      expect(tester.state(panelFinder), same(initialState));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('prunes completed lockouts after a different dose is current', (
    tester,
  ) async {
    final states = StreamController<RobotFaceState>.broadcast();
    final logger = _ImmediateVisibleAndTakenLogger();
    addTearDown(states.close);

    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        visibleAndTakenLogger: logger.call,
      ),
    );
    states.add(readyState);
    await tester.pump();
    await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
    await tester.pump();

    states.add(readyState.copyWith(actionDoseId: 'dose-2'));
    await tester.pump();
    states.add(readyState);
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(RobotFaceScreen.confirmTakenButtonKey),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'does not retain an old async completion after a newer transient dose',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedVisibleAndTakenLogger();
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          visibleAndTakenLogger: logger.call,
        ),
      );
      states.add(readyState);
      await tester.pump();
      await tester.tap(find.byKey(RobotFaceScreen.confirmTakenButtonKey));
      await tester.pump();

      states.add(readyState.copyWith(actionDoseId: 'dose-2'));
      await tester.pump();
      states.add(
        readyState.copyWith(actionDoseId: null, availableActions: const {}),
      );
      await tester.pump();
      logger.complete();
      await tester.pump();
      states.add(readyState);
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(RobotFaceScreen.confirmTakenButtonKey),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'does not retain old Help completion after a newer transient dose',
    (tester) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final logger = _DelayedDoseActionLogger();
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          doseActionLogger: logger.call,
        ),
      );
      states.add(helpState);
      await tester.pump();
      await tester.tap(find.byKey(RobotFaceScreen.needHelpButtonKey));
      await tester.pump();

      states.add(helpState.copyWith(actionDoseId: 'dose-2'));
      await tester.pump();
      states.add(
        helpState.copyWith(actionDoseId: null, availableActions: const {}),
      );
      await tester.pump();
      logger.complete();
      await tester.pump();
      states.add(helpState);
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.byKey(RobotFaceScreen.needHelpButtonKey))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final action in <RobotFaceActionKind>[
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    testWidgets('reserves ${action.name} while PIN authorization is pending', (
      tester,
    ) async {
      final states = StreamController<RobotFaceState>.broadcast();
      final authorizer = _DelayedActionAuthorizer();
      var doseActionCalls = 0;
      var visibleAndTakenCalls = 0;
      addTearDown(states.close);

      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          actionAuthorizer: authorizer.call,
          doseActionLogger: (_, _, _) async {
            doseActionCalls += 1;
            return true;
          },
          visibleAndTakenLogger:
              (
                _, {
                required doseId,
                required occurredAt,
                required successMessage,
              }) async {
                visibleAndTakenCalls += 1;
                return true;
              },
        ),
      );
      states.add(
        readyState.copyWith(availableActions: <RobotFaceActionKind>{action}),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(
          action == RobotFaceActionKind.confirmTaken
              ? RobotFaceScreen.confirmTakenButtonKey
              : RobotFaceScreen.skipDoseButtonKey,
        ),
      );
      button.onPressed!.call();
      button.onPressed!.call();
      await tester.pump();

      expect(authorizer.calls, 1);
      authorizer.complete();
      await tester.pump();

      expect(doseActionCalls, action == RobotFaceActionKind.skipDose ? 1 : 0);
      expect(
        visibleAndTakenCalls,
        action == RobotFaceActionKind.confirmTaken ? 1 : 0,
      );
    });
  }

  for (final firstAction in <RobotFaceActionKind>[
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    testWidgets(
      'reserves a dose across ${firstAction.name} and the other terminal action',
      (tester) async {
        final states = StreamController<RobotFaceState>.broadcast();
        final authorizer = _DelayedActionAuthorizer();
        final loggedEvents = <DoseLogEventKind>[];
        var takenCalls = 0;
        addTearDown(states.close);

        await tester.pumpWidget(
          _ActionHostTestApp(
            stateStream: states.stream,
            actionAuthorizer: authorizer.call,
            doseActionLogger: (_, action, _) async {
              loggedEvents.add(action.kind);
              return true;
            },
            visibleAndTakenLogger:
                (
                  _, {
                  required doseId,
                  required occurredAt,
                  required successMessage,
                }) async {
                  takenCalls++;
                  return true;
                },
          ),
        );
        states.add(
          readyState.copyWith(
            availableActions: const {
              RobotFaceActionKind.confirmTaken,
              RobotFaceActionKind.skipDose,
            },
          ),
        );
        await tester.pump();

        final firstKey = firstAction == RobotFaceActionKind.confirmTaken
            ? RobotFaceScreen.confirmTakenButtonKey
            : RobotFaceScreen.skipDoseButtonKey;
        final otherKey = firstAction == RobotFaceActionKind.confirmTaken
            ? RobotFaceScreen.skipDoseButtonKey
            : RobotFaceScreen.confirmTakenButtonKey;
        final first = tester.widget<FilledButton>(find.byKey(firstKey));
        final other = tester.widget<FilledButton>(find.byKey(otherKey));
        first.onPressed!.call();
        other.onPressed!.call();
        await tester.pump();

        expect(authorizer.calls, 1);
        expect(loggedEvents, isEmpty);
        expect(takenCalls, 0);
        authorizer.complete();
        await tester.pump();
        expect(
          loggedEvents,
          firstAction == RobotFaceActionKind.skipDose
              ? [DoseLogEventKind.doseSkipped]
              : isEmpty,
        );
        expect(
          takenCalls,
          firstAction == RobotFaceActionKind.confirmTaken ? 1 : 0,
        );
      },
    );
  }

  for (final action in <RobotFaceActionKind>[
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    testWidgets(
      'releases ${action.name} after an authorization error for retry',
      (tester) async {
        final states = StreamController<RobotFaceState>.broadcast();
        final authorizer = _FailingOnceActionAuthorizer();
        addTearDown(states.close);

        await tester.pumpWidget(
          _ActionHostTestApp(
            stateStream: states.stream,
            actionAuthorizer: authorizer.call,
          ),
        );
        states.add(
          readyState.copyWith(availableActions: <RobotFaceActionKind>{action}),
        );
        await tester.pump();

        final key = action == RobotFaceActionKind.confirmTaken
            ? RobotFaceScreen.confirmTakenButtonKey
            : RobotFaceScreen.skipDoseButtonKey;
        tester.widget<FilledButton>(find.byKey(key)).onPressed!.call();
        await tester.pump();
        await tester.pump();

        expect(
          tester.widget<FilledButton>(find.byKey(key)).onPressed,
          isNotNull,
        );
        tester.widget<FilledButton>(find.byKey(key)).onPressed!.call();
        await tester.pump();
        expect(authorizer.calls, 2);
      },
    );
  }
}

class _ActionHostTestApp extends StatefulWidget {
  const _ActionHostTestApp({
    required this.stateStream,
    this.database,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
  });

  final Stream<RobotFaceState> stateStream;
  final DoseyDatabase? database;
  final RobotFaceDoseActionLogger? doseActionLogger;
  final RobotFaceVisibleAndTakenLogger? visibleAndTakenLogger;
  final RobotFaceActionAuthorizer? actionAuthorizer;

  @override
  State<_ActionHostTestApp> createState() => _ActionHostTestAppState();
}

class _ActionHostTestAppState extends State<_ActionHostTestApp> {
  late final DoseyDatabase _database =
      widget.database ?? DoseyDatabase.inMemory();

  @override
  void dispose() {
    if (widget.database == null) unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: _database,
      bleGateway: _FakeBleGateway(),
      connectivityGateway: _FakeConnectivityGateway(),
      permissionGateway: _FakePermissionGateway(),
      reminderScheduler: _FakeReminderScheduler(),
      missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
      child: MaterialApp(
        home: RobotFaceScreen(
          stateStream: widget.stateStream,
          doseActionLogger: widget.doseActionLogger,
          visibleAndTakenLogger: widget.visibleAndTakenLogger,
          actionAuthorizer: widget.actionAuthorizer,
        ),
      ),
    );
  }
}

class _DelayedVisibleAndTakenLogger {
  final Completer<bool> _completion = Completer<bool>();
  int calls = 0;

  Future<bool> call(
    BuildContext context, {
    required String doseId,
    required DateTime occurredAt,
    required String successMessage,
  }) {
    calls += 1;
    return _completion.future;
  }

  void complete() => _completion.complete(true);
}

class _DelayedActionAuthorizer {
  final Completer<bool> _completion = Completer<bool>();
  int calls = 0;

  Future<bool> call(BuildContext context) {
    calls += 1;
    return _completion.future;
  }

  void complete() => _completion.complete(true);
}

class _FailingOnceActionAuthorizer {
  int calls = 0;

  Future<bool> call(BuildContext context) {
    calls += 1;
    if (calls == 1) {
      return Future<bool>.error(StateError('authorization failed'));
    }
    return Future<bool>.value(true);
  }
}

class _DelayedDoseActionLogger {
  final Completer<bool> _completion = Completer<bool>();
  int calls = 0;

  Future<bool> call(
    BuildContext context,
    DoseLogEvent event,
    String successMessage,
  ) {
    calls += 1;
    return _completion.future;
  }

  void complete() => _completion.complete(true);
}

class _ImmediateVisibleAndTakenLogger {
  Future<bool> call(
    BuildContext context, {
    required String doseId,
    required DateTime occurredAt,
    required String successMessage,
  }) async => true;
}

class _FakeMissedDoseReconciliationService
    extends MissedDoseReconciliationService {
  _FakeMissedDoseReconciliationService()
    : super(reminders: _FakeReminderRepository(), doseLog: _FakeDoseLog());

  @override
  Future<void> reconcile() async {}
}

class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<int> deleteSchedule(String id, {AdminAuditEvent? auditEvent}) async =>
      1;

  @override
  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    AdminAuditEvent? auditEvent,
  }) async {}

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    return Stream.value(const <ReminderSchedule>[]);
  }
}

class _FakeDoseLog implements DoseLogRepository {
  @override
  Future<void> addEvent(DoseLogEvent event) async {}

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    return Stream.value(const <DoseLogEvent>[]);
  }
}

class _FakeBleGateway implements BleGateway {
  @override
  Future<void> close() async {}

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() {
    return Stream.value(const BleAvailabilitySnapshot.available());
  }

  @override
  Stream<BleConnectionSnapshot> watchConnection() {
    return Stream.value(const BleConnectionSnapshot.disconnected());
  }
}

class _FakeConnectivityGateway implements ConnectivityGateway {
  @override
  Future<ConnectivityState> currentConnectivity() async =>
      ConnectivityState.wifi;

  @override
  Stream<ConnectivityState> watchConnectivity() {
    return Stream.value(ConnectivityState.wifi);
  }
}

class _FakePermissionGateway implements AppPermissionGateway {
  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return AppPermissionState.granted;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return AppPermissionState.granted;
  }
}

class _FakeReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancelDoseReminder(String doseId) async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {}
}
