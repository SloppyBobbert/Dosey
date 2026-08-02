import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/power/device_power_source.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/settings/device_role.dart';

enum DiagnosticsAvailability { known, unknown, notApplicable }

class DiagnosticsValue<T extends Object> {
  const DiagnosticsValue.known(T value)
    : this._(availability: DiagnosticsAvailability.known, value: value);

  const DiagnosticsValue.unknown()
    : this._(availability: DiagnosticsAvailability.unknown);

  const DiagnosticsValue.notApplicable()
    : this._(availability: DiagnosticsAvailability.notApplicable);

  const DiagnosticsValue._({required this.availability, this.value});

  final DiagnosticsAvailability availability;
  final T? value;

  @override
  bool operator ==(Object other) {
    return other is DiagnosticsValue<Object> &&
        availability == other.availability &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(availability, value);
}

enum NormalizedConnectivity { none, wifi, cellular, other }

class PhoneDiagnosticsSnapshot {
  const PhoneDiagnosticsSnapshot({
    required this.notificationPermission,
    required this.connectivity,
    required this.runtimeCapability,
    required this.effectiveDeviceRole,
    required this.devicePower,
  });

  final DiagnosticsValue<AppPermissionState> notificationPermission;
  final DiagnosticsValue<NormalizedConnectivity> connectivity;
  final DiagnosticsValue<RuntimeCapability> runtimeCapability;
  final DiagnosticsValue<AppDeviceRole> effectiveDeviceRole;
  final DiagnosticsValue<DevicePowerSnapshot> devicePower;
}

class PhoneDiagnosticsProjection {
  const PhoneDiagnosticsProjection._();

  static PhoneDiagnosticsSnapshot project({
    AppPermissionState? notificationPermission,
    bool notificationPermissionApplicable = true,
    ConnectivityState? connectivity,
    bool connectivityApplicable = true,
    RuntimeCapability? runtimeCapability,
    AppDeviceRole? effectiveDeviceRole,
    DevicePowerSnapshot? devicePower,
    bool devicePowerApplicable = true,
  }) {
    return PhoneDiagnosticsSnapshot(
      notificationPermission: !notificationPermissionApplicable
          ? const DiagnosticsValue<AppPermissionState>.notApplicable()
          : notificationPermission == null ||
                notificationPermission == AppPermissionState.unknown
          ? const DiagnosticsValue<AppPermissionState>.unknown()
          : DiagnosticsValue<AppPermissionState>.known(notificationPermission),
      connectivity: !connectivityApplicable
          ? const DiagnosticsValue<NormalizedConnectivity>.notApplicable()
          : connectivity == null
          ? const DiagnosticsValue<NormalizedConnectivity>.unknown()
          : DiagnosticsValue<NormalizedConnectivity>.known(
              connectivityFor(connectivity),
            ),
      runtimeCapability: runtimeCapability == null
          ? const DiagnosticsValue<RuntimeCapability>.unknown()
          : DiagnosticsValue<RuntimeCapability>.known(runtimeCapability),
      effectiveDeviceRole: effectiveDeviceRole == null
          ? const DiagnosticsValue<AppDeviceRole>.unknown()
          : DiagnosticsValue<AppDeviceRole>.known(effectiveDeviceRole),
      devicePower: !devicePowerApplicable
          ? const DiagnosticsValue<DevicePowerSnapshot>.notApplicable()
          : devicePower == null
          ? const DiagnosticsValue<DevicePowerSnapshot>.unknown()
          : DiagnosticsValue<DevicePowerSnapshot>.known(devicePower),
    );
  }

  /// This reports transport only; it does not prove internet, companion,
  /// controller, hardware, or cloud availability.
  static NormalizedConnectivity connectivityFor(
    ConnectivityState connectivity,
  ) {
    return switch (connectivity) {
      ConnectivityState.offline => NormalizedConnectivity.none,
      ConnectivityState.wifi => NormalizedConnectivity.wifi,
      ConnectivityState.cellular => NormalizedConnectivity.cellular,
      ConnectivityState.other => NormalizedConnectivity.other,
    };
  }
}
