import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/diagnostics/phone_diagnostics_projection.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/power/device_power_source.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const power = DevicePowerSnapshot(
    batteryLevel: null,
    externalPower: ExternalPowerState.unknown,
  );

  test('diagnostics values preserve availability and compare structurally', () {
    const known = DiagnosticsValue<AppPermissionState>.known(
      AppPermissionState.granted,
    );
    const sameKnown = DiagnosticsValue<AppPermissionState>.known(
      AppPermissionState.granted,
    );
    const unknown = DiagnosticsValue<AppPermissionState>.unknown();
    const notApplicable = DiagnosticsValue<AppPermissionState>.notApplicable();

    expect(known.availability, DiagnosticsAvailability.known);
    expect(known.value, AppPermissionState.granted);
    expect(unknown.availability, DiagnosticsAvailability.unknown);
    expect(unknown.value, isNull);
    expect(notApplicable.availability, DiagnosticsAvailability.notApplicable);
    expect(notApplicable.value, isNull);
    expect(known, sameKnown);
    expect(known.hashCode, sameKnown.hashCode);
    expect(known, isNot(unknown));
  });

  test('diagnostics value equality is symmetric across generic types', () {
    const typedKnown = DiagnosticsValue<AppPermissionState>.known(
      AppPermissionState.granted,
    );
    const objectKnown = DiagnosticsValue<Object>.known(
      AppPermissionState.granted,
    );
    const typedUnknown = DiagnosticsValue<AppPermissionState>.unknown();
    const objectUnknown = DiagnosticsValue<Object>.unknown();
    const typedNotApplicable =
        DiagnosticsValue<AppPermissionState>.notApplicable();
    const objectNotApplicable = DiagnosticsValue<Object>.notApplicable();

    for (final pair in <(DiagnosticsValue<Object>, DiagnosticsValue<Object>)>[
      (typedKnown, objectKnown),
      (typedUnknown, objectUnknown),
      (typedNotApplicable, objectNotApplicable),
    ]) {
      expect(pair.$1, pair.$2);
      expect(pair.$2, pair.$1);
      expect(pair.$1.hashCode, pair.$2.hashCode);
    }
  });

  test('maps every reported connectivity transport', () {
    expect(
      PhoneDiagnosticsProjection.connectivityFor(ConnectivityState.offline),
      NormalizedConnectivity.none,
    );
    expect(
      PhoneDiagnosticsProjection.connectivityFor(ConnectivityState.wifi),
      NormalizedConnectivity.wifi,
    );
    expect(
      PhoneDiagnosticsProjection.connectivityFor(ConnectivityState.cellular),
      NormalizedConnectivity.cellular,
    );
    expect(
      PhoneDiagnosticsProjection.connectivityFor(ConnectivityState.other),
      NormalizedConnectivity.other,
    );
  });

  test('projects applicable null values as unknown', () {
    final snapshot = PhoneDiagnosticsProjection.project(
      notificationPermission: null,
      connectivity: null,
      runtimeCapability: null,
      effectiveDeviceRole: null,
      devicePower: null,
    );

    expect(
      snapshot.notificationPermission.availability,
      DiagnosticsAvailability.unknown,
    );
    expect(snapshot.connectivity.availability, DiagnosticsAvailability.unknown);
    expect(
      snapshot.runtimeCapability.availability,
      DiagnosticsAvailability.unknown,
    );
    expect(
      snapshot.effectiveDeviceRole.availability,
      DiagnosticsAvailability.unknown,
    );
    expect(snapshot.devicePower.availability, DiagnosticsAvailability.unknown);
  });

  test(
    'normalizes an unknown notification permission to diagnostics unknown',
    () {
      final snapshot = PhoneDiagnosticsProjection.project(
        notificationPermission: AppPermissionState.unknown,
        connectivity: ConnectivityState.wifi,
        runtimeCapability: RuntimeCapability.phoneOnly,
        effectiveDeviceRole: AppDeviceRole.androidRobot,
        devicePower: power,
      );

      expect(
        snapshot.notificationPermission.availability,
        DiagnosticsAvailability.unknown,
      );
      expect(snapshot.notificationPermission.value, isNull);
    },
  );

  test(
    'inapplicable inputs remain not applicable when values are supplied',
    () {
      final snapshot = PhoneDiagnosticsProjection.project(
        notificationPermission: AppPermissionState.granted,
        notificationPermissionApplicable: false,
        connectivity: ConnectivityState.wifi,
        connectivityApplicable: false,
        runtimeCapability: RuntimeCapability.phoneOnly,
        effectiveDeviceRole: AppDeviceRole.androidRobot,
        devicePower: power,
        devicePowerApplicable: false,
      );

      expect(
        snapshot.notificationPermission.availability,
        DiagnosticsAvailability.notApplicable,
      );
      expect(
        snapshot.connectivity.availability,
        DiagnosticsAvailability.notApplicable,
      );
      expect(
        snapshot.devicePower.availability,
        DiagnosticsAvailability.notApplicable,
      );
    },
  );

  test('preserves known runtime capability and effective device role', () {
    final snapshot = PhoneDiagnosticsProjection.project(
      notificationPermission: null,
      connectivity: null,
      runtimeCapability: RuntimeCapability.hardwareAssisted,
      effectiveDeviceRole: AppDeviceRole.iosPersonal,
      devicePower: null,
    );

    expect(
      snapshot.runtimeCapability,
      const DiagnosticsValue<RuntimeCapability>.known(
        RuntimeCapability.hardwareAssisted,
      ),
    );
    expect(
      snapshot.effectiveDeviceRole,
      const DiagnosticsValue<AppDeviceRole>.known(AppDeviceRole.iosPersonal),
    );
  });

  test('keeps a power snapshot known when its observations are unknown', () {
    final snapshot = PhoneDiagnosticsProjection.project(
      notificationPermission: null,
      connectivity: null,
      runtimeCapability: null,
      effectiveDeviceRole: null,
      devicePower: power,
    );

    expect(snapshot.devicePower.availability, DiagnosticsAvailability.known);
    expect(snapshot.devicePower.value, power);
    expect(snapshot.devicePower.value!.batteryLevel, isNull);
    expect(
      snapshot.devicePower.value!.externalPower,
      ExternalPowerState.unknown,
    );
  });

  test('projects each diagnostic field independently', () {
    final snapshot = PhoneDiagnosticsProjection.project(
      notificationPermission: AppPermissionState.denied,
      connectivity: ConnectivityState.cellular,
      runtimeCapability: null,
      effectiveDeviceRole: AppDeviceRole.androidPersonal,
      devicePower: null,
    );

    expect(
      snapshot.notificationPermission,
      const DiagnosticsValue<AppPermissionState>.known(
        AppPermissionState.denied,
      ),
    );
    expect(
      snapshot.connectivity,
      const DiagnosticsValue<NormalizedConnectivity>.known(
        NormalizedConnectivity.cellular,
      ),
    );
    expect(
      snapshot.runtimeCapability.availability,
      DiagnosticsAvailability.unknown,
    );
    expect(
      snapshot.effectiveDeviceRole,
      const DiagnosticsValue<AppDeviceRole>.known(
        AppDeviceRole.androidPersonal,
      ),
    );
    expect(snapshot.devicePower.availability, DiagnosticsAvailability.unknown);
  });
}
