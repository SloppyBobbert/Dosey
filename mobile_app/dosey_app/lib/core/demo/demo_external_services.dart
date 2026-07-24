import 'dart:typed_data';

import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';

class DemoReminderScheduler implements ReminderScheduler {
  const DemoReminderScheduler();

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

class DemoBleGateway implements BleGateway {
  const DemoBleGateway();

  @override
  Future<void> close() async {}

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() {
    return Stream.value(const BleAvailabilitySnapshot.unavailable());
  }

  @override
  Stream<BleConnectionSnapshot> watchConnection() {
    return Stream.value(const BleConnectionSnapshot.disconnected());
  }
}

class DemoConnectivityGateway implements ConnectivityGateway {
  const DemoConnectivityGateway();

  @override
  Future<ConnectivityState> currentConnectivity() async {
    return ConnectivityState.offline;
  }

  @override
  Stream<ConnectivityState> watchConnectivity() {
    return Stream.value(ConnectivityState.offline);
  }
}

class DemoPermissionGateway implements AppPermissionGateway {
  const DemoPermissionGateway();

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return AppPermissionState.denied;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return AppPermissionState.denied;
  }
}

class DemoBackupFileGateway implements BackupFileGateway {
  const DemoBackupFileGateway();

  @override
  Future<bool> hasRecovery() async => false;

  @override
  Future<Uint8List?> pickImportBytes() async => null;

  @override
  Future<Uint8List?> readRecovery() async => null;

  @override
  Future<BackupShareResult> shareExport({
    required Uint8List bytes,
    required String filename,
  }) async => BackupShareResult.unavailable;

  @override
  Future<void> writeRecovery(Uint8List bytes) async {}
}
