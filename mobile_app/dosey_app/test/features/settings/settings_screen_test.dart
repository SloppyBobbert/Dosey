import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings_repository.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('Robot Mode does not offer account sign-in', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
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

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('canceling leave Robot Mode keeps Robot Mode selected', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final settings = DoseyAppScope.of(
      tester.element(find.byType(MaterialApp)),
    ).settings;

    await _chooseDeviceRole(tester, AppDeviceRole.androidPersonal);
    expect(find.text('Leave Robot Mode?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await settings.getDeviceRole(), AppDeviceRole.androidRobot);
    expect(_selectedDeviceRole(tester), AppDeviceRole.androidRobot);
  });

  testWidgets('confirmed leave Robot Mode succeeds without configured PIN', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final settings = DoseyAppScope.of(
      tester.element(find.byType(MaterialApp)),
    ).settings;

    await _chooseDeviceRole(tester, AppDeviceRole.androidPersonal);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.getDeviceRole(), AppDeviceRole.androidPersonal);
  });

  testWidgets('entering Robot Mode does not show leave confirmation', (
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
    final settings = DoseyAppScope.of(
      tester.element(find.byType(MaterialApp)),
    ).settings;

    await _chooseDeviceRole(tester, AppDeviceRole.androidRobot);

    expect(find.text('Leave Robot Mode?'), findsNothing);
    expect(await settings.getDeviceRole(), AppDeviceRole.androidRobot);
  });

  testWidgets('canceling Action PIN keeps Robot Mode selected', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await settings.setActionPin('1234');

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    await _chooseDeviceRole(tester, AppDeviceRole.androidPersonal);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Action PIN'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await settings.getDeviceRole(), AppDeviceRole.androidRobot);
    expect(_selectedDeviceRole(tester), AppDeviceRole.androidRobot);
  });

  testWidgets('wrong Action PIN keeps Robot Mode selected', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await settings.setActionPin('1234');

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    await _chooseDeviceRole(tester, AppDeviceRole.androidPersonal);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '4321');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong PIN.'), findsOneWidget);
    expect(await settings.getDeviceRole(), AppDeviceRole.androidRobot);
    expect(_selectedDeviceRole(tester), AppDeviceRole.androidRobot);
  });

  testWidgets('correct Action PIN leaves Robot Mode', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setDeviceRole(AppDeviceRole.androidRobot);
    await settings.setActionPin('1234');

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    await _chooseDeviceRole(tester, AppDeviceRole.androidPersonal);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('action-pin-field')), '1234');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(await settings.getDeviceRole(), AppDeviceRole.androidPersonal);
  });

  testWidgets('robot-capable role shows robot face settings controls', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();
    final scope = tester.element(find.byType(MaterialApp));
    await DoseyAppScope.of(
      scope,
    ).settings.setDeviceRole(AppDeviceRole.androidRobot);
    await tester.pumpAndSettle();

    await _scrollToRobotFace(tester);

    expect(find.text('Robot Face'), findsOneWidget);
    expect(find.text('Flip face 180°'), findsOneWidget);
    expect(find.text('For upside-down mounts.'), findsOneWidget);
    expect(find.text('Dim after inactivity'), findsOneWidget);
    expect(find.text('Return to Robot Face'), findsOneWidget);
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
    expect(find.text('Flip face 180°'), findsNothing);
    expect(find.text('Dim after inactivity'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Household & robot profile'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Household & robot profile').hitTestable(),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Admin history'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin history').hitTestable(), findsOneWidget);
    expect(find.text('No local admin changes recorded yet.'), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final children =
        (listView.childrenDelegate as SliverChildListDelegate).children;
    final childTypes = children
        .map((child) => child.runtimeType.toString())
        .toList();
    final actionPinIndex = childTypes.indexOf('_ActionPinCard');
    final householdIndex = childTypes.indexOf('_HouseholdAccountCard');
    final adminHistoryIndex = childTypes.indexOf('_AdminHistoryCard');
    final robotFaceIndex = childTypes.indexOf('_RobotFaceSettingsSection');
    final reminderIndex = childTypes.indexOf('_ReminderNotificationCard');

    expect(actionPinIndex, isNonNegative);
    expect(householdIndex, greaterThan(actionPinIndex));
    expect(adminHistoryIndex, greaterThan(householdIndex));
    expect(robotFaceIndex, greaterThan(adminHistoryIndex));
    expect(reminderIndex, greaterThan(robotFaceIndex));

    expect(children[householdIndex - 1], isA<SizedBox>());
    expect((children[householdIndex - 1] as SizedBox).height, 12);
    expect(children[adminHistoryIndex - 1], isA<SizedBox>());
    expect((children[adminHistoryIndex - 1] as SizedBox).height, 12);
  });

  testWidgets('robot face controls persist and update state', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestSettingsApp(database: database));
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

    await tester.pumpWidget(_TestSettingsApp(database: database));
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

    await tester.pumpWidget(_TestSettingsApp(database: database));
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
    expect(find.text('Action PIN'), findsOneWidget);
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

    await tester.pumpWidget(_TestSettingsApp(database: database));
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

      await tester.pumpWidget(_TestSettingsApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Robot Face'), findsNothing);
      expect(find.text('Flip face 180°'), findsNothing);
      expect(find.text('Dim after inactivity'), findsNothing);
      expect(find.text('Wake before dose'), findsNothing);
      expect(find.text('Stay awake after dose'), findsNothing);
      expect(find.text('iOS can only be a personal phone.'), findsOneWidget);
      expect(find.textContaining('iOS personal phone'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'section targets scroll to Household & robot profile and Admin history',
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
        findsOneWidget,
      );
      expect(
        find.text('Edit household & robot profile').hitTestable(),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _TestSettingsApp(
          database: database,
          sectionTarget: SettingsSection.adminHistory,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin history').hitTestable(), findsOneWidget);
      expect(
        find.text('No local admin changes recorded yet.').hitTestable(),
        findsOneWidget,
      );
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

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Household & robot profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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
    expect(_findRichTextContaining('Cloud sync: Local only'), findsOneWidget);
  });

  testWidgets('household edit sheet shows optional metadata fields', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_TestSettingsApp(database: database));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Household & robot profile'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
  );
}

Future<void> _chooseDeviceRole(WidgetTester tester, AppDeviceRole role) async {
  final dropdown = tester.widget<DropdownButton<AppDeviceRole>>(
    find.byType(DropdownButton<AppDeviceRole>),
  );
  dropdown.onChanged?.call(role);
  await tester.pumpAndSettle();
}

AppDeviceRole? _selectedDeviceRole(WidgetTester tester) {
  return tester
      .widget<DropdownButton<AppDeviceRole>>(
        find.byType(DropdownButton<AppDeviceRole>),
      )
      .value;
}

Future<void> _scrollToRobotFace(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Robot Face'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToActionPin(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Action PIN'),
    300,
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
  });

  final DoseyDatabase database;
  final DoseyVoicePlayer? voicePlayer;
  final DoseyVoicePlayer? previewVoicePlayer;
  final SettingsSection? sectionTarget;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: FakeBleGateway(),
      connectivityGateway: FakeConnectivityGateway(),
      permissionGateway: const _FakePermissionGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      voicePlayer: voicePlayer,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F5E)),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: SettingsScreen(
            sectionTarget: sectionTarget,
            previewVoicePlayer: previewVoicePlayer,
          ),
        ),
      ),
    );
  }
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
}
