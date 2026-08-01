import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:dosey_app/core/power/device_power_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BatteryPlusDevicePowerSource', () {
    test('maps battery states to external power presence', () {
      expect(
        BatteryPlusDevicePowerSource.externalPowerFor(BatteryState.charging),
        ExternalPowerState.present,
      );
      expect(
        BatteryPlusDevicePowerSource.externalPowerFor(BatteryState.full),
        ExternalPowerState.present,
      );
      expect(
        BatteryPlusDevicePowerSource.externalPowerFor(
          BatteryState.connectedNotCharging,
        ),
        ExternalPowerState.present,
      );
      expect(
        BatteryPlusDevicePowerSource.externalPowerFor(BatteryState.discharging),
        ExternalPowerState.absent,
      );
      expect(
        BatteryPlusDevicePowerSource.externalPowerFor(BatteryState.unknown),
        ExternalPowerState.unknown,
      );
    });

    test('uses null for battery levels above 100', () async {
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => 101,
        batteryState: () async => BatteryState.charging,
        batteryStateChanges: const Stream<BatteryState>.empty(),
      );

      final snapshot = await source.initialize();

      expect(snapshot.batteryLevel, isNull);
      expect(snapshot.externalPower, ExternalPowerState.present);
      expect(source.currentSnapshot, snapshot);
      await source.dispose();
    });

    test('uses null for negative battery levels', () async {
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => -1,
        batteryState: () async => BatteryState.discharging,
        batteryStateChanges: const Stream<BatteryState>.empty(),
      );

      final snapshot = await source.initialize();

      expect(snapshot.batteryLevel, isNull);
      await source.dispose();
    });

    test('publishes battery state stream updates', () async {
      final states = StreamController<BatteryState>();
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => 64,
        batteryState: () async => BatteryState.discharging,
        batteryStateChanges: states.stream,
      );
      await source.initialize();

      final update = source.snapshots.first;
      states.add(BatteryState.full);

      expect((await update).externalPower, ExternalPowerState.present);
      expect(source.currentSnapshot.batteryLevel, 64);
      await source.dispose();
      await states.close();
    });

    test(
      'keeps a stream power update while accepting a delayed initial level',
      () async {
        final initialLevel = Completer<int>();
        final states = StreamController<BatteryState>();
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () => initialLevel.future,
          batteryState: () async => BatteryState.discharging,
          batteryStateChanges: states.stream,
        );

        final initialization = source.initialize();
        states.add(BatteryState.charging);
        await Future<void>.delayed(Duration.zero);
        initialLevel.complete(40);
        await initialization;

        expect(
          source.currentSnapshot,
          const DevicePowerSnapshot(
            batteryLevel: 40,
            externalPower: ExternalPowerState.present,
          ),
        );
        await source.dispose();
        await states.close();
      },
    );

    test('keeps unknown values explicit when initial reads fail', () async {
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => throw StateError('level unavailable'),
        batteryState: () async => throw StateError('state unavailable'),
        batteryStateChanges: const Stream<BatteryState>.empty(),
      );

      final snapshot = await source.initialize();

      expect(snapshot.batteryLevel, isNull);
      expect(snapshot.externalPower, ExternalPowerState.unknown);
      await source.dispose();
    });

    test(
      'keeps external power when only the battery-level read fails',
      () async {
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () async => throw StateError('level unavailable'),
          batteryState: () async => BatteryState.charging,
          batteryStateChanges: const Stream<BatteryState>.empty(),
        );

        final snapshot = await source.initialize();

        expect(snapshot.batteryLevel, isNull);
        expect(snapshot.externalPower, ExternalPowerState.present);
        await source.dispose();
      },
    );

    test(
      'keeps battery level when only the external-power read fails',
      () async {
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () async => 64,
          batteryState: () async => throw StateError('state unavailable'),
          batteryStateChanges: const Stream<BatteryState>.empty(),
        );

        final snapshot = await source.initialize();

        expect(snapshot.batteryLevel, 64);
        expect(snapshot.externalPower, ExternalPowerState.unknown);
        await source.dispose();
      },
    );

    test(
      'refresh rereads both values and publishes the latest snapshot',
      () async {
        var level = 20;
        var state = BatteryState.discharging;
        var levelReads = 0;
        var stateReads = 0;
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () async {
            levelReads++;
            return level;
          },
          batteryState: () async {
            stateReads++;
            return state;
          },
          batteryStateChanges: const Stream<BatteryState>.empty(),
        );
        await source.initialize();
        level = 80;
        state = BatteryState.charging;

        final snapshot = await source.refresh();

        expect(levelReads, 2);
        expect(stateReads, 2);
        expect(snapshot.batteryLevel, 80);
        expect(snapshot.externalPower, ExternalPowerState.present);
        await source.dispose();
      },
    );

    test(
      'refresh replaces unavailable values with explicit unknown values',
      () async {
        var shouldFail = false;
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () async {
            if (shouldFail) throw StateError('level unavailable');
            return 64;
          },
          batteryState: () async {
            if (shouldFail) throw StateError('state unavailable');
            return BatteryState.charging;
          },
          batteryStateChanges: const Stream<BatteryState>.empty(),
        );
        await source.initialize();
        shouldFail = true;

        final snapshot = await source.refresh();

        expect(snapshot.batteryLevel, isNull);
        expect(snapshot.externalPower, ExternalPowerState.unknown);
        await source.dispose();
      },
    );

    test('coalesces concurrent refresh requests', () async {
      final level = Completer<int>();
      final state = Completer<BatteryState>();
      var levelReads = 0;
      var stateReads = 0;
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () {
          levelReads++;
          return level.future;
        },
        batteryState: () {
          stateReads++;
          return state.future;
        },
        batteryStateChanges: const Stream<BatteryState>.empty(),
      );

      final first = source.refresh();
      final second = source.refresh();
      expect(identical(first, second), isTrue);
      expect(levelReads, 1);
      expect(stateReads, 1);
      level.complete(40);
      state.complete(BatteryState.discharging);

      expect((await first).batteryLevel, 40);
      await source.dispose();
    });

    test(
      'accepts delayed level while rejecting stale external-power read',
      () async {
        final level = Completer<int>();
        final state = Completer<BatteryState>();
        final states = StreamController<BatteryState>();
        final source = BatteryPlusDevicePowerSource.withOperations(
          batteryLevel: () => level.future,
          batteryState: () => state.future,
          batteryStateChanges: states.stream,
        );

        final refresh = source.initialize();
        states.add(BatteryState.charging);
        await Future<void>.delayed(Duration.zero);
        level.complete(40);
        state.complete(BatteryState.discharging);

        final snapshot = await refresh;
        expect(snapshot.batteryLevel, 40);
        expect(snapshot.externalPower, ExternalPowerState.present);
        await source.dispose();
        await states.close();
      },
    );

    test('does not publish delayed refresh values after disposal', () async {
      final level = Completer<int>();
      final state = Completer<BatteryState>();
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () => level.future,
        batteryState: () => state.future,
        batteryStateChanges: const Stream<BatteryState>.empty(),
      );

      final refresh = source.refresh();
      await source.dispose();
      level.complete(40);
      state.complete(BatteryState.charging);

      expect(
        await refresh,
        const DevicePowerSnapshot(
          batteryLevel: null,
          externalPower: ExternalPowerState.unknown,
        ),
      );
      expect(source.currentSnapshot.batteryLevel, isNull);
    });

    test('changes external power to unknown after a stream error', () async {
      final states = StreamController<BatteryState>();
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => 64,
        batteryState: () async => BatteryState.charging,
        batteryStateChanges: states.stream,
      );
      await source.initialize();

      final update = source.snapshots.first;
      states.addError(StateError('state unavailable'));

      expect((await update).externalPower, ExternalPowerState.unknown);
      await source.dispose();
      await states.close();
    });

    test('ignores updates after disposal', () async {
      final states = StreamController<BatteryState>();
      final source = BatteryPlusDevicePowerSource.withOperations(
        batteryLevel: () async => 64,
        batteryState: () async => BatteryState.discharging,
        batteryStateChanges: states.stream,
      );
      await source.initialize();
      await source.dispose();
      states.add(BatteryState.charging);
      await Future<void>.delayed(Duration.zero);

      expect(source.currentSnapshot.externalPower, ExternalPowerState.absent);
      await states.close();
    });
  });

  test('fake source provides deterministic snapshots for tests', () async {
    final source = FakeDevicePowerSource(
      initialSnapshot: const DevicePowerSnapshot(
        batteryLevel: 50,
        externalPower: ExternalPowerState.absent,
      ),
    );
    final update = source.snapshots.first;

    source.emit(
      const DevicePowerSnapshot(
        batteryLevel: 51,
        externalPower: ExternalPowerState.present,
      ),
    );

    expect(await source.initialize(), source.currentSnapshot);
    expect(await source.refresh(), source.currentSnapshot);
    expect((await update).batteryLevel, 51);
    await source.dispose();
  });
}
