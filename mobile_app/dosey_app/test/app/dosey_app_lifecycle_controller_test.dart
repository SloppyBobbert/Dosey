import 'dart:async';

import 'package:dosey_app/app/dosey_app_lifecycle_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects live scope replacement and shuts down the original', () async {
    final controller = DoseyAppLifecycleController();
    final owner = Object();
    var calls = 0;
    controller.attachScope(owner, () async => calls += 1);

    expect(
      () => controller.attachScope(Object(), () async {}),
      throwsStateError,
    );

    await controller.shutdownCurrentScope();
    expect(calls, 1);
  });

  test('rejects live host replacement and shuts down the original', () async {
    final controller = DoseyAppLifecycleController();
    final owner = Object();
    var calls = 0;
    controller.attachHost(owner, () async => calls += 1);

    expect(
      () => controller.attachHost(Object(), () async {}),
      throwsStateError,
    );

    await controller.shutdown();
    expect(calls, 1);
  });

  test('production scope transitions safely to a demo scope', () async {
    final controller = DoseyAppLifecycleController();
    final production = Object();
    final demo = Object();
    final releaseProduction = Completer<void>();
    var productionCalls = 0;
    var demoCalls = 0;
    controller.attachScope(production, () async {
      productionCalls += 1;
      await releaseProduction.future;
    });

    final productionShutdown = controller.shutdownCurrentScope();
    expect(() => controller.attachScope(demo, () async {}), throwsStateError);
    controller.detachScope(production);
    expect(() => controller.attachScope(demo, () async {}), throwsStateError);

    releaseProduction.complete();
    await productionShutdown;
    controller.attachScope(demo, () async => demoCalls += 1);
    controller.detachScope(production);
    await controller.shutdownCurrentScope();

    expect(productionCalls, 1);
    expect(demoCalls, 1);
  });

  test(
    'host detach during scope shutdown cannot start cleanup early',
    () async {
      final controller = DoseyAppLifecycleController();
      final scopeGate = Completer<void>();
      final host = Object();
      var hostCalls = 0;
      controller.attachScope(Object(), () async => scopeGate.future);
      controller.attachHost(host, () async => hostCalls += 1);

      final shutdown = controller.shutdown();
      expect(() => controller.detachHost(host), throwsStateError);
      expect(hostCalls, 0);

      scopeGate.complete();
      await shutdown;
      expect(hostCalls, 1);
    },
  );

  test('host detach during cleanup retains one host shutdown', () async {
    final controller = DoseyAppLifecycleController();
    final host = Object();
    final hostGate = Completer<void>();
    final hostStarted = Completer<void>();
    var hostCalls = 0;
    controller.attachHost(host, () async {
      hostCalls += 1;
      hostStarted.complete();
      await hostGate.future;
    });

    final first = controller.shutdown();
    await hostStarted.future;
    controller.detachHost(host);
    final second = controller.shutdown();
    expect(identical(first, second), isTrue);
    expect(hostCalls, 1);

    hostGate.complete();
    await first;
    expect(hostCalls, 1);
  });

  test('reentrant scope shutdown receives the shared future once', () async {
    final controller = DoseyAppLifecycleController();
    Future<void>? reentrant;
    var calls = 0;
    controller.attachScope(Object(), () {
      calls += 1;
      reentrant = controller.shutdownCurrentScope();
      return Future.value();
    });

    final shutdown = controller.shutdownCurrentScope();
    expect(identical(reentrant, shutdown), isTrue);
    await shutdown;
    expect(calls, 1);
  });

  test(
    'reentrant final shutdown receives one future and cleans up once',
    () async {
      final controller = DoseyAppLifecycleController();
      Future<void>? reentrant;
      var scopeCalls = 0;
      var hostCalls = 0;
      controller.attachScope(Object(), () {
        scopeCalls += 1;
        reentrant = controller.shutdown();
        return Future.value();
      });
      controller.attachHost(Object(), () async => hostCalls += 1);

      final shutdown = controller.shutdown();
      expect(identical(reentrant, shutdown), isTrue);
      await shutdown;
      expect(scopeCalls, 1);
      expect(hostCalls, 1);
    },
  );

  test('preserves scope failure while still running host cleanup', () async {
    final controller = DoseyAppLifecycleController();
    final scopeError = StateError('scope failure');
    var hostCalls = 0;
    controller.attachScope(Object(), () async => throw scopeError);
    controller.attachHost(Object(), () async {
      hostCalls += 1;
      throw StateError('host failure');
    });

    await expectLater(controller.shutdown(), throwsA(same(scopeError)));
    expect(hostCalls, 1);
  });

  test(
    'failed non-final scope shutdown clears its slot for a later scope',
    () async {
      final controller = DoseyAppLifecycleController();
      final failure = StateError('scope failure');
      var laterCalls = 0;
      controller.attachScope(Object(), () async => throw failure);

      await expectLater(
        controller.shutdownCurrentScope(),
        throwsA(same(failure)),
      );
      controller.attachScope(Object(), () async => laterCalls += 1);
      await controller.shutdownCurrentScope();

      expect(laterCalls, 1);
    },
  );

  test('final shutdown rejects attachments and shares its future', () async {
    final controller = DoseyAppLifecycleController();
    final gate = Completer<void>();
    controller.attachScope(Object(), () async => gate.future);

    final first = controller.shutdown();
    final second = controller.shutdown();
    expect(identical(first, second), isTrue);
    expect(
      () => controller.attachScope(Object(), () async {}),
      throwsStateError,
    );
    expect(
      () => controller.attachHost(Object(), () async {}),
      throwsStateError,
    );

    gate.complete();
    await first;
  });
}
