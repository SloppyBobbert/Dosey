import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/today/phone_only_today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('records duplicate Taken taps once and queues one mutation', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    await fixture.pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Taken'));
    await tester.pumpAndSettle();

    expect(
      await fixture.database
          .select(fixture.database.phoneDoseActionEvents)
          .get(),
      hasLength(1),
    );
    expect(
      await fixture.database.select(fixture.database.syncOutboxMutations).get(),
      hasLength(1),
    );
    expect(find.text('Taken recorded'), findsOneWidget);
  });

  testWidgets('Snooze persists locally and schedules a one-time reminder', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    await fixture.pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Snooze'));
    await tester.pumpAndSettle();

    expect(fixture.scheduler.scheduled, hasLength(1));
    expect(fixture.scheduler.scheduled.single.repeatsDaily, isFalse);
    expect(
      fixture.scheduler.scheduled.single.scheduledFor,
      fixture.clock.now().add(const Duration(minutes: 10)),
    );
    expect(
      await fixture.database
          .select(fixture.database.phoneDoseActionEvents)
          .get(),
      hasLength(1),
    );
  });
}

class _Fixture {
  _Fixture(this.database, this.clock, this.scheduler);

  final DoseyDatabase database;
  final ControllableAppClock clock;
  final _RecordingScheduler scheduler;

  static Future<_Fixture> create() async {
    final database = DoseyDatabase.inMemory();
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    final scheduler = _RecordingScheduler();
    await LocalScheduleProfileRepository(database).upsertProfile(
      ScheduleProfile(
        id: ScheduleProfile.defaultProfileId,
        name: 'Home',
        isActive: true,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'morning',
        label: 'Morning medicine',
        prescriptionId: 'med-1',
        hour: 8,
        minute: 0,
        isEnabled: true,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
    return _Fixture(database, clock, scheduler);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      DoseyAppScope(
        database: database,
        appClock: clock,
        runtimeCapability: RuntimeCapability.phoneOnly,
        buildProfile: AppBuildProfile.robot,
        reminderScheduler: scheduler,
        localTimezoneGateway: const _UtcTimezoneGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
        voicePlayer: DoseyVoicePlayer(playbackGateway: _SilentVoiceGateway()),
        child: const MaterialApp(home: Scaffold(body: PhoneOnlyTodayScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() async {
    await clock.close();
    await database.close();
  }
}

class _Scheduled {
  const _Scheduled(this.scheduledFor, this.repeatsDaily);
  final DateTime scheduledFor;
  final bool repeatsDaily;
}

class _RecordingScheduler implements ReminderScheduler {
  final scheduled = <_Scheduled>[];

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
  }) async {
    scheduled.add(_Scheduled(scheduledFor, repeatsDaily));
  }
}

class _UtcTimezoneGateway implements LocalTimezoneGateway {
  const _UtcTimezoneGateway();

  @override
  Future<String> localTimezoneName() async => 'UTC';
}

class _SilentVoiceGateway implements VoicePlaybackGateway {
  @override
  Future<void> dispose() async {}
  @override
  bool get isPlaying => false;
  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {}
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Future<void> stop() async {}
}
