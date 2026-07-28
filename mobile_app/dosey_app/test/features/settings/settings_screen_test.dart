import 'dart:async';
import 'dart:convert';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/android/robot_phone_setup_gateway.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/backup/backup_codec.dart';
import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/build/app_build_profile.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/local_household_cache_repository.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/onboarding/household_membership_gate.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/settings/settings_accordion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';
import '../../support/fake_cloud_identity_gateway.dart';

void main() {
  testWidgets('personal settings show compact collapsed daily groups', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.personal,
      ),
    );
    await tester.pumpAndSettle();

    final titles = _accordionTitles(tester);
    expect(titles, const [
      'Account & household',
      'Reminders',
      'Appearance',
      'Help & safety',
    ]);
    for (final accordion in _accordions(tester)) {
      expect(accordion.expanded, isFalse);
    }
    expect(find.text('Maintenance'), findsNothing);
    expect(find.text('No local admin changes recorded yet.'), findsNothing);
    expect(find.text('Backup and database'), findsNothing);
  });

  testWidgets('robot settings show service access outside daily groups', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();

    final titles = _accordionTitles(tester);
    expect(titles, const [
      'Device & connection',
      'Robot Face',
      'Reminders',
      'Appearance',
      'Help & safety',
    ]);
    for (final accordion in _accordions(tester)) {
      expect(accordion.expanded, isFalse);
    }
    expect(find.text('Maintenance'), findsOneWidget);
  });

  testWidgets(
    'robot maintenance asks for the Action PIN before service tools',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final settings = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidRobot,
      );
      await settings.setDeviceRole(AppDeviceRole.androidRobot);
      await settings.setActionPin('1234');

      await tester.pumpWidget(
        _TestSettingsApp(
          database: database,
          buildProfile: AppBuildProfile.robot,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open tools'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Action PIN'), findsOneWidget);
      expect(find.text('Hardware bench'), findsNothing);

      await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('For setup and repairs'), findsOneWidget);
      expect(find.text('Hardware bench'), findsOneWidget);
      expect(find.text('Robot phone setup'), findsOneWidget);
    },
  );

  testWidgets(
    'technical records stay out of ordinary settings and in Maintenance',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
      await LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidRobot,
      ).setActionPin('1234');

      await tester.pumpWidget(
        _TestSettingsApp(
          database: database,
          buildProfile: AppBuildProfile.robot,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin history'), findsNothing);
      expect(find.text('Backup and database'), findsNothing);
      await _openMaintenanceRecords(tester);
      expect(find.text('Admin history'), findsOneWidget);
      expect(find.text('Backup and database'), findsOneWidget);
      expect(find.text('Export backup'), findsOneWidget);
      expect(find.text('Restore backup'), findsOneWidget);
      expect(find.text('Check database'), findsOneWidget);
    },
  );

  testWidgets('demo mode disables backup and restore actions', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    addTearDown(database.close);
    addTearDown(clock.close);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        appClock: clock,
        buildProfile: AppBuildProfile.robot,
      ),
    );
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    ).setActionPin('1234');
    await tester.pumpAndSettle();
    await _openMaintenanceRecords(tester);

    expect(
      find.text(
        'Backup and restore are unavailable while FAKE DATA is active.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Export backup'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Restore backup'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('backup export warning is followed by Action PIN', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await settings.setOnboardingCompleted(true);
    await settings.setActionPin('1234');

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();
    await _openMaintenanceRecords(tester);

    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();
    expect(find.text('Export unencrypted backup?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter Action PIN'), findsOneWidget);
  });

  testWidgets('database health check does not require Action PIN', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await settings.setOnboardingCompleted(true);
    await settings.setActionPin('1234');

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();
    await _openMaintenanceRecords(tester);
    final checkDatabaseButton = find.widgetWithText(
      OutlinedButton,
      'Check database',
    );
    await tester.ensureVisible(checkDatabaseButton);
    await tester.pumpAndSettle();
    await tester.tap(checkDatabaseButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter Action PIN'), findsNothing);
    expect(find.text('Database check passed.'), findsOneWidget);
  });

  testWidgets('restore previews validated record count before replacement', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    final document = await LocalBackupStore(database).readSnapshot();
    final gateway = _FakeBackupFileGateway(
      picked: const BackupCodec().encode(document),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        backupFileGateway: gateway,
        buildProfile: AppBuildProfile.robot,
      ),
    );
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    ).setActionPin('1234');
    await tester.pumpAndSettle();
    await _openMaintenanceRecords(tester);
    final restoreBackup = find.text('Restore backup');
    await tester.ensureVisible(restoreBackup);
    await tester.tap(restoreBackup);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Replace local backup data?'), findsOneWidget);
    expect(
      find.textContaining('${document.summary.totalRecords} records'),
      findsOneWidget,
    );
    expect(find.text('Replace data'), findsOneWidget);
  });

  testWidgets('Robot Mode does not offer account sign-in', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Account'), findsNothing);
  });

  testWidgets('Personal Mode retains account sign-in', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    await _openSettingsAccordion(tester, 'Account & household');

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('Personal phone cannot change its fixed device role', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.personal,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettingsAccordion(tester, 'Account & household');

    expect(find.text('Personal phone'), findsOneWidget);
    expect(find.byType(DropdownButton<AppDeviceRole>), findsNothing);
    expect(find.text('Leave Robot Mode?'), findsNothing);
  });

  testWidgets('Robot phone exposes setup without account actions', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final setupGateway = _FakeRobotPhoneSetupGateway();
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    await LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidRobot,
    ).setActionPin('1234');

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        robotPhoneSetupGateway: setupGateway,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettingsAccordion(tester, 'Device & connection');
    expect(find.text('Robot phone'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
    final settingsScrollable = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Maintenance'),
      300,
      scrollable: settingsScrollable,
    );
    await tester.pumpAndSettle();

    final openTools = find.byKey(const Key('open-maintenance-tools'));
    expect(openTools, findsOneWidget);

    await tester.ensureVisible(openTools);
    await tester.pumpAndSettle();

    expect(openTools.hitTestable(), findsOneWidget);
    await tester.tap(openTools);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final openSetup = find.widgetWithText(OutlinedButton, 'Robot phone setup');
    expect(openSetup.hitTestable(), findsOneWidget);
    await tester.tap(openSetup);
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth ready'), findsOneWidget);
  });

  testWidgets('robot-capable role shows robot face settings controls', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidRobot);
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);

    expect(_robotFaceAccordion(), findsOneWidget);
    expect(find.text('Flip face 180°'), findsOneWidget);
    expect(find.text('For upside-down mounts.'), findsOneWidget);
    expect(find.text('Dim after inactivity'), findsOneWidget);
    expect(find.text('Return to Robot Face'), findsOneWidget);
    expect(find.text('PIR wake duration'), findsOneWidget);
    expect(
      find.text(
        'Motion or touch keeps Robot Face awake for this long. Android controls when the display turns off afterward.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'When Robot Mode is open on another tab, return to the face after this much inactivity.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'After quiet time, show a darker resting face. Dose alerts still stay bright.',
      ),
      findsOneWidget,
    );
    expect(find.text('Wake before dose'), findsOneWidget);
    expect(find.text('Stay awake after dose'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('voice-preview:Reminder voice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('voice-preview:Dispense narration')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('voice-preview:Safety/confirmation voice'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('voice-preview:Missed dose voice')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('voice-preview:Controller alert voice'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('voice-preview:Idle chatter voice')),
      findsOneWidget,
    );
    expect(
      find.text('Brighten the face before a scheduled dose.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Keep the face awake while someone confirms, skips, or asks for help.',
      ),
      findsOneWidget,
    );
    expect(find.text('10 minutes'), findsWidgets);
  });

  testWidgets('personal role does not show robot face settings controls', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidPersonal);
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsNothing);
    expect(find.text('Robot Face'), findsNothing);
    expect(find.text('Flip face 180°'), findsNothing);
    expect(find.text('Dim after inactivity'), findsNothing);
    expect(_accordionTitles(tester), isNot(contains('Robot Face')));
  });

  testWidgets('robot face controls persist and update state', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidRobot);
    await tester.pumpAndSettle();

    final repository = DoseyAppScope.of(scope).robotFaceSettings;

    expect(await repository.getSettings(), const RobotFaceSettings());

    await _scrollToRobotFace(tester);

    await tester.tap(find.text('Flip face 180°'));
    await tester.pumpAndSettle();
    expect(
      await repository.getSettings(),
      const RobotFaceSettings(isFlipped: true),
    );

    await tester.tap(find.text('Dim after inactivity'));
    await tester.pumpAndSettle();
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Return to Robot Face:2'),
      value: 5,
    );
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('PIR wake duration:60'),
      value: 120,
    );
    await tester.tap(find.text('Robot voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice variety'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Voice volume'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await _setDropdownValue<RobotVoiceVolumePreset>(
      tester,
      key: const ValueKey<String>('Voice volume:RobotVoiceVolumePreset.normal'),
      value: RobotVoiceVolumePreset.loud,
    );
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Idle chatter cooldown:10'),
      value: 15,
    );
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Reminder repeat cooldown:5'),
      value: 10,
    );
    await _setDropdownValue<RobotReminderRepeatPolicy>(
      tester,
      key: const ValueKey<String>(
        'Reminder repeat policy:RobotReminderRepeatPolicy.noRepeats',
      ),
      value: RobotReminderRepeatPolicy.repeatRemindersOnly,
    );
    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Quiet hours end'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Quiet hours start:1320'),
      value: 21 * 60,
    );
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Quiet hours end:420'),
      value: 6 * 60,
    );
    await tester.tap(find.text('Allow safety voice during quiet hours'));
    await tester.pumpAndSettle();
    expect(
      await repository.getSettings(),
      const RobotFaceSettings(
        isFlipped: true,
        dimAfterInactivity: false,
        returnToFaceAfterInactivityMinutes: 5,
        pirWakeDurationSeconds: 120,
        voiceEnabled: true,
        voiceVarietyEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.loud,
        voiceQuietHoursEnabled: true,
        voiceQuietHoursStartMinutes: 21 * 60,
        voiceQuietHoursEndMinutes: 6 * 60,
        voiceSafetyDuringQuietHoursEnabled: true,
        reminderVoiceEnabled: true,
        dispenseNarrationEnabled: true,
        safetyConfirmationVoiceEnabled: true,
        missedDoseVoiceEnabled: true,
        controllerAlertVoiceEnabled: true,
        idleChatterVoiceEnabled: true,
        idleChatterCooldownMinutes: 15,
        reminderRepeatCooldownMinutes: 10,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersOnly,
      ),
    );

    await tester.tap(find.text('Reminder voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dispense narration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Safety/confirmation voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missed dose voice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Controller alert voice'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller alert voice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idle chatter voice'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Wake before dose'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Wake before dose:10'),
      value: 15,
    );
    await _setDropdownValue<int>(
      tester,
      key: const ValueKey<String>('Stay awake after dose:10'),
      value: 30,
    );

    final updatedSettings = await repository.getSettings();
    expect(updatedSettings.isFlipped, isTrue);
    expect(updatedSettings.dimAfterInactivity, isFalse);
    expect(updatedSettings.voiceEnabled, isTrue);
    expect(updatedSettings.voiceVarietyEnabled, isTrue);
    expect(updatedSettings.voiceVolumePreset, RobotVoiceVolumePreset.loud);
    expect(updatedSettings.voiceQuietHoursEnabled, isTrue);
    expect(updatedSettings.voiceQuietHoursStartMinutes, 21 * 60);
    expect(updatedSettings.voiceQuietHoursEndMinutes, 6 * 60);
    expect(updatedSettings.voiceSafetyDuringQuietHoursEnabled, isTrue);
    expect(updatedSettings.reminderVoiceEnabled, isFalse);
    expect(updatedSettings.dispenseNarrationEnabled, isFalse);
    expect(updatedSettings.safetyConfirmationVoiceEnabled, isFalse);
    expect(updatedSettings.missedDoseVoiceEnabled, isFalse);
    expect(updatedSettings.controllerAlertVoiceEnabled, isFalse);
    expect(updatedSettings.idleChatterVoiceEnabled, isFalse);
    expect(updatedSettings.idleChatterCooldownMinutes, 15);
    expect(updatedSettings.reminderRepeatCooldownMinutes, 10);
    expect(
      updatedSettings.reminderRepeatPolicy,
      RobotReminderRepeatPolicy.repeatRemindersOnly,
    );
    expect(updatedSettings.wakeBeforeDoseMinutes, 15);
    expect(updatedSettings.stayAwakeAfterDoseMinutes, 30);
    expect(updatedSettings.pirWakeDurationSeconds, 120);

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.elementAt(0).value, isTrue);
    expect(switches.elementAt(1).value, isFalse);
    expect(switches.elementAt(2).value, isTrue);
    expect(switches.elementAt(3).value, isTrue);
    expect(switches.elementAt(4).value, isTrue);
    expect(switches.elementAt(5).value, isTrue);
    expect(switches.elementAt(6).value, isFalse);
    expect(switches.elementAt(7).value, isFalse);
    expect(switches.elementAt(8).value, isFalse);
    expect(switches.elementAt(9).value, isFalse);
    expect(switches.elementAt(10).value, isFalse);
    expect(switches.elementAt(11).value, isFalse);
    expect(find.text('Loud'), findsOneWidget);
    expect(find.text('15 minutes'), findsWidgets);
    expect(find.text('10 minutes'), findsWidgets);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('6:00 AM'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('saved robot face timing values render on load', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(
        idleChatterCooldownMinutes: 15,
        reminderRepeatCooldownMinutes: 10,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersAndReady,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);

    expect(find.text('15 minutes'), findsWidgets);
    expect(find.text('10 minutes'), findsWidgets);
    expect(find.text('Repeat reminders and dose ready'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('test voice button uses safe phrase and current volume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final liveVoiceGateway = _FakeVoicePlaybackGateway();
    final previewVoiceGateway = _FakeVoicePlaybackGateway();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(
        voiceEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.loud,
      ),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        voicePlayer: DoseyVoicePlayer(playbackGateway: liveVoiceGateway),
        previewVoicePlayer: DoseyVoicePlayer(
          playbackGateway: previewVoiceGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);
    await tester.scrollUntilVisible(
      find.text('Test voice'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test voice'));
    await tester.pumpAndSettle();

    expect(previewVoiceGateway.playedPhrases, [DoseyVoicePhrase.ready]);
    expect(previewVoiceGateway.lastVolume, RobotVoiceVolumePreset.loud.volume);
    expect(liveVoiceGateway.playedPhrases, isEmpty);
  });

  testWidgets('category preview uses expected phrase and current volume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    final liveVoiceGateway = _FakeVoicePlaybackGateway();
    final previewVoiceGateway = _FakeVoicePlaybackGateway();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await RobotFaceSettingsRepository(database).saveSettings(
      const RobotFaceSettings(
        voiceEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.quiet,
      ),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        voicePlayer: DoseyVoicePlayer(playbackGateway: liveVoiceGateway),
        previewVoicePlayer: DoseyVoicePlayer(
          playbackGateway: previewVoiceGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('voice-preview:Reminder voice')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('voice-preview:Reminder voice')),
    );
    await tester.pumpAndSettle();

    expect(previewVoiceGateway.playedPhrases, [DoseyVoicePhrase.doseSoon]);
    expect(previewVoiceGateway.lastVolume, RobotVoiceVolumePreset.quiet.volume);
    expect(liveVoiceGateway.playedPhrases, isEmpty);
    final scope = tester.element(find.byType(MaterialApp));
    expect(
      await DoseyAppScope.of(scope).robotFaceSettings.getSettings(),
      const RobotFaceSettings(
        voiceEnabled: true,
        voiceVolumePreset: RobotVoiceVolumePreset.quiet,
      ),
    );
  });

  testWidgets('voice preview buttons disable with master or category toggle', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);
    await tester.scrollUntilVisible(
      find.text('Reminder voice'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    IconButton reminderPreview() => tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('voice-preview:Reminder voice')),
    );

    expect(reminderPreview().onPressed, isNull);

    await tester.scrollUntilVisible(
      find.text('Robot voice'),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot voice'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reminder voice'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(reminderPreview().onPressed, isNotNull);

    await tester.tap(find.text('Reminder voice'));
    await tester.pumpAndSettle();
    expect(reminderPreview().onPressed, isNull);
  });

  testWidgets('action PIN section enables PIN after matching entry', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    expect(find.text('Action PIN'), findsWidgets);
    expect(find.text('PIN is off'), findsOneWidget);

    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '1234',
    );
    await tester.tap(find.text('Save PIN'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isTrue);
    expect(find.text('PIN is on'), findsOneWidget);
  });

  testWidgets('action PIN section rejects mismatched new PIN values', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '1234',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '4321',
    );
    await tester.tap(find.text('Save PIN'));
    await tester.pump();

    expect(await settings.verifyActionPin('1234'), isFalse);
    expect(find.text('PIN entries do not match.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump();
  });

  testWidgets('action PIN section filters non-digit new PIN values', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    await tester.tap(find.text('Enable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-action-pin-field')),
      '12a4',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-action-pin-field')),
      '12a4',
    );
    final newPinField = tester.widget<TextField>(
      find.byKey(const Key('new-action-pin-field')),
    );
    expect(newPinField.controller?.text, '124');
    await tester.tap(find.text('Save PIN'));
    await tester.pump();

    expect(await settings.verifyActionPin('12a4'), isFalse);
    expect(find.text('Use at least 4 digits.'), findsOneWidget);

    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pump();
  });

  testWidgets('action PIN section requires current PIN before disabling', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await repository.setActionPin('1234');

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    final settings = DoseyAppScope.of(scope).settings;

    await _scrollToActionPin(tester);
    expect(find.text('PIN is on'), findsOneWidget);

    await tester.tap(find.text('Disable PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '4321');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isTrue);
    expect(find.text('Wrong PIN.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.verifyActionPin('1234'), isFalse);
    expect(find.text('PIN is off'), findsOneWidget);
  });

  testWidgets('robot face timing dropdowns resync after repository update', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(database: database, buildProfile: AppBuildProfile.robot),
    );
    await tester.pumpAndSettle();

    final scope = tester.element(find.byType(MaterialApp));
    final repository = DoseyAppScope.of(scope).robotFaceSettings;

    await _scrollToRobotFace(tester);

    expect(find.text('10 minutes'), findsWidgets);

    await repository.saveSettings(
      const RobotFaceSettings(
        idleChatterCooldownMinutes: 15,
        reminderRepeatCooldownMinutes: 10,
        reminderRepeatPolicy: RobotReminderRepeatPolicy.repeatRemindersAndReady,
        wakeBeforeDoseMinutes: 15,
        stayAwakeAfterDoseMinutes: 30,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 minutes'), findsWidgets);
    expect(find.text('15 minutes'), findsWidgets);
    expect(find.text('Repeat reminders and dose ready'), findsOneWidget);
    expect(find.text('30 minutes'), findsOneWidget);
  });

  testWidgets('stale robot role stays hidden on iOS personal mode', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    try {
      await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: 'device_role',
              value: 'android_robot',
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      await tester.pumpWidget(
        _TestSettingsApp(
          database: database,
          sectionTarget: SettingsSection.householdAccount,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile & device'));
      await tester.pumpAndSettle();

      expect(find.text('Robot Face'), findsNothing);
      expect(find.text('Flip face 180°'), findsNothing);
      expect(find.text('Dim after inactivity'), findsNothing);
      expect(find.text('Wake before dose'), findsNothing);
      expect(find.text('Stay awake after dose'), findsNothing);
      expect(find.text('iOS always uses the Personal phone.'), findsOneWidget);
      expect(_findRichTextContaining('iOS personal phone'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'section target opens Account & household for Household profile',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);

      await tester.pumpWidget(
        _TestSettingsApp(
          database: database,
          sectionTarget: SettingsSection.householdAccount,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Household & robot profile').hitTestable(),
        findsWidgets,
      );
      expect(find.text('Profile & device').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('household card shows device/person metadata and not-set labels', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile & device'));
    await tester.pumpAndSettle();

    expect(
      _findRichTextContaining('Household: Dosey household'),
      findsOneWidget,
    );
    expect(_findRichTextContaining('Robot: Dosey robot phone'), findsOneWidget);
    expect(
      _findRichTextContaining(
        'This device: Android personal phone. This device does not control the XIAO controller.',
      ),
      findsOneWidget,
    );
    expect(_findRichTextContaining('Person: Not set'), findsOneWidget);
    expect(_findRichTextContaining('Relationship: Not set'), findsOneWidget);
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    expect(_findRichTextContaining('Cloud sync: Not linked'), findsOneWidget);
  });

  testWidgets('household edit sheet shows optional metadata fields', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile & device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit household & robot profile'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Household name'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Robot name'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Person/profile name'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final option in const [
      'Self',
      'Parent',
      'Grandparent',
      'Child',
      'Caregiver',
      'Other',
    ]) {
      expect(find.text(option), findsWidgets);
    }
  });

  testWidgets('robot owner can generate a temporary mounted-device code', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final pairing = _FakeRobotPairingGateway();

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'owner-1',
            email: 'owner@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(_robotInstallation),
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate robot pairing code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate robot pairing code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(pairing.createdForRobotId, 'robot-1');
    expect(find.text('Pairing code: ABCD2EFGH3'), findsOneWidget);
    expect(find.textContaining('expires'), findsOneWidget);
    final auditRows = await database.select(database.adminAuditEvents).get();
    expect(auditRows, hasLength(1));
    expect(
      auditRows.single.eventType,
      AdminAuditEventType.pairingCodeGenerated.name,
    );
    expect(auditRows.single.targetId, 'robot-1');
  });

  testWidgets('owner generation uses an owner-specific session error', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final pairing = _FakeRobotPairingGateway(
      createFailure: const RobotPairingException(
        RobotPairingFailureReason.missingSession,
      ),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'owner-1',
            email: 'owner@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(_robotInstallation),
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate robot pairing code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate robot pairing code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in again to generate a pairing code.'),
      findsOneWidget,
    );
  });

  testWidgets('owner lists members and generates an email-bound invitation', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final management = _FakeHouseholdManagementGateway();
    final robot = _robotInstallationWithMember();

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'owner-1',
            email: 'owner@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(robot),
        householdManagementGateway: management,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();

    expect(find.text('Owner Person (Owner)'), findsOneWidget);
    expect(find.text('Member Person (Member)'), findsOneWidget);
    expect(find.text('Remove Member Person'), findsOneWidget);

    await tester.ensureVisible(find.text('Generate member invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate member invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Invited Google account email'),
      ' Member@Example.com ',
    );
    await tester.tap(find.text('Generate invitation'));
    await tester.pumpAndSettle();

    expect(management.invitedRobotId, 'robot-1');
    expect(management.invitedEmail, 'member@example.com');
    expect(find.text('Invitation code: ABCD2345EFGH6789'), findsOneWidget);
    final auditRows = await database.select(database.adminAuditEvents).get();
    expect(auditRows, hasLength(1));
    expect(
      auditRows.single.eventType,
      AdminAuditEventType.householdInvitationGenerated.name,
    );
    final details = jsonDecode(auditRows.single.detailsJson!);
    expect(details['invitedEmail'], 'member@example.com');
    expect(auditRows.single.detailsJson, isNot(contains('ABCD2345EFGH6789')));
  });

  testWidgets('owner removal updates the household cache and audit', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final robot = _robotInstallationWithMember();
    final management = _FakeHouseholdManagementGateway(
      removalResult: _robotInstallation,
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'owner-1',
            email: 'owner@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(robot),
        householdManagementGateway: management,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Member Person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();

    expect(management.removedAccountId, 'member-1');
    expect(find.text('Member Person (Member)'), findsNothing);
    final cached = await LocalHouseholdCacheRepository(
      database,
    ).readForAccount('owner-1');
    expect(cached?.installation.members, hasLength(1));
    final auditRows = await database.select(database.adminAuditEvents).get();
    expect(
      auditRows.single.eventType,
      AdminAuditEventType.householdMemberRemoved.name,
    );
  });

  testWidgets('later household sync replaces a local management result', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final sync = _ControllableHouseholdSyncGateway(
      _robotInstallationWithMember(),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'owner-1',
            email: 'owner@example.com',
          ),
        ),
        householdSyncGateway: sync,
        householdManagementGateway: _FakeHouseholdManagementGateway(
          removalResult: _robotInstallation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Member Person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    expect(find.text('Member Person (Member)'), findsNothing);

    sync.emit(
      RobotInstallation(
        id: 'robot-1',
        displayName: 'Renamed Dosey',
        ownerAccountId: 'owner-1',
        members: _robotInstallationWithMember().members,
        currentRole: HouseholdRole.owner,
        mountedDeviceId: 'mounted-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _findRichTextContaining('Cloud robot: Renamed Dosey'),
      findsOneWidget,
    );
    expect(
      find.text('Member Person (Member)', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('non-owner can leave and clears only their household cache', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final robot = _memberRobotInstallation();
    final cache = LocalHouseholdCacheRepository(database);
    await cache.replaceForAccount(
      'member-1',
      robot,
      confirmedAt: DateTime.utc(2026, 7, 26, 12),
    );
    final management = _FakeHouseholdManagementGateway();

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'member-1',
            email: 'member@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(robot),
        householdManagementGateway: management,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();

    expect(find.text('Generate member invitation'), findsNothing);
    expect(find.textContaining('Remove '), findsNothing);
    await tester.ensureVisible(find.text('Leave household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(management.leftRobotId, 'robot-1');
    expect(await cache.readForAccount('member-1'), isNull);
    final auditRows = await database.select(database.adminAuditEvents).get();
    expect(auditRows.single.eventType, AdminAuditEventType.householdLeft.name);
  });

  testWidgets('leaving returns the retained Personal app to create and join', (
    tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    final robot = _memberRobotInstallation();

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.householdAccount,
        cloudIdentityGateway: FakeCloudIdentityGateway(
          identity: const CloudIdentity.signedIn(
            accountId: 'member-1',
            email: 'member@example.com',
          ),
        ),
        householdSyncGateway: _FakeHouseholdSyncGateway(robot),
        householdManagementGateway: _FakeHouseholdManagementGateway(
          beforeLeaveReturn: database.close,
        ),
        gateAccountId: 'member-1',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leave household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave household'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Create a household'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
  });

  testWidgets('Robot Mode can claim an existing robot with a temporary code', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    final pairing = _FakeRobotPairingGateway();
    final household = _RefreshingHouseholdSyncGateway(_robotInstallation);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        sectionTarget: SettingsSection.householdAccount,
        householdSyncGateway: household,
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair this robot phone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '10-character pairing code'),
      'abcd2-efgh3',
    );
    await tester.tap(find.text('Pair robot'));
    await tester.pumpAndSettle();

    expect(pairing.claimedCode, 'abcd2-efgh3');
    expect(household.refreshCount, 1);
    expect(find.text('Robot phone paired.'), findsOneWidget);
    expect(_findRichTextContaining('Cloud sync: Linked'), findsOneWidget);
  });

  testWidgets('disabled pairing configuration hides Robot Mode action', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        sectionTarget: SettingsSection.householdAccount,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();

    expect(find.text('Pair this robot phone'), findsNothing);
    expect(find.text('Robot pairing is not configured.'), findsOneWidget);
  });

  testWidgets('Robot Mode reports when claimed membership cannot refresh', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    final pairing = _FakeRobotPairingGateway(claimedRobotId: 'robot-2');
    final household = _RefreshingHouseholdSyncGateway(_robotInstallation);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        sectionTarget: SettingsSection.householdAccount,
        householdSyncGateway: household,
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair this robot phone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '10-character pairing code'),
      'ABCD2EFGH3',
    );
    await tester.tap(find.text('Pair robot'));
    await tester.pumpAndSettle();

    expect(
      find.text('Robot phone paired, but linked status could not refresh.'),
      findsOneWidget,
    );
  });

  testWidgets('Robot Mode keeps the pairing dialog open for a blank code', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    final pairing = _FakeRobotPairingGateway();

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        sectionTarget: SettingsSection.householdAccount,
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair this robot phone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '10-character pairing code'),
      '   ',
    );
    await tester.tap(find.text('Pair robot'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter a pairing code.'), findsOneWidget);
    expect(pairing.claimedCode, isNull);
  });

  testWidgets('Robot Mode shows the blocked-device pairing error', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);
    final pairing = _FakeRobotPairingGateway(
      claimFailure: const RobotPairingException(
        RobotPairingFailureReason.blockedDevice,
      ),
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        buildProfile: AppBuildProfile.robot,
        sectionTarget: SettingsSection.householdAccount,
        robotPairingGateway: pairing,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Robot linking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair this robot phone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '10-character pairing code'),
      'ABCD2EFGH3',
    );
    await tester.tap(find.text('Pair robot'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many attempts. Wait 15 minutes and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('practice mode shows saved completion status', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setGuidedTrialCompleted(
      completedAt: DateTime.utc(2026, 7, 26),
      appVersion: '1.2.3+4',
    );

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        sectionTarget: SettingsSection.guidedTrial,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Practice mode'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Practice mode'), findsOneWidget);
    expect(
      find.text('Last completed 2026-07-26 UTC with app 1.2.3+4'),
      findsOneWidget,
    );
    expect(find.text('Practice again'), findsOneWidget);
  });

  testWidgets('practice mode disables start while active', (tester) async {
    final database = DoseyDatabase.inMemory(isDemo: true);
    final clock = ControllableAppClock(DateTime.utc(2040, 1, 2, 8));
    addTearDown(database.close);
    addTearDown(clock.close);

    await tester.pumpWidget(
      _TestSettingsApp(
        database: database,
        appClock: clock,
        sectionTarget: SettingsSection.guidedTrial,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Practice mode'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice in progress'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Practice in progress'),
          )
          .onPressed,
      isNull,
    );
  });
}

