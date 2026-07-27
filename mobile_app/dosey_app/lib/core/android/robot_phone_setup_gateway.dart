enum RobotPhoneSetupItem {
  bluetooth,
  wifi,
  notifications,
  batteryOptimization,
  secureLock,
}

enum SetupReadiness { ready, actionRequired, permissionRequired, unsupported }

enum RobotPhoneSetupAction {
  bluetoothSettings,
  wifiSettings,
  notificationSettings,
  batteryOptimizationSettings,
  securitySettings,
  appDetails,
}

enum SetupActionResult { opened, unsupported }

abstract interface class RobotPhoneSetupGateway {
  Future<Map<RobotPhoneSetupItem, SetupReadiness>> readStatus();

  Future<SetupActionResult> open(RobotPhoneSetupAction action);
}
