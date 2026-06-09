import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local app settings persist safety acknowledgement', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchSafetyAcknowledged().first, isFalse);

    await repository.setSafetyAcknowledged(true);

    expect(await repository.watchSafetyAcknowledged().first, isTrue);
  });
}
