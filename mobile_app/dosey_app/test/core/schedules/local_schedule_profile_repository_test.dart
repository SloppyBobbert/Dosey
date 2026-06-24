import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local schedule profile repository seeds one active default profile',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalScheduleProfileRepository(database);

      final profiles = await repository.watchProfiles().first;

      expect(profiles, hasLength(1));
      expect(profiles.single.id, ScheduleProfile.defaultProfileId);
      expect(profiles.single.name, 'Schedule 1');
      expect(profiles.single.isActive, isTrue);
      expect(
        (await repository.watchActiveProfile().first).id,
        ScheduleProfile.defaultProfileId,
      );
    },
  );

  test(
    'local schedule profile repository switches the active profile',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalScheduleProfileRepository(database);
      final createdAt = DateTime.utc(2026, 6, 9, 8);
      final travel = ScheduleProfile(
        id: 'travel',
        name: 'Travel',
        isActive: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.upsertProfile(travel);
      await repository.setActiveProfile('travel');

      final profiles = await repository.watchProfiles().first;
      final active = await repository.watchActiveProfile().first;
      expect(active.id, 'travel');
      expect(profiles.where((profile) => profile.isActive), hasLength(1));
      expect(
        profiles.singleWhere((profile) => profile.id == 'travel').isActive,
        isTrue,
      );
      expect(
        profiles
            .singleWhere(
              (profile) => profile.id == ScheduleProfile.defaultProfileId,
            )
            .isActive,
        isFalse,
      );
    },
  );
}
