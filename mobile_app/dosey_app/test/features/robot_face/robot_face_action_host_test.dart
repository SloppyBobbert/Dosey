import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/app/dosey_material_app.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
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
import 'package:flutter/rendering.dart';

import 'robot_face_test_font.dart';

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
  for (final action in [
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
    RobotFaceActionKind.askForHelp,
  ]) {
    testWidgets(
      'details toggles retain pending and completed action ownership ${action.name}',
      (tester) async {
        final states = StreamController<RobotFaceState>.broadcast();
        addTearDown(states.close);
        final saved = Completer<bool>();
        var calls = 0;
        await tester.pumpWidget(
          _ActionHostTestApp(
            stateStream: states.stream,
            visibleAndTakenLogger:
                (
                  _, {
                  required doseId,
                  required occurredAt,
                  required successMessage,
                }) {
                  calls++;
                  return saved.future;
                },
            doseActionLogger: (_, event, _) {
              calls++;
              return saved.future;
            },
          ),
        );
        states.add(readyState.copyWith(availableActions: {action}));
        await tester.pump();
        final panel = tester.state(find.byKey(RobotFaceScreen.actionPanelKey));
        final button = find.byKey(switch (action) {
          RobotFaceActionKind.confirmTaken =>
            RobotFaceScreen.confirmTakenButtonKey,
          RobotFaceActionKind.skipDose => RobotFaceScreen.skipDoseButtonKey,
          _ => RobotFaceScreen.needHelpButtonKey,
        });
        final callback = tester.widget<FilledButton>(button).onPressed!;
        await tester.tap(button);
        await tester.pump();
        for (var i = 0; i < 2; i++) {
          await tester.tap(
            find.byKey(const ValueKey('robot-face-toggle-details')),
          );
          await tester.pump();
          expect(
            tester.state(find.byKey(RobotFaceScreen.actionPanelKey)),
            same(panel),
          );
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
        }
        expect(calls, 1);
        saved.complete(true);
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('robot-face-toggle-details')),
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        // Existing terminal callbacks also reject stale invocations. Help's
        // disabled UI is tested here without changing its logger policy.
        if (action != RobotFaceActionKind.askForHelp) callback();
        await tester.pump();
        expect(calls, 1);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
  for (final terminal in [
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    for (final addedDuringAuthorization in [true, false]) {
      testWidgets(
        'terminal completion blocks newly available actions ${terminal.name} pending=$addedDuringAuthorization',
        (tester) async {
          final states = StreamController<RobotFaceState>.broadcast();
          addTearDown(states.close);
          final authorizer = _DelayedActionAuthorizer();
          var terminalCalls = 0;
          var helpCalls = 0;
          await tester.pumpWidget(
            _ActionHostTestApp(
              stateStream: states.stream,
              actionAuthorizer: authorizer.call,
              doseActionLogger: (_, event, _) async {
                if (event.kind == DoseLogEventKind.caregiverHelpRequested) {
                  helpCalls++;
                } else {
                  terminalCalls++;
                }
                return true;
              },
              visibleAndTakenLogger:
                  (
                    _, {
                    required doseId,
                    required occurredAt,
                    required successMessage,
                  }) async {
                    terminalCalls++;
                    return true;
                  },
            ),
          );
          final initial = readyState.copyWith(availableActions: {terminal});
          final expanded = readyState.copyWith(
            availableActions: const {
              RobotFaceActionKind.confirmTaken,
              RobotFaceActionKind.skipDose,
              RobotFaceActionKind.askForHelp,
            },
          );
          states.add(initial);
          await tester.pump();
          final terminalKey = terminal == RobotFaceActionKind.confirmTaken
              ? RobotFaceScreen.confirmTakenButtonKey
              : RobotFaceScreen.skipDoseButtonKey;
          final originalCallback = tester
              .widget<FilledButton>(find.byKey(terminalKey))
              .onPressed!;
          originalCallback();
          await tester.pump();
          if (addedDuringAuthorization) {
            states.add(expanded);
            await tester.pump();
          }
          expect(terminalCalls, 0);
          authorizer.complete();
          await tester.pump();
          expect(terminalCalls, 1);
          if (!addedDuringAuthorization) {
            states.add(expanded);
            await tester.pump();
          }
          for (final key in [
            RobotFaceScreen.confirmTakenButtonKey,
            RobotFaceScreen.skipDoseButtonKey,
          ]) {
            expect(
              tester.widget<FilledButton>(find.byKey(key)).onPressed,
              isNull,
              reason: 'Terminal success closes every terminal kind for dose-1',
            );
          }
          originalCallback();
          await tester.pump();
          expect(authorizer.calls, 1);
          expect(terminalCalls, 1);
          // Host-only Help independence; no post-terminal persistence claim.
          tester
              .widget<FilledButton>(
                find.byKey(RobotFaceScreen.needHelpButtonKey),
              )
              .onPressed!();
          await tester.pump();
          expect(helpCalls, 1);
          states.add(expanded.copyWith(actionDoseId: 'dose-2'));
          await tester.pump();
          for (final key in [
            RobotFaceScreen.confirmTakenButtonKey,
            RobotFaceScreen.skipDoseButtonKey,
            RobotFaceScreen.needHelpButtonKey,
          ]) {
            expect(
              tester.widget<FilledButton>(find.byKey(key)).onPressed,
              isNotNull,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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

  for (final terminal in [
    RobotFaceActionKind.confirmTaken,
    RobotFaceActionKind.skipDose,
  ]) {
    for (final throws in [false, true]) {
      testWidgets(
        'action host with Help still offered: terminal success before Help failure ${terminal.name} throws=$throws',
        (tester) async {
          final states = StreamController<RobotFaceState>.broadcast();
          addTearDown(states.close);
          final authorization = Completer<bool>();
          final terminalLog = Completer<bool>();
          final help = Completer<bool>();
          var helpCalls = 0;
          var terminalCalls = 0;
          var authorizationCalls = 0;
          await tester.pumpWidget(
            _ActionHostTestApp(
              stateStream: states.stream,
              actionAuthorizer: (_) {
                authorizationCalls++;
                return authorization.future;
              },
              doseActionLogger: (_, event, _) {
                if (event.kind == DoseLogEventKind.caregiverHelpRequested) {
                  helpCalls++;
                  return helpCalls == 1 ? help.future : Future.value(true);
                }
                terminalCalls++;
                return terminalLog.future;
              },
              visibleAndTakenLogger:
                  (
                    _, {
                    required doseId,
                    required occurredAt,
                    required successMessage,
                  }) {
                    terminalCalls++;
                    return terminalLog.future;
                  },
            ),
          );
          // This isolates host bookkeeping while the supplied actions still
          // include Help. The production controller/service may close the dose
          // and ignore post-terminal Help; this does not qualify durable retry.
          states.add(
            readyState.copyWith(
              availableActions: const {
                RobotFaceActionKind.confirmTaken,
                RobotFaceActionKind.skipDose,
                RobotFaceActionKind.askForHelp,
              },
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
          tester
              .widget<FilledButton>(
                find.byKey(RobotFaceScreen.needHelpButtonKey),
              )
              .onPressed!();
          await tester.pump();
          expect(helpCalls, 1);
          expect(terminalCalls, 0);
          authorization.complete(true);
          await tester.pump();
          expect(terminalCalls, 1);
          terminalLog.complete(
            true,
          ); // The missing race: real success, not false.
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(RobotFaceScreen.needHelpButtonKey),
                )
                .onPressed,
            isNull,
          );
          if (throws) {
            help.completeError(StateError('Help failure'));
          } else {
            help.complete(false);
          }
          await tester.pump();
          final retry = tester
              .widget<FilledButton>(
                find.byKey(RobotFaceScreen.needHelpButtonKey),
              )
              .onPressed;
          expect(retry, isNotNull);
          retry!();
          await tester.pump();
          expect(helpCalls, 2);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(RobotFaceScreen.needHelpButtonKey),
                )
                .onPressed,
            isNull,
          );
          for (final key in [
            RobotFaceScreen.confirmTakenButtonKey,
            RobotFaceScreen.skipDoseButtonKey,
          ]) {
            expect(
              tester.widget<FilledButton>(find.byKey(key)).onPressed,
              isNull,
            );
          }
          terminalCallback();
          await tester.pump();
          expect(terminalCalls, 1);
          expect(authorizationCalls, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final mode in [
    RobotFaceMode.waitingForConfirmation,
    RobotFaceMode.dispensing,
    RobotFaceMode.missed,
    RobotFaceMode.error,
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('ordinary expanded reachability ${mode.name} ${brightness.name}', (
        tester,
      ) async {
        await tester.runAsync(loadRobotFaceTestFont);
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        await LocalAppSettingsRepository(
          database,
          defaultRole: AppDeviceRole.androidRobot,
        ).setThemePreference(
          brightness == Brightness.light
              ? AppThemePreference.light
              : AppThemePreference.dark,
        );
        final states = StreamController<RobotFaceState>.broadcast();
        addTearDown(states.close);
        const reminder =
            'Now · Fictional extended release morning medication 100 mg / 25 mg combination tablet with breakfast and a full glass of water · final reminder words';
        const status =
            'Controller diagnostic: the fictional dose is visible awaiting confirmation; inspect the cup and contact your caregiver before proceeding · final diagnostic words';
        await tester.pumpWidget(
          _ActionHostTestApp(
            stateStream: states.stream,
            database: database,
            productionScale: mode == RobotFaceMode.error ? 1 : 2,
          ),
        );
        states.add(
          readyState.copyWith(
            mode: mode,
            nextEventLabel: reminder,
            statusLabel: status,
            availableActions: mode == RobotFaceMode.missed
                ? const {RobotFaceActionKind.recognizeMissedDose}
                : const {RobotFaceActionKind.askForHelp},
          ),
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(RobotFaceScreen))).brightness,
          brightness,
        );
        await tester.tap(
          find.byKey(const ValueKey('robot-face-toggle-details')),
        );
        await tester.pumpAndSettle();
        final cardWidth = tester
            .getSize(find.byKey(RobotFaceScreen.bottomCardKey))
            .width;
        final reminderRect = tester.getRect(find.text(reminder));
        expect(
          reminderRect.width,
          greaterThan(cardWidth * .85),
          reason: 'Expanded reminder uses the readable card width',
        );
        if (mode != RobotFaceMode.missed) {
          final statusRect = tester.getRect(find.text(status));
          expect(
            statusRect.top,
            greaterThanOrEqualTo(reminderRect.bottom),
            reason: 'Instructions follow the reminder, never a side pill',
          );
          expect(statusRect.width, greaterThan(cardWidth * .85));
        }
        final labels = [
          reminder,
          status,
          if (mode == RobotFaceMode.missed) ...[
            'Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
          ],
        ];
        await _expectReachableDetails(
          tester,
          labels,
          '${mode.name}_${brightness.name}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('light theme idle details icon contrasts on its control', (
    tester,
  ) async {
    await tester.runAsync(loadRobotFaceTestFont);
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    ).setThemePreference(AppThemePreference.light);
    final states = StreamController<RobotFaceState>.broadcast();
    addTearDown(states.close);
    await tester.pumpWidget(
      _ActionHostTestApp(
        stateStream: states.stream,
        database: database,
        productionScale: 1,
      ),
    );
    states.add(
      readyState.copyWith(mode: RobotFaceMode.idle, availableActions: const {}),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(RobotFaceScreen))).brightness,
      Brightness.light,
    );
    final icon = find.byIcon(Icons.info_outline);
    final color =
        tester.widget<Icon>(icon).color ??
        IconTheme.of(tester.element(icon)).color!;
    final background = tester
        .widget<Material>(
          find
              .descendant(
                of: find.byKey(const ValueKey('robot-face-toggle-details')),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    final foreground = Color.alphaBlend(color, background);
    final luminances = [
      foreground.computeLuminance(),
      background.computeLuminance(),
    ]..sort();
    final contrast = (luminances.last + .05) / (luminances.first + .05);
    expect(contrast, greaterThanOrEqualTo(3));
    await _captureFixture(tester, 'idle_light');
  });

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
    testWidgets('retries ${action.name} after denied authorization', (
      tester,
    ) async {
      final states = StreamController<RobotFaceState>.broadcast();
      addTearDown(states.close);
      var authorizationCalls = 0;
      var terminalCalls = 0;
      await tester.pumpWidget(
        _ActionHostTestApp(
          stateStream: states.stream,
          actionAuthorizer: (_) async => ++authorizationCalls > 1,
          doseActionLogger: (_, _, _) async {
            terminalCalls++;
            return true;
          },
          visibleAndTakenLogger:
              (
                _, {
                required doseId,
                required occurredAt,
                required successMessage,
              }) async {
                terminalCalls++;
                return true;
              },
        ),
      );
      states.add(readyState.copyWith(availableActions: {action}));
      await tester.pump();
      final key = action == RobotFaceActionKind.confirmTaken
          ? RobotFaceScreen.confirmTakenButtonKey
          : RobotFaceScreen.skipDoseButtonKey;
      tester.widget<FilledButton>(find.byKey(key)).onPressed!();
      await tester.pump();
      expect(terminalCalls, 0);
      expect(authorizationCalls, 1);
      tester.widget<FilledButton>(find.byKey(key)).onPressed!();
      await tester.pump();
      expect(authorizationCalls, 2);
      expect(terminalCalls, 1);
      expect(tester.widget<FilledButton>(find.byKey(key)).onPressed, isNull);
    });

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

Future<void> _captureFixture(WidgetTester tester, String name) async {
  final directory = Platform.environment['ROBOT_FACE_FIXTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('ordinary-fixture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _expectReachableDetails(
  WidgetTester tester,
  List<String> labels,
  String fixture,
) async {
  final card = find.byKey(RobotFaceScreen.bottomCardKey);
  final scroll = find.descendant(of: card, matching: find.byType(Scrollable));
  final position = tester.state<ScrollableState>(scroll).position;
  final viewport = find.descendant(
    of: card,
    matching: find.byType(SingleChildScrollView),
  );
  final keys = [
    fixture.startsWith('missed')
        ? RobotFaceScreen.recognizeMissedDoseButtonKey
        : RobotFaceScreen.needHelpButtonKey,
    RobotFaceScreen.exitButtonKey,
  ];
  final pinned = keys.map((key) => tester.getRect(find.byKey(key))).toList();
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final rect in pinned) {
    expect(
      screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
      isTrue,
    );
    expect(rect.shortestSide, greaterThanOrEqualTo(48));
    expect(rect.overlaps(tester.getRect(card)), isFalse);
  }
  final glyphs = <(RenderParagraph, Rect)>[];
  for (final label in labels) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'Expanded text cannot discard a suffix: $label',
    );
    expect(
      paragraph.textScaler.scale(10),
      fixture.startsWith('error') ? 10 : 20,
    );
    expect(paragraph.text.style?.fontFamily, robotFaceTestFont);
    // Check each painted character: an ellipsized suffix cannot silently yield
    // an empty word-box list and pass the traversal assertion.
    for (var i = 0; i < label.length; i++) {
      if (label[i].trim().isEmpty) continue;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      expect(boxes, isNotEmpty, reason: 'Missing glyph $i of $label');
      glyphs.addAll(boxes.map((box) => (paragraph, box.toRect())));
    }
    for (final word in RegExp(r'\S+').allMatches(label)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      );
      expect(boxes, isNotEmpty);
      glyphs.addAll(boxes.map((box) => (paragraph, box.toRect())));
    }
  }
  expect(glyphs, isNotEmpty);
  final reached = <int>{};
  final extent = position.maxScrollExtent;
  final step = position.viewportDimension / 3;
  expect(step, greaterThan(0));
  await _captureFixture(tester, '${fixture}_start');
  for (double offset = 0; offset < extent + step; offset += step) {
    position.jumpTo(offset.clamp(0, extent));
    await tester.pumpAndSettle();
    final visible = tester.getRect(viewport).inflate(.001);
    for (var i = 0; i < glyphs.length; i++) {
      final (paragraph, box) = glyphs[i];
      final rect = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        box,
      );
      if (visible.contains(rect.topLeft) &&
          visible.contains(rect.bottomRight)) {
        reached.add(i);
      }
    }
    for (var i = 0; i < keys.length; i++) {
      expect(tester.getRect(find.byKey(keys[i])), pinned[i]);
    }
  }
  expect(reached.length, glyphs.length);
  await _captureFixture(tester, '${fixture}_end');
}

// Shared by the isolated, real-font presentation preview suite.
Widget robotFacePreviewApp({
  required Stream<RobotFaceState> states,
  required DoseyDatabase database,
  required double scale,
}) => _ActionHostTestApp(
  stateStream: states,
  database: database,
  productionScale: scale,
);

class _ActionHostTestApp extends StatefulWidget {
  const _ActionHostTestApp({
    required this.stateStream,
    this.database,
    this.doseActionLogger,
    this.visibleAndTakenLogger,
    this.actionAuthorizer,
    this.productionScale,
  });

  final double? productionScale;
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
      child: widget.productionScale != null
          ? DoseyMaterialApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(widget.productionScale!),
                    disableAnimations: true,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textTheme: Theme.of(
                        context,
                      ).textTheme.apply(fontFamily: robotFaceTestFont),
                    ),
                    child: RepaintBoundary(
                      key: const ValueKey('ordinary-fixture'),
                      child: RobotFaceScreen(
                        stateStream: widget.stateStream,
                        onLongPress: () {},
                      ),
                    ),
                  ),
                ),
              ),
            )
          : MaterialApp(
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
