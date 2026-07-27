import 'dart:async';

import 'package:dosey_app/core/display/flutter_system_ui_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate desired states are idempotent', () async {
    var enterCalls = 0;
    var restoreCalls = 0;
    final gateway = FlutterSystemUiGateway.withOperations(
      enterOperation: () async => enterCalls += 1,
      restoreOperation: () async => restoreCalls += 1,
    );

    await Future.wait([gateway.enterRobotFace(), gateway.enterRobotFace()]);
    await Future.wait([gateway.restoreAppUi(), gateway.restoreAppUi()]);

    expect(enterCalls, 1);
    expect(restoreCalls, 1);
  });

  test('delayed stale enter cannot re-hide UI after restore request', () async {
    final enterCompleter = Completer<void>();
    final operations = <String>[];
    final gateway = FlutterSystemUiGateway.withOperations(
      enterOperation: () async {
        operations.add('enter-start');
        await enterCompleter.future;
        operations.add('enter-end');
      },
      restoreOperation: () async => operations.add('restore'),
    );

    final entering = gateway.enterRobotFace();
    await Future<void>.delayed(Duration.zero);
    final restoring = gateway.restoreAppUi();
    enterCompleter.complete();
    await Future.wait([entering, restoring]);

    expect(operations, ['enter-start', 'enter-end', 'restore']);
    expect(gateway.isRobotFaceDesired, isFalse);
  });

  test('platform failure does not block a later restore request', () async {
    var restoreCalls = 0;
    final gateway = FlutterSystemUiGateway.withOperations(
      enterOperation: () => Future<void>.error(StateError('unavailable')),
      restoreOperation: () async => restoreCalls += 1,
    );

    await expectLater(gateway.enterRobotFace(), completes);
    await gateway.restoreAppUi();

    expect(restoreCalls, 1);
    expect(gateway.isRobotFaceDesired, isFalse);
  });
}
