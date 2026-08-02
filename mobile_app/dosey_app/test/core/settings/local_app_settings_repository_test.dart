import 'dart:async';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/guided_tour/guided_tour_progress.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart' show SqliteException;

void main() {
  test('theme preference defaults to dark', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      await repository.watchThemePreference().first,
      AppThemePreference.dark,
    );
  });

  test('theme preferences round-trip and emit updates', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    for (final preference in AppThemePreference.values) {
      final update = repository.watchThemePreference().firstWhere(
        (value) => value == preference,
      );

      await repository.setThemePreference(preference);

      expect(await update, preference);
      expect(await repository.watchThemePreference().first, preference);
    }
  });

  test('malformed theme preference falls back to dark', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await database.setAppSetting('theme_preference', 'sepia');

    expect(
      await repository.watchThemePreference().first,
      AppThemePreference.dark,
    );
  });

  test('guided trial is incomplete by default', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.getGuidedTrialCompletion(), isNull);
  });

  test('guided trial completion stores time and app version', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    final completedAt = DateTime.utc(2026, 7, 26, 12, 30);

    await repository.setGuidedTrialCompleted(
      completedAt: completedAt,
      appVersion: '1.0.0+1',
    );

    expect(
      await repository.getGuidedTrialCompletion(),
      GuidedTrialCompletion(completedAt: completedAt, appVersion: '1.0.0+1'),
    );
  });

  test('guided trial ignores malformed or incomplete metadata', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await database.setAppSetting('guided_trial_completed', 'true');
    await database.setAppSetting('guided_trial_completed_at', 'not-a-date');
    await database.setAppSetting('guided_trial_app_version', '');

    expect(await repository.getGuidedTrialCompletion(), isNull);
  });

  test('guided trial completion rejects a blank app version', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      () => repository.setGuidedTrialCompleted(
        completedAt: DateTime.utc(2026, 7, 26),
        appVersion: '   ',
      ),
      throwsArgumentError,
    );
  });

  test('guided tour progress defaults to unseen', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(
      await repository.readGuidedTourProgress(),
      const GuidedTourProgress.unseen(),
    );
  });

  test('guided tour reader normalizes malformed stored rows', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    const keys = {
      'guided_tour_version',
      'guided_tour_state',
      'guided_tour_step',
    };
    final malformedRows = [
      {
        'guided_tour_version': '1',
        'guided_tour_state': 'unknown',
        'guided_tour_step': '0',
      },
      {
        'guided_tour_version': 'invalid',
        'guided_tour_state': 'in_progress',
        'guided_tour_step': '0',
      },
      {
        'guided_tour_version': '1',
        'guided_tour_state': 'in_progress',
        'guided_tour_step': '-1',
      },
      {'guided_tour_version': '1', 'guided_tour_state': 'in_progress'},
      {
        'guided_tour_version': '2',
        'guided_tour_state': 'in_progress',
        'guided_tour_step': '0',
      },
    ];

    for (final row in malformedRows) {
      await database.deleteAppSettings(keys);
      for (final entry in row.entries) {
        await database.setAppSetting(entry.key, entry.value);
      }

      expect(
        await repository.readGuidedTourProgress(),
        const GuidedTourProgress.unseen(),
      );
    }
  });

  test('guided tour progress round-trips current states', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    for (final progress in [
      GuidedTourProgress.inProgress(step: 1),
      GuidedTourProgress.skipped(step: 2),
      GuidedTourProgress.completed(step: 3),
    ]) {
      await repository.writeGuidedTourProgress(progress);

      expect(await repository.readGuidedTourProgress(), progress);
    }
  });

  test('guided tour reads wait for an earlier requested write', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    final progress = GuidedTourProgress.inProgress(step: 2);

    final write = repository.writeGuidedTourProgress(progress);
    final read = repository.readGuidedTourProgress();

    expect(await read, progress);
    await write;
  });

  test('guided tour progress writes all settings with one timestamp', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.writeGuidedTourProgress(
      GuidedTourProgress.inProgress(step: 2),
    );

    final settings = await database.getAppSettings({
      'guided_tour_version',
      'guided_tour_state',
      'guided_tour_step',
    });
    expect(settings, hasLength(3));
    expect(
      {for (final setting in settings) setting.key: setting.value},
      {
        'guided_tour_version': '1',
        'guided_tour_state': 'in_progress',
        'guided_tour_step': '2',
      },
    );
    expect(settings.map((setting) => setting.updatedAt).toSet(), hasLength(1));
  });

  test('guided tour writes complete in request order', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    final gate = _GuidedTourWriteGate();
    addTearDown(gate.release);
    final completions = <String>[];
    final first = database
        .runWithInterceptor(
          () => repository.writeGuidedTourProgress(
            GuidedTourProgress.inProgress(step: 1),
          ),
          interceptor: _GuidedTourFirstWriteInterceptor(gate),
        )
        .then((_) => completions.add('first'));
    await gate.started.future.timeout(const Duration(seconds: 2));
    var secondCompleted = false;
    final second = repository
        .writeGuidedTourProgress(GuidedTourProgress.completed(step: 2))
        .then((_) {
          secondCompleted = true;
          completions.add('second');
        });

    await Future<void>.delayed(Duration.zero);
    expect(completions, isEmpty);
    expect(secondCompleted, isFalse);

    gate.release();
    await Future.wait([first, second]);

    expect(completions, ['first', 'second']);

    expect(
      await repository.readGuidedTourProgress(),
      GuidedTourProgress.completed(step: 2),
    );
  });

  test(
    'a failed guided tour write rolls back the complete stored tuple',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );
      const keys = {
        'guided_tour_version',
        'guided_tour_state',
        'guided_tour_step',
      };
      await repository.writeGuidedTourProgress(
        GuidedTourProgress.completed(step: 4),
      );
      final before = {
        for (final setting in await database.getAppSettings(keys))
          setting.key: setting,
      };
      await database.customStatement('''
      CREATE TRIGGER fail_guided_tour_state_write
      BEFORE INSERT ON app_settings
      WHEN NEW.key = 'guided_tour_state'
      BEGIN
        SELECT RAISE(FAIL, 'deliberate guided tour write failure');
      END;
    ''');
      addTearDown(
        () => database.customStatement(
          'DROP TRIGGER IF EXISTS fail_guided_tour_state_write;',
        ),
      );

      await expectLater(
        repository.writeGuidedTourProgress(
          GuidedTourProgress.inProgress(step: 1),
        ),
        throwsA(isA<SqliteException>()),
      );
      final after = {
        for (final setting in await database.getAppSettings(keys))
          setting.key: setting,
      };
      expect(after, hasLength(3));
      for (final key in keys) {
        expect(after[key]?.value, before[key]?.value);
        expect(after[key]?.updatedAt, before[key]?.updatedAt);
      }
    },
  );

  test('a queued guided tour read survives an earlier failed write', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    final gate = _GuidedTourWriteGate();
    await database.customStatement('''
      CREATE TRIGGER fail_in_progress_guided_tour_state_write
      BEFORE INSERT ON app_settings
      WHEN NEW.key = 'guided_tour_state' AND NEW.value = 'in_progress'
      BEGIN
        SELECT RAISE(FAIL, 'deliberate guided tour write failure');
      END;
    ''');
    addTearDown(
      () => database.customStatement(
        'DROP TRIGGER IF EXISTS fail_in_progress_guided_tour_state_write;',
      ),
    );
    addTearDown(gate.release);

    final first = database.runWithInterceptor(
      () => repository.writeGuidedTourProgress(
        GuidedTourProgress.inProgress(step: 1),
      ),
      interceptor: _GuidedTourFirstWriteInterceptor(gate),
    );
    await gate.started.future.timeout(const Duration(seconds: 2));
    final second = repository.writeGuidedTourProgress(
      GuidedTourProgress.completed(step: 2),
    );
    final read = repository.readGuidedTourProgress();
    var readCompleted = false;
    read.then((_) => readCompleted = true);

    await Future<void>.delayed(Duration.zero);
    expect(readCompleted, isFalse);

    gate.release();

    await expectLater(first, throwsA(isA<SqliteException>()));
    await second;

    expect(await read, GuidedTourProgress.completed(step: 2));
  });

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

  test('local app settings persist onboarding completion', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchOnboardingCompleted().first, isFalse);

    await repository.setOnboardingCompleted(true);

    expect(await repository.watchOnboardingCompleted().first, isTrue);
  });

  test('local app settings reset setup state together', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setSafetyAcknowledged(true);
    await repository.setOnboardingCompleted(true);

    await repository.resetSetupState();

    expect(await repository.watchSafetyAcknowledged().first, isFalse);
    expect(await repository.watchOnboardingCompleted().first, isFalse);
  });

  test('action PIN is disabled by default', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    expect(await repository.watchActionPinEnabled().first, isFalse);
    expect(await repository.verifyActionPin('1234'), isFalse);
  });

  test('action PIN stores verification data without plaintext PIN', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setActionPin('1234');

    expect(await repository.watchActionPinEnabled().first, isTrue);
    expect(await repository.verifyActionPin('1234'), isTrue);
    expect(await repository.verifyActionPin('4321'), isFalse);

    final storedSettings = await database.getAppSettings({
      'action_pin_hash',
      'action_pin_salt',
    });
    expect(
      storedSettings.map((setting) => setting.value),
      isNot(contains('1234')),
    );
  });

  test('action PIN rejects non-digit values', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await expectLater(repository.setActionPin('12a4'), throwsArgumentError);
    await expectLater(repository.setActionPin('12 34'), throwsArgumentError);
    expect(await repository.watchActionPinEnabled().first, isFalse);
  });

  test('action PIN can be cleared', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );

    await repository.setActionPin('1234');
    await repository.clearActionPin();

    expect(await repository.watchActionPinEnabled().first, isFalse);
    expect(await repository.verifyActionPin('1234'), isFalse);
  });

  test('action PIN lifecycle audits without storing secrets', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    const actorType = AdminAuditActorType.localAdmin;

    await repository.setActionPin(
      '1234',
      auditEvent: AdminAuditEvent(
        eventType: AdminAuditEventType.pinEnabled,
        targetType: AdminAuditTargetType.pin,
        actorType: actorType,
        actorLabel: 'local admin',
        sourceDeviceRole: 'androidPersonal',
        summary: 'enabled pin',
        occurredAt: DateTime.utc(2026, 7, 21),
      ),
    );
    await repository.clearActionPin(
      auditEvent: AdminAuditEvent(
        eventType: AdminAuditEventType.pinDisabled,
        targetType: AdminAuditTargetType.pin,
        actorType: actorType,
        actorLabel: 'local admin',
        sourceDeviceRole: 'androidPersonal',
        summary: 'disabled pin',
        occurredAt: DateTime.utc(2026, 7, 21, 0, 0, 1),
      ),
    );

    final rows = await database.select(database.adminAuditEvents).get();
    expect(rows, hasLength(2));
    expect(rows.every((row) => !(row.summary.contains('1234'))), isTrue);
    expect(
      rows.every((row) => !(row.detailsJson ?? '').contains('1234')),
      isTrue,
    );
  });
}

class _GuidedTourWriteGate {
  final started = Completer<void>();
  final _release = Completer<void>();

  Future<void> get released => _release.future;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}

class _GuidedTourFirstWriteInterceptor extends QueryInterceptor {
  _GuidedTourFirstWriteInterceptor(this._gate);

  final _GuidedTourWriteGate _gate;
  var _paused = false;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(statement, args);
    if (!_paused &&
        statement.contains('app_settings') &&
        args.contains('guided_tour_version')) {
      _paused = true;
      _gate.started.complete();
      await _gate.released;
    }
    return result;
  }
}
