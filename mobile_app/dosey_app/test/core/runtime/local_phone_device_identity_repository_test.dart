import 'package:dosey_app/core/runtime/local_phone_device_identity_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists one bounded device identity across repository restarts',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);

      final first = LocalPhoneDeviceIdentityRepository(
        database,
        createId: () => 'phone-0123456789abcdef',
      );
      final second = LocalPhoneDeviceIdentityRepository(
        database,
        createId: () => 'phone-should-not-replace',
      );

      expect(await first.getOrCreate(), 'phone-0123456789abcdef');
      expect(await second.getOrCreate(), 'phone-0123456789abcdef');
    },
  );

  test(
    'rejects malformed persisted identities instead of replacing them',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'phone_device_id_v1',
              value: 'contains spaces',
              updatedAt: DateTime.utc(2040),
            ),
          );

      final repository = LocalPhoneDeviceIdentityRepository(database);

      await expectLater(repository.getOrCreate(), throwsStateError);
    },
  );
}