List<String> _accordionTitles(WidgetTester tester) {
  return _accordions(tester).map((accordion) => accordion.title).toList();
}

List<SettingsAccordion> _accordions(WidgetTester tester) {
  final listView = tester.widget<ListView>(find.byType(ListView));
  final children =
      (listView.childrenDelegate as SliverChildListDelegate).children;
  return children.whereType<SettingsAccordion>().toList();
}

Future<void> _openSettingsAccordion(WidgetTester tester, String title) async {
  final finder = find.text(title);
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _openMaintenanceRecords(WidgetTester tester) async {
  await tester.tap(find.text('Open tools'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Service records'));
  await tester.pumpAndSettle();
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
  );
}

Future<void> _scrollToRobotFace(WidgetTester tester) async {
  final accordion = _robotFaceAccordion();
  await tester.scrollUntilVisible(
    accordion,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  if (!(tester.widget<SettingsAccordion>(accordion).expanded ?? false)) {
    await tester.tap(
      find.descendant(of: accordion, matching: find.text('Robot Face')).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    find.text('Flip face 180°'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _robotFaceAccordion() {
  return find.byWidgetPredicate(
    (widget) => widget is SettingsAccordion && widget.title == 'Robot Face',
  );
}

Future<void> _scrollToActionPin(WidgetTester tester) async {
  await _openSettingsAccordion(tester, 'Account & household');
  final isPinEnabled = find.text('PIN is on').evaluate().isNotEmpty;
  final isPinDisabled = find.text('PIN is off').evaluate().isNotEmpty;
  if (!isPinEnabled && !isPinDisabled) {
    throw StateError('Action PIN controls did not render.');
  }
  await tester.scrollUntilVisible(
    find.text(isPinEnabled ? 'Disable PIN' : 'Enable PIN'),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _setDropdownValue<T>(
  WidgetTester tester, {
  required Key key,
  required T value,
}) async {
  final dropdown = tester.widget<DropdownButton<T>>(
    find.descendant(
      of: find.byKey(key),
      matching: find.byType(DropdownButton<T>),
    ),
  );
  dropdown.onChanged?.call(value);
  await tester.pumpAndSettle();
}

Future<void> _markOnboardingComplete(
  DoseyDatabase database, {
  required AppDeviceRole role,
}) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
  await settings.setOnboardingCompleted(true);
}

class _TestSettingsApp extends StatelessWidget {
  const _TestSettingsApp({
    required this.database,
    this.voicePlayer,
    this.previewVoicePlayer,
    this.sectionTarget,
    this.backupFileGateway,
    this.appClock,
    this.cloudIdentityGateway,
    this.householdSyncGateway,
    this.householdManagementGateway,
    this.robotPairingGateway,
    this.gateAccountId,
    this.buildProfile,
    this.robotPhoneSetupGateway,
  });

  final DoseyDatabase database;
  final DoseyVoicePlayer? voicePlayer;
  final DoseyVoicePlayer? previewVoicePlayer;
  final SettingsSection? sectionTarget;
  final BackupFileGateway? backupFileGateway;
  final AppClock? appClock;
  final CloudIdentityGateway? cloudIdentityGateway;
  final HouseholdSyncGateway? householdSyncGateway;
  final HouseholdManagementGateway? householdManagementGateway;
  final RobotPairingGateway? robotPairingGateway;
  final String? gateAccountId;
  final AppBuildProfile? buildProfile;
  final RobotPhoneSetupGateway? robotPhoneSetupGateway;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      buildProfile: buildProfile,
      appClock: appClock,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      backupFileGateway: backupFileGateway,
      cloudIdentityGateway: cloudIdentityGateway,
      householdSyncGateway: householdSyncGateway,
      householdManagementGateway: householdManagementGateway,
      robotPairingGateway: robotPairingGateway,
      robotPhoneSetupGateway: robotPhoneSetupGateway,
      voicePlayer: voicePlayer,
      child: Builder(
        builder: (scopeContext) {
          final settings = Scaffold(
            body: SettingsScreen(
              sectionTarget: sectionTarget,
              previewVoicePlayer: previewVoicePlayer,
            ),
          );
          final accountId = gateAccountId;
          final home = accountId == null
              ? settings
              : HouseholdMembershipGate(
                  accountId: accountId,
                  sync: DoseyAppScope.of(scopeContext).householdSync,
                  management: DoseyAppScope.of(
                    scopeContext,
                  ).householdManagement,
                  membership: DoseyAppScope.of(
                    scopeContext,
                  ).householdMembership,
                  cache: DoseyAppScope.of(scopeContext).householdCache,
                  runProtectedMutation: (action) async => action(
                    const AdminAuditActorIdentity(
                      actorType: AdminAuditActorType.signedInUser,
                      actorUserId: 'member-1',
                      actorLabel: 'Member',
                      actorProviderLabel: 'Google',
                    ),
                  ),
                  child: settings,
                );
          return MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2F6F5E),
              ),
              useMaterial3: true,
            ),
            home: home,
          );
        },
      ),
    );
  }
}

class _FakeRobotPhoneSetupGateway implements RobotPhoneSetupGateway {
  @override
  Future<SetupActionResult> open(RobotPhoneSetupAction action) async =>
      SetupActionResult.opened;

  @override
  Future<Map<RobotPhoneSetupItem, SetupReadiness>> readStatus() async => {
    for (final item in RobotPhoneSetupItem.values) item: SetupReadiness.ready,
  };
}

final _robotInstallation = RobotInstallation(
  id: 'robot-1',
  displayName: 'Kitchen Dosey',
  ownerAccountId: 'owner-1',
  members: const [
    HouseholdMember(
      accountId: 'owner-1',
      label: 'Owner Person',
      role: HouseholdRole.owner,
    ),
  ],
  currentRole: HouseholdRole.owner,
  mountedDeviceId: 'mounted-1',
);

RobotInstallation _robotInstallationWithMember({
  HouseholdRole currentRole = HouseholdRole.owner,
}) => RobotInstallation(
  id: 'robot-1',
  displayName: 'Kitchen Dosey',
  ownerAccountId: 'owner-1',
  members: const [
    HouseholdMember(
      accountId: 'owner-1',
      label: 'Owner Person',
      role: HouseholdRole.owner,
    ),
    HouseholdMember(
      accountId: 'member-1',
      label: 'Member Person',
      role: HouseholdRole.member,
    ),
  ],
  currentRole: currentRole,
  mountedDeviceId: 'mounted-1',
);

RobotInstallation _memberRobotInstallation() =>
    _robotInstallationWithMember(currentRole: HouseholdRole.member);

class _FakeHouseholdSyncGateway implements HouseholdSyncGateway {
  const _FakeHouseholdSyncGateway(this.robot);

  final RobotInstallation? robot;

  @override
  Stream<RobotInstallation?> watchRobot() => Stream.value(robot);

  @override
  Future<RobotInstallation?> refreshRobot() async => robot;
}

class _ControllableHouseholdSyncGateway implements HouseholdSyncGateway {
  _ControllableHouseholdSyncGateway(this._robot);

  RobotInstallation? _robot;
  final _changes = StreamController<RobotInstallation?>.broadcast();

  void emit(RobotInstallation? robot) {
    _robot = robot;
    _changes.add(robot);
  }

  @override
  Stream<RobotInstallation?> watchRobot() async* {
    yield _robot;
    yield* _changes.stream;
  }

  @override
  Future<RobotInstallation?> refreshRobot() async => _robot;
}

class _RefreshingHouseholdSyncGateway implements HouseholdSyncGateway {
  _RefreshingHouseholdSyncGateway(this.robot);

  final RobotInstallation robot;
  final _changes = StreamController<RobotInstallation?>.broadcast();
  RobotInstallation? _current;
  var refreshCount = 0;

  @override
  Stream<RobotInstallation?> watchRobot() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<RobotInstallation?> refreshRobot() async {
    refreshCount += 1;
    _current = robot;
    _changes.add(robot);
    return robot;
  }
}

class _FakeRobotPairingGateway implements RobotPairingGateway {
  _FakeRobotPairingGateway({
    this.createFailure,
    this.claimFailure,
    this.claimedRobotId = 'robot-1',
  });

  final RobotPairingException? createFailure;
  final RobotPairingException? claimFailure;
  final String claimedRobotId;
  String? createdForRobotId;
  String? claimedCode;

  @override
  bool get isAvailable => true;

  @override
  Future<RobotPairingCredential> createPairingCode({
    required String robotId,
  }) async {
    createdForRobotId = robotId;
    if (createFailure case final failure?) throw failure;
    return RobotPairingCredential(
      code: 'ABCD2EFGH3',
      expiresAt: DateTime.utc(2026, 7, 26, 12, 10),
    );
  }

  @override
  Future<String> claimRobot({required String code}) async {
    claimedCode = code;
    if (claimFailure case final failure?) throw failure;
    return claimedRobotId;
  }
}

class _FakeHouseholdManagementGateway implements HouseholdManagementGateway {
  _FakeHouseholdManagementGateway({this.removalResult, this.beforeLeaveReturn});

  final RobotInstallation? removalResult;
  final Future<void> Function()? beforeLeaveReturn;
  String? invitedRobotId;
  String? invitedEmail;
  String? removedRobotId;
  String? removedAccountId;
  String? leftRobotId;

  @override
  bool get isAvailable => true;

  @override
  Future<RobotInstallation> acceptInvitation(String code) =>
      throw UnimplementedError();

  @override
  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  ) async {
    invitedRobotId = robotId;
    invitedEmail = email;
    return HouseholdInvitationCredential(
      code: 'ABCD2345EFGH6789',
      expiresAt: DateTime.utc(2026, 7, 27, 12),
    );
  }

  @override
  Future<RobotInstallation> createRobot(String displayName) =>
      throw UnimplementedError();

  @override
  Future<void> leaveRobot(String robotId) async {
    leftRobotId = robotId;
    await beforeLeaveReturn?.call();
  }

  @override
  Future<RobotInstallation> removeMember(
    String robotId,
    String accountId,
  ) async {
    removedRobotId = robotId;
    removedAccountId = accountId;
    return removalResult ?? _robotInstallation;
  }
}

class _FakeBackupFileGateway implements BackupFileGateway {
  _FakeBackupFileGateway({this.picked});

  final Uint8List? picked;

  @override
  Future<bool> hasRecovery() async => false;

  @override
  Future<Uint8List?> pickImportBytes() async => picked;

  @override
  Future<Uint8List?> readRecovery() async => null;

  @override
  Future<BackupShareResult> shareExport({
    required Uint8List bytes,
    required String filename,
  }) async => BackupShareResult.completed;

  @override
  Future<void> writeRecovery(Uint8List bytes) async {}
}

class _FakePermissionGateway implements AppPermissionGateway {
  const _FakePermissionGateway();

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    return AppPermissionState.granted;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    return AppPermissionState.granted;
  }
}

class _NoopReminderScheduler implements ReminderScheduler {
  const _NoopReminderScheduler();

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

class _FakeVoicePlaybackGateway implements VoicePlaybackGateway {
  final List<DoseyVoicePhrase> playedPhrases = <DoseyVoicePhrase>[];
  double? lastVolume;

  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playing => const Stream<bool>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath, {required double volume}) async {
    playedPhrases.add(
      FixedPhraseCatalog.phrases
          .singleWhere((phrase) => phrase.assetPath == assetPath)
          .phrase,
    );
    lastVolume = volume;
  }

  @override
  Future<void> stop() async {}
}
