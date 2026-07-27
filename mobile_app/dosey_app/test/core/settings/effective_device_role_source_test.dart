import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/effective_device_role_source.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;
  late LocalAppSettingsRepository settings;

  setUp(() {
    database = DoseyDatabase.inMemory();
    settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
  });

  tearDown(() => database.close());

  test('stale Robot setting cannot enable Personal capabilities', () async {
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    final source = EffectiveDeviceRoleSource(
      settings,
      profile: AppBuildProfile.personal,
      platform: AppDevicePlatform.android,
    );

    expect(await source.getDeviceRole(), AppDeviceRole.androidPersonal);
    expect(await source.watchDeviceRole().first, AppDeviceRole.androidPersonal);
    expect(source.capabilities.canHostRobot, isFalse);
  });

  test('imported Personal setting cannot disable Robot capabilities', () async {
    await settings.setDeviceRole(AppDeviceRole.androidPersonal);
    final source = EffectiveDeviceRoleSource(
      settings,
      profile: AppBuildProfile.robot,
      platform: AppDevicePlatform.android,
    );

    expect(await source.getDeviceRole(), AppDeviceRole.androidRobot);
    expect(await source.watchDeviceRole().first, AppDeviceRole.androidRobot);
    expect(source.capabilities.canHostRobot, isTrue);
  });

  test('iOS remains Personal when Robot profile is supplied', () async {
    final source = EffectiveDeviceRoleSource(
      settings,
      profile: AppBuildProfile.robot,
      platform: AppDevicePlatform.ios,
    );

    expect(await source.getDeviceRole(), AppDeviceRole.iosPersonal);
    expect(source.capabilities.showsRobotFace, isFalse);
  });
}
