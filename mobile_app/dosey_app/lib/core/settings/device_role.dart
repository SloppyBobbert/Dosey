enum AppDevicePlatform { android, ios, web }

enum AppDeviceRole {
  androidRobot(
    storageValue: 'android_robot',
    label: 'Android robot phone',
    canHostRobot: true,
  ),
  androidPersonal(
    storageValue: 'android_personal',
    label: 'Android personal phone',
    canHostRobot: false,
  ),
  iosPersonal(
    storageValue: 'ios_personal',
    label: 'iOS personal phone',
    canHostRobot: false,
  ),
  webPersonal(
    storageValue: 'web_personal',
    label: 'Web personal',
    canHostRobot: false,
  );

  const AppDeviceRole({
    required this.storageValue,
    required this.label,
    required this.canHostRobot,
  });

  final String storageValue;
  final String label;
  final bool canHostRobot;

  static List<AppDeviceRole> allowedFor(AppDevicePlatform platform) {
    return switch (platform) {
      AppDevicePlatform.android => [androidRobot, androidPersonal],
      AppDevicePlatform.ios => [iosPersonal],
      AppDevicePlatform.web => [webPersonal],
    };
  }

  static AppDeviceRole defaultFor(AppDevicePlatform platform) {
    return switch (platform) {
      AppDevicePlatform.android => androidPersonal,
      AppDevicePlatform.ios => iosPersonal,
      AppDevicePlatform.web => webPersonal,
    };
  }

  static AppDeviceRole? fromStorageValue(String value) {
    for (final role in values) {
      if (role.storageValue == value) {
        return role;
      }
    }

    return null;
  }

  bool isAllowedOn(AppDevicePlatform platform) {
    return allowedFor(platform).contains(this);
  }
}
