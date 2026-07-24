import 'package:dosey_app/core/time/app_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    },
  );
}
