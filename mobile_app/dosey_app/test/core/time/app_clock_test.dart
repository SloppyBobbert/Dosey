import 'package:dosey_app/core/time/app_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'system clock stop prevents ticks and leaves the stream closable',
    () async {
      final clock = SystemAppClock(
        tickInterval: const Duration(milliseconds: 1),
      );
      final emitted = <DateTime>[];
      final subscription = clock.ticks.listen(emitted.add);

      clock.stop();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emitted, isEmpty);
      await clock.close();
      await subscription.cancel();
    },
  );

  test('system clock close is idempotent', () async {
    final clock = SystemAppClock(tickInterval: const Duration(days: 1));

    await clock.close();
    await clock.close();
  });

  test(
    'controllable clock advances deterministically and emits each value',
    () async {
      final initial = DateTime.utc(2026, 7, 24, 8);
      final clock = ControllableAppClock(initial);
      final emitted = <DateTime>[];
      final subscription = clock.ticks.listen(emitted.add);

      clock.advance(const Duration(minutes: 30));
      clock.set(DateTime.utc(2026, 7, 24, 9));
      await Future<void>.delayed(Duration.zero);

      expect(clock.now(), DateTime.utc(2026, 7, 24, 9));
      expect(emitted, <DateTime>[
        DateTime.utc(2026, 7, 24, 8, 30),
        DateTime.utc(2026, 7, 24, 9),
      ]);

      await subscription.cancel();
      await clock.close();
      await clock.close();
    },
  );

  test('controllable clock close is idempotent', () async {
    final clock = ControllableAppClock(DateTime.utc(2026, 7, 24, 8));

    await clock.close();
    await clock.close();
  });
}
