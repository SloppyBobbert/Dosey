import 'dart:async';

import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/features/settings/robot_phone_setup_screen.dart';
import 'package:dosey_app/features/shell/external_action_resume_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows observed readiness without claiming settings changed', (
    tester,
  ) async {
    final gateway = _FakeSetupGateway(
      status: {
        RobotPhoneSetupItem.bluetooth: SetupReadiness.permissionRequired,
        RobotPhoneSetupItem.wifi: SetupReadiness.ready,
        RobotPhoneSetupItem.notifications: SetupReadiness.actionRequired,
        RobotPhoneSetupItem.batteryOptimization: SetupReadiness.actionRequired,
        RobotPhoneSetupItem.secureLock: SetupReadiness.unsupported,
      },
    );

    await tester.pumpWidget(_TestApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Robot phone setup'), findsOneWidget);
    expect(find.text('Bluetooth permission required'), findsOneWidget);
    expect(find.text('Wi-Fi ready'), findsOneWidget);
    expect(find.text('Notifications need attention'), findsOneWidget);
    expect(
      find.textContaining('Status is checked from Android'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Secure lock status unavailable'),
      200,
    );
    expect(find.text('Secure lock status unavailable'), findsOneWidget);
    expect(find.textContaining('changed'), findsNothing);
  });

  testWidgets('opens Android settings under a settings resume lease', (
    tester,
  ) async {
    final openCompleter = Completer<SetupActionResult>();
    final gateway = _FakeSetupGateway(openCompleter: openCompleter);
    final guard = ExternalActionResumeGuard<String>();

    await tester.pumpWidget(_TestApp(gateway: gateway, guard: guard));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Open Bluetooth'));
    await tester.pump();

    expect(gateway.actions, [RobotPhoneSetupAction.bluetoothSettings]);
    guard.didChangeLifecycleState(AppLifecycleState.paused);
    expect(guard.consumeResumeTarget(), 'settings');
    openCompleter.complete(SetupActionResult.opened);
    await tester.pumpAndSettle();
  });

  testWidgets('refreshes observed status when the app resumes', (tester) async {
    final gateway = _FakeSetupGateway();
    await tester.pumpWidget(_TestApp(gateway: gateway));
    await tester.pumpAndSettle();
    expect(gateway.readCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(gateway.readCount, 2);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.gateway, this.guard});

  final RobotPhoneSetupGateway gateway;
  final ExternalActionResumeGuard<String>? guard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RobotPhoneSetupScreen(
        gateway: gateway,
        externalActionResumeGuard: guard ?? ExternalActionResumeGuard<String>(),
      ),
    );
  }
}

class _FakeSetupGateway implements RobotPhoneSetupGateway {
  _FakeSetupGateway({
    Map<RobotPhoneSetupItem, SetupReadiness>? status,
    this.openCompleter,
  }) : status =
           status ??
           {
             for (final item in RobotPhoneSetupItem.values)
               item: SetupReadiness.ready,
           };

  final Map<RobotPhoneSetupItem, SetupReadiness> status;
  final Completer<SetupActionResult>? openCompleter;
  final List<RobotPhoneSetupAction> actions = [];
  int readCount = 0;

  @override
  Future<SetupActionResult> open(RobotPhoneSetupAction action) async {
    actions.add(action);
    return openCompleter?.future ?? SetupActionResult.opened;
  }

  @override
  Future<Map<RobotPhoneSetupItem, SetupReadiness>> readStatus() async {
    readCount += 1;
    return status;
  }
}
