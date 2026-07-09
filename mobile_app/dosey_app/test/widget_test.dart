import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/main.dart' as app;
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/onboarding/onboarding_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first install shows medical-device onboarding before shell', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Dosey is not a medical device'), findsOneWidget);
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('medical-device onboarding requires acknowledgement', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final enabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('onboarding shows an error when setup state cannot load', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingGate(
          onboardingCompletedStream: Stream<bool>.error(
            StateError('settings failed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Setup could not load'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('safety notice stays put when acknowledgement cannot save', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await database.close();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Dosey is not a medical device'), findsOneWidget);
    expect(find.text('Setup could not be saved. Try again.'), findsOneWidget);
    expect(find.text('How will you use this phone?'), findsNothing);
  });

  testWidgets('Android Robot Mode completes onboarding without login', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await _acceptMedicalNotice(tester);
    await tester.tap(find.text('Robot Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Dosey'), findsOneWidget);
    expect(find.text('Controller'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
  });

  testWidgets('Android Personal Mode shows Google sign-in gate', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await _acceptMedicalNotice(tester);
    await tester.tap(find.text('Personal Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      find.text('Personal Mode requires Google sign-in for now.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('rapid role taps keep first onboarding role selection', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await _acceptMedicalNotice(tester);
    await tester.tap(find.text('Personal Mode'));
    await tester.tap(find.text('Robot Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('onboarding sign-in failure stays on account gate', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await _acceptMedicalNotice(tester);
    await tester.tap(find.text('Personal Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      find.text('Google sign-in failed. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Controller'), findsNothing);
    final signInButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue with Google'),
    );
    expect(signInButton.onPressed, isNotNull);
  });

  testWidgets('iOS onboarding never offers Robot Mode', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    try {
      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();

      await _acceptMedicalNotice(tester);

      expect(find.text('Robot Mode'), findsNothing);
      expect(find.text('Personal Mode'), findsOneWidget);

      await tester.tap(find.text('Personal Mode'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('settings can start onboarding over', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start over setup'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over setup'));
    await tester.pumpAndSettle();

    expect(find.text('Dosey is not a medical device'), findsOneWidget);
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('settings shows signed-out profile and grouped safety sections', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Local prototype'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Cloud sync is not active yet.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Device mode'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Device mode'), findsOneWidget);
    expect(find.text('Android robot phone'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Prototype safety'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text(
        'Servo movement and reminders do not prove a dose was taken. Confirm doses manually after checking the cup.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings shows signed-in profile identity', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    await _saveSignedInUser(database, provider: AuthProvider.google);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Dosey Tester'), findsOneWidget);
    expect(find.text('google@example.com'), findsOneWidget);
    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('Android personal phone'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('settings shows reminder notification permission status', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.granted},
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Reminder notifications'), findsOneWidget);
    expect(find.text('Notifications allowed'), findsOneWidget);
    expect(
      find.text(
        'Dose reminders are scheduled locally on this phone. If notifications are blocked, Dosey can still show schedules in the app but system alerts may not appear.',
      ),
      findsOneWidget,
    );
    expect(
      permissions.checkedPermissions,
      contains(AppPermission.notifications),
    );
  });

  testWidgets('settings refreshes notification status after app resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final notificationStatus = {
      AppPermission.notifications: AppPermissionState.granted,
    };
    final permissions = _FakePermissionGateway(
      checkResponses: notificationStatus,
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Notifications allowed'), findsOneWidget);

    notificationStatus[AppPermission.notifications] = AppPermissionState.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Notifications blocked'), findsOneWidget);
  });

  testWidgets('settings can request reminder notification permission', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.denied},
      requestResponses: {
        AppPermission.notifications: AppPermissionState.granted,
      },
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Notifications blocked'), findsOneWidget);

    await tester.tap(find.text('Check permissions'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications allowed'), findsOneWidget);
    expect(permissions.requestedPermissions, [AppPermission.notifications]);
  });

  testWidgets('settings handles notification permission check failure', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final permissions = _FakePermissionGateway(
      checkError: StateError('permission bridge unavailable'),
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Notification status unknown'), findsOneWidget);
    expect(
      find.textContaining('Notification permission check failed'),
      findsOneWidget,
    );
  });

  testWidgets('settings can schedule a test reminder notification', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final scheduler = _RecordingReminderScheduler();
    final permissions = _FakePermissionGateway(
      requestResponses: {
        AppPermission.notifications: AppPermissionState.granted,
      },
    );

    await tester.pumpWidget(
      DoseyApp(
        database: database,
        permissionGateway: permissions,
        reminderScheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();

    expect(find.text('Test notification scheduled.'), findsOneWidget);
    expect(permissions.requestedPermissions, [AppPermission.notifications]);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduledReminders.single.doseId, 'dosey-test-reminder');
    expect(scheduler.scheduledReminders.single.label, 'Dosey test reminder');
    expect(scheduler.scheduledReminders.single.repeatsDaily, isFalse);
  });

  testWidgets('settings does not report test notification success when blocked', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final scheduler = _RecordingReminderScheduler();
    final permissions = _FakePermissionGateway(
      requestResponses: {
        AppPermission.notifications: AppPermissionState.denied,
      },
    );

    await tester.pumpWidget(
      DoseyApp(
        database: database,
        permissionGateway: permissions,
        reminderScheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Notifications are still blocked. Allow notifications before using the test alert.',
      ),
      findsOneWidget,
    );
    expect(find.text('Test notification scheduled.'), findsNothing);
    expect(scheduler.scheduledReminders, isEmpty);
  });

  testWidgets('settings reports test notification scheduler failures', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final scheduler = _RecordingReminderScheduler()
      ..scheduleError = Exception('notifications unavailable');
    final permissions = _FakePermissionGateway(
      requestResponses: {
        AppPermission.notifications: AppPermissionState.granted,
      },
    );

    await tester.pumpWidget(
      DoseyApp(
        database: database,
        permissionGateway: permissions,
        reminderScheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reminder notifications'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send test notification'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test notification failed:'), findsOneWidget);
    expect(find.text('Test notification scheduled.'), findsNothing);
    expect(scheduler.scheduledReminders, isEmpty);
  });

  testWidgets('settings menu opens the full settings screen', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open settings menu'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Device mode'), findsWidgets);
    expect(find.text('Reminder notifications'), findsWidgets);
    expect(find.text('Start over setup'), findsOneWidget);

    await tester.tap(find.text('All settings'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Cloud sync is not active yet.'), findsOneWidget);
  });

  testWidgets('settings menu opens account section and signs out', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    await _saveSignedInUser(database, provider: AuthProvider.google);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open settings menu'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Account').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Dosey Tester'), findsOneWidget);
    expect(find.text('google@example.com'), findsOneWidget);
    expect(find.text('Google account'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('app bar title follows the selected tab', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Today')),
      findsOneWidget,
    );

    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Prescriptions'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
  });

  testWidgets('shows local-first app tabs and safety guidance', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Dosey'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Carousel'), findsOneWidget);
    expect(find.text('Controller'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text('Use candy, beads, dry beans, vitamins, or fake pills.'),
      findsOneWidget,
    );
  });

  testWidgets('Carousel screen shows loading safety empty state', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    expect(find.text('Daviky loading'), findsOneWidget);
    expect(find.text('0 loaded / 0 assigned'), findsOneWidget);
    expect(
      find.text(
        'Use candy, beads, dry beans, vitamins, or fake pills for prototype testing. Do not use real prescription medication in early tests.',
      ),
      findsOneWidget,
    );
    expect(find.text('No active schedules to load.'), findsOneWidget);
  });

  testWidgets('Carousel screen assigns and loads an active schedule', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Slot number'),
      '1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Assign next dose'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Assign next dose'));
    await tester.pumpAndSettle();

    expect(find.text('Slot 1'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('0 loaded / 1 assigned'), -220);
    await tester.pumpAndSettle();
    expect(find.text('0 loaded / 1 assigned'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mark loaded'), 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark loaded'));
    await tester.pumpAndSettle();

    expect(find.text('Loaded'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 loaded / 1 assigned'), -220);
    await tester.pumpAndSettle();
    expect(find.text('1 loaded / 1 assigned'), findsOneWidget);
  });

  testWidgets('Carousel tab shows loading bay summary', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    expect(find.text('Loading bay'), findsOneWidget);
    expect(find.text('Daviky carousel'), findsOneWidget);
    expect(find.text('1 assigned'), findsOneWidget);
    expect(find.text('1 loaded'), findsOneWidget);
    expect(find.text('1 ready to dispense'), findsOneWidget);
    expect(find.text('Feeds dispense flow'), findsOneWidget);
    expect(find.text('Prototype loading'), findsOneWidget);
  });

  testWidgets('Carousel tab shows local refill countdown', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'allergy-noon',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await _addLoadedVitaminSlot(database);
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'schedule-1-allergy-noon',
        slotNumber: 2,
        prescriptionId: 'allergy-pill',
        scheduleId: 'allergy-noon',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.dispensed,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Refill countdown'), 220);
    await tester.pumpAndSettle();

    expect(find.text('Refill countdown'), findsOneWidget);
    expect(find.text('1 dose remaining'), findsOneWidget);
    expect(find.text('Refill soon'), findsOneWidget);
    expect(find.text('1 slot dispensed'), findsOneWidget);
    expect(find.text('Review dispensed slots'), findsOneWidget);

    await tester.tap(find.text('Review dispensed slots'));
    await tester.pumpAndSettle();

    expect(find.text('1 needs review'), findsOneWidget);
    expect(
      find.text('Dispensed slots marked for refill review.'),
      findsOneWidget,
    );
    final slots = await database.select(database.carouselSlots).get();
    final reviewedSlot = slots.singleWhere(
      (slot) => slot.id == 'schedule-1-allergy-noon',
    );
    expect(reviewedSlot.status, CarouselSlotStatus.needsReview.storageValue);
  });

  testWidgets('Carousel can review and reload a dispensed slot', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'schedule-1-vitamin-d-morning',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.dispensed,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review refill'), 220);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review refill'));
    await tester.pumpAndSettle();
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Mark loaded'), findsOneWidget);

    await tester.tap(find.text('Mark loaded'));
    await tester.pumpAndSettle();

    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.loaded.storageValue);
  });

  testWidgets('Carousel skips disabled schedules when assigning slots', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(
      database,
      id: 'disabled-vitamin-d',
      isEnabled: false,
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'allergy-noon',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    expect(find.text('12:00 · Allergy pill'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsNothing);
  });

  testWidgets('Carousel hides loaded slots for disabled schedules', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'disabled-vitamin-d');
    await LocalCarouselSlotRepository(database).assignSlot(
      CarouselSlot(
        id: 'schedule-1-disabled-vitamin-d',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'disabled-vitamin-d',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await _addVitaminReminder(
      database,
      id: 'disabled-vitamin-d',
      isEnabled: false,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    expect(find.text('Slot 1'), findsNothing);
    expect(find.text('Dispense slot'), findsNothing);
    expect(find.text('0 loaded / 0 assigned'), findsOneWidget);
  });

  test('Carousel reuses slot numbers after a schedule is disabled', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final reminders = LocalReminderRepository(database);
    final carouselSlots = LocalCarouselSlotRepository(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await reminders.upsertSchedule(
      ReminderSchedule(
        id: 'allergy-noon',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await carouselSlots.assignSlot(
      CarouselSlot(
        id: 'schedule-1-vitamin-d-morning',
        slotNumber: 1,
        prescriptionId: 'vitamin-d',
        scheduleId: 'vitamin-d-morning',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.loaded,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await reminders.upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d-morning',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await carouselSlots.assignSlot(
      CarouselSlot(
        id: 'schedule-1-allergy-noon',
        slotNumber: 1,
        prescriptionId: 'allergy-pill',
        scheduleId: 'allergy-noon',
        profileId: ReminderSchedule.defaultProfileId,
        status: CarouselSlotStatus.assigned,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    final slots = await database.select(database.carouselSlots).get();
    expect(slots, hasLength(1));
    expect(slots.single.scheduleId, 'allergy-noon');
  });

  testWidgets('Today dispenses a loaded slot without marking the dose taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('Dispense from slot 1'), findsOneWidget);
    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    await tester.ensureVisible(find.text('Dispense from slot 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Dispense from slot 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Dispense moved'), findsOneWidget);
    expect(find.text('Dose visible'), findsOneWidget);
    expect(find.text('Confirm taken'), findsOneWidget);
    var events = await database.select(database.doseLogEvents).get();
    expect(
      events.single.kind,
      DoseLogEventKind.controllerDispenseSucceeded.name,
    );
    expect(events.single.marksDoseTaken, isFalse);
    var slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.dispensed.storageValue);

    await tester.pump(const Duration(seconds: 4));

    await tester.ensureVisible(find.text('Dose visible'));
    await tester.tap(find.text('Dose visible'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    events = await database.select(database.doseLogEvents).get();
    expect(
      events.map((event) => event.kind),
      contains(DoseLogEventKind.doseVisibleConfirmed.name),
    );
    expect(
      events
          .singleWhere(
            (event) => event.kind == DoseLogEventKind.doseVisibleConfirmed.name,
          )
          .marksDoseTaken,
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.widgetWithText(FilledButton, 'Dose visible'), findsNothing);
    expect(find.text('Current dose'), findsOneWidget);
  });

  testWidgets('Today does not log movement when slot update fails', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    await (database.delete(
      database.carouselSlots,
    )..where((row) => row.id.equals('schedule-1-vitamin-d-morning'))).go();

    await _runAsyncCallback(dispenseButton.onPressed!);

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  testWidgets('Today keeps slot loaded when controller rejects dispense', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    await DoseyAppScope.of(
      tester.element(find.byType(OnboardingGate)),
    ).controller.disconnect();

    await _runAsyncCallback(dispenseButton.onPressed!);

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.loaded.storageValue);
  });

  testWidgets('Today ignores dose actions while dispense is pending', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm taken'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    expect(confirmButton.onPressed, isNotNull);

    final pendingDispense = (dispenseButton.onPressed as dynamic)();
    final pendingConfirm = (confirmButton.onPressed as dynamic)();

    if (pendingDispense is Future<void>) {
      await pendingDispense;
    }
    if (pendingConfirm is Future<void>) {
      await pendingConfirm;
    }
    await tester.pumpAndSettle();

    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.where(
        (event) => event.kind == DoseLogEventKind.doseTakenConfirmed.name,
      ),
      isEmpty,
    );
    expect(
      events.where(
        (event) =>
            event.kind == DoseLogEventKind.controllerDispenseSucceeded.name,
      ),
      hasLength(1),
    );
  });

  testWidgets('Today ignores stale duplicate dispense callbacks', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNotNull);

    await _runAsyncCallback(dispenseButton.onPressed!);
    await _runAsyncCallback(dispenseButton.onPressed!);

    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.where(
        (event) =>
            event.kind == DoseLogEventKind.controllerDispenseSucceeded.name,
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'Today ignores duplicate rapid confirm taken callbacks and spends inventory once',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await _addVitaminPrescription(database, remainingDoses: 2);
      await _addVitaminReminder(database, id: 'vitamin-d-morning');

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm taken'),
      );
      expect(confirmButton.onPressed, isNotNull);

      await _runAsyncCallback(confirmButton.onPressed!);
      await _runAsyncCallback(confirmButton.onPressed!);
      await tester.pumpAndSettle();

      final events = await database.select(database.doseLogEvents).get();
      expect(
        events.where(
          (event) => event.kind == DoseLogEventKind.doseTakenConfirmed.name,
        ),
        hasLength(1),
      );

      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('vitamin-d'))).getSingle();
      expect(prescription.remainingDoses, 1);
    },
  );

  testWidgets('Today ignores a second terminal action after confirm taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm taken'),
    );
    final alreadyTakenButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Already taken'),
    );
    expect(confirmButton.onPressed, isNotNull);
    expect(alreadyTakenButton.onPressed, isNotNull);

    await _runAsyncCallback(confirmButton.onPressed!);
    await _runAsyncCallback(alreadyTakenButton.onPressed!);
    await tester.pumpAndSettle();

    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.where(
        (event) =>
            event.doseId == _todayDoseId('vitamin-d-morning') &&
            (event.kind == DoseLogEventKind.doseTakenConfirmed.name ||
                event.kind == DoseLogEventKind.doseAlreadyTaken.name),
      ),
      hasLength(1),
    );
    expect(events.single.kind, DoseLogEventKind.doseTakenConfirmed.name);
  });

  testWidgets('Today ignores a stale non-terminal action after confirm taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm taken'),
    );
    final snoozeButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Log snooze'),
    );
    expect(confirmButton.onPressed, isNotNull);
    expect(snoozeButton.onPressed, isNotNull);

    await _runAsyncCallback(confirmButton.onPressed!);
    await _runAsyncCallback(snoozeButton.onPressed!);
    await tester.pumpAndSettle();

    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.where(
        (event) => event.doseId == _todayDoseId('vitamin-d-morning'),
      ),
      hasLength(1),
    );
    expect(events.single.kind, DoseLogEventKind.doseTakenConfirmed.name);
  });

  testWidgets('Today keeps Dose visible after later non-terminal notes', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dispense from slot 1'));
    await tester.tap(find.widgetWithText(FilledButton, 'Dispense from slot 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.widgetWithText(FilledButton, 'Dose visible'), findsOneWidget);

    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseSnoozed(
        doseId: _todayDoseId('vitamin-d-morning'),
        occurredAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.widgetWithText(FilledButton, 'Dose visible'), findsOneWidget);
  });

  testWidgets(
    'Today dose visible does not decrement linked prescription inventory',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await _addVitaminPrescription(database, remainingDoses: 2);
      await _addVitaminReminder(database, id: 'vitamin-d-morning');
      await _addLoadedVitaminSlot(database);

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect simulator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Dispense from slot 1'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Dispense from slot 1'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 4));

      await tester.ensureVisible(find.text('Dose visible'));
      await tester.tap(find.text('Dose visible'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('vitamin-d'))).getSingle();
      expect(prescription.remainingDoses, 2);
    },
  );

  testWidgets('Today confirm taken retires loaded carousel slot', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Confirm taken'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm taken'));
    await tester.pumpAndSettle();

    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.needsReview.storageValue);

    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Slot 1'), 420);
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Dispense slot'), findsNothing);
  });

  testWidgets('Today keeps slot loaded when terminal dose log fails', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);
    await database.customStatement('''
      CREATE TRIGGER fail_confirm_taken_log
      BEFORE INSERT ON dose_log_events
      WHEN NEW.kind = 'doseTakenConfirmed'
      BEGIN
        SELECT RAISE(ABORT, 'forced dose log failure');
      END;
    ''');

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Confirm taken'));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm taken'));
    await tester.pumpAndSettle();

    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.loaded.storageValue);
    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  testWidgets('Today skip dose retires loaded carousel slot', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Skip dose'));
    await tester.tap(find.text('Skip dose'));
    await tester.pumpAndSettle();

    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.needsReview.storageValue);
  });

  testWidgets('Today disables loaded-slot dispense while offline', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dispense from slot 1'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNull);
  });

  testWidgets('Today disables connected dispense outside Robot Mode', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    await _saveSignedInUser(database, provider: AuthProvider.google);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dispense from slot 1'));
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense from slot 1'),
    );
    expect(dispenseButton.onPressed, isNull);
  });

  testWidgets('Carousel dispenses loaded slots through the controller', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
    await tester.pumpAndSettle();

    expect(find.text('Loaded'), findsOneWidget);
    expect(find.text('Dispense slot'), findsOneWidget);
    await tester.tap(find.text('Dispense slot'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Dispensed'), findsOneWidget);
    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.single.kind,
      DoseLogEventKind.controllerDispenseSucceeded.name,
    );
    expect(events.single.marksDoseTaken, isFalse);
    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.dispensed.storageValue);
  });

  testWidgets('Carousel does not log movement when slot update fails', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispense slot'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    await (database.delete(
      database.carouselSlots,
    )..where((row) => row.id.equals('schedule-1-vitamin-d-morning'))).go();

    await _runAsyncCallback(dispenseButton.onPressed!);

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  testWidgets('Carousel keeps slot loaded when controller rejects dispense', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispense slot'),
    );
    expect(dispenseButton.onPressed, isNotNull);
    await DoseyAppScope.of(
      tester.element(find.byType(OnboardingGate)),
    ).controller.disconnect();

    await _runAsyncCallback(dispenseButton.onPressed!);

    expect(await database.select(database.doseLogEvents).get(), isEmpty);
    final slot =
        await (database.select(database.carouselSlots)
              ..where((row) => row.id.equals('schedule-1-vitamin-d-morning')))
            .getSingle();
    expect(slot.status, CarouselSlotStatus.loaded.storageValue);
  });

  testWidgets('Carousel disables slot dispense while offline', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispense slot'),
    );
    expect(dispenseButton.onPressed, isNull);
  });

  testWidgets('Carousel disables connected dispense outside Robot Mode', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );
    await _saveSignedInUser(database, provider: AuthProvider.google);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect simulator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
    await tester.pumpAndSettle();

    final dispenseButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Dispense slot'),
    );
    expect(dispenseButton.onPressed, isNull);
  });

  testWidgets(
    'Carousel ignores duplicate dispense taps while a slot is moving',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await _addVitaminPrescription(database);
      await _addVitaminReminder(database, id: 'vitamin-d-morning');
      await _addLoadedVitaminSlot(database);

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Controller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect simulator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carousel'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Dispense slot'), 420);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dispense slot'));
      await tester.tap(find.text('Dispense slot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final events = await database.select(database.doseLogEvents).get();
      expect(
        events
            .where(
              (event) =>
                  event.kind ==
                  DoseLogEventKind.controllerDispenseSucceeded.name,
            )
            .length,
        1,
      );
    },
  );

  testWidgets('completed onboarding does not flash onboarding while loading', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Dosey is not a medical device'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('Dosey is ready for your day'), findsOneWidget);
  });

  testWidgets('Today screen shows polished empty reminder landing', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Dosey is ready for your day'), findsOneWidget);
    expect(find.text('Local-only'), findsOneWidget);
    expect(find.text('Prototype-safe'), findsOneWidget);
    expect(find.text('Manual confirmation'), findsOneWidget);
    expect(find.text('No reminders scheduled for today.'), findsOneWidget);
    expect(
      find.text('Add your first schedule from the Schedule tab.'),
      findsOneWidget,
    );
  });

  testWidgets('Today screen previews upcoming reminders', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d',
        label: 'Vitamin D',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Scheduled reminders'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Vitamin D'), findsWidgets);
  });

  testWidgets('Today dashboard highlights the next dose hero', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await _addLoadedVitaminSlot(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Next dose'), findsOneWidget);
    expect(find.text('Vitamin D'), findsWidgets);
    expect(find.text('08:30'), findsWidgets);
    expect(find.text('Capsule'), findsWidgets);
    expect(find.text('Loaded slot 1'), findsOneWidget);
    expect(find.text('Controller offline'), findsOneWidget);
    expect(find.text('Active schedule'), findsOneWidget);
  });

  testWidgets('Today dashboard shows the next schedule timeline', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'allergy-pill',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Next schedule timeline'), 220);
    await tester.pumpAndSettle();

    expect(find.text('Next schedule timeline'), findsOneWidget);
    expect(find.text('Now watching'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Later today'), findsOneWidget);
    expect(find.text('08:30'), findsWidgets);
    expect(find.text('Vitamin D'), findsWidgets);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Allergy pill'), findsWidgets);
  });

  testWidgets('Today timeline advances past terminal dose events', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database, id: 'vitamin-d-morning');
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'allergy-pill',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseSkipped(
        doseId: _todayDoseId('vitamin-d-morning'),
        occurredAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Next schedule timeline'), 220);
    await tester.pumpAndSettle();

    expect(find.text('Now watching'), findsWidgets);
    expect(find.text('12:00'), findsWidgets);
    expect(find.text('Allergy pill'), findsWidgets);
    expect(find.text('08:30'), findsNothing);
  });

  testWidgets('Today screen only shows reminders from the active schedule', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);
    await _addTravelProfile(database);
    await _addVitaminReminder(
      database,
      id: 'travel-vitamin-d',
      profileId: 'travel',
      hour: 10,
      minute: 0,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('10:00 · Vitamin D'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsNothing);
  });

  testWidgets('Today screen shows linked prescription pill type', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d-morning',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Current dose'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsOneWidget);
    expect(find.text('Capsule'), findsWidgets);
  });

  testWidgets('Today screen uses linked prescription name for current dose', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await LocalPrescriptionRepository(database).upsertPrescription(
      Prescription(
        id: 'vitamin-d',
        name: 'Vitamin D3',
        pillType: PillType.capsule,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'vitamin-d-morning',
        label: 'Vitamin D',
        prescriptionId: 'vitamin-d',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Current dose'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D3'), findsOneWidget);
  });

  testWidgets('Today advances after the earlier dose is skipped', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database);
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'allergy-pill',
        label: 'Allergy pill',
        prescriptionId: 'allergy-pill',
        hour: 12,
        minute: 0,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await DriftDoseLogRepository(database).addEvent(
      DoseLogEvent.doseSkipped(
        doseId: _todayDoseId('vitamin-d'),
        occurredAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Current dose'), findsOneWidget);
    expect(find.text('12:00 · Allergy pill'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsNothing);
  });

  testWidgets('Today screen shows current dose actions from reminders', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Current dose'), findsOneWidget);
    expect(find.text('08:30 · Vitamin D'), findsOneWidget);
    expect(find.text('Confirm taken'), findsOneWidget);
    expect(find.text('Log snooze'), findsOneWidget);
    expect(find.text('Already taken'), findsOneWidget);
    expect(find.text('Taken early'), findsOneWidget);
    expect(find.text('Taken late'), findsOneWidget);
    expect(find.text('Ask caregiver'), findsOneWidget);
    expect(find.text('Skip dose'), findsOneWidget);
    expect(find.text('Mark missed'), findsOneWidget);
  });

  testWidgets('Today snooze logs reminder delay without marking taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log snooze'));
    await tester.tap(find.text('Log snooze'));
    await tester.pumpAndSettle();

    expect(
      find.text('Snooze logged locally; reminder timing is unchanged.'),
      findsOneWidget,
    );
    expect(find.text('Snoozed logged'), findsOneWidget);
    expect(find.text('Current dose'), findsOneWidget);

    final events = await database.select(database.doseLogEvents).get();
    expect(events.single.kind, DoseLogEventKind.doseSnoozed.name);
    expect(events.single.marksDoseTaken, isFalse);
  });

  testWidgets('Today confirm taken logs current dose as taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm taken'));
    await tester.tap(find.text('Confirm taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose taken confirmed'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
  });

  testWidgets('Today confirm taken decrements linked prescription inventory', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm taken'));
    await tester.tap(find.text('Confirm taken'));
    await tester.pumpAndSettle();

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  testWidgets('Today already taken logs manual taken without dispensing', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Already taken'));
    await tester.tap(find.text('Already taken'));
    await tester.pumpAndSettle();

    expect(find.text('Already-taken dose logged.'), findsOneWidget);
    expect(find.text('Current dose'), findsNothing);

    final events = await database.select(database.doseLogEvents).get();
    expect(events.single.kind, DoseLogEventKind.doseAlreadyTaken.name);
    expect(events.single.marksDoseTaken, isTrue);
  });

  testWidgets('Today already taken decrements linked prescription inventory', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Already taken'));
    await tester.tap(find.text('Already taken'));
    await tester.pumpAndSettle();

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  testWidgets('Today taken early logs manual early dose as taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Taken early'));
    await tester.tap(find.text('Taken early'));
    await tester.pumpAndSettle();

    expect(find.text('Early dose logged.'), findsOneWidget);
    expect(find.text('Current dose'), findsNothing);

    final events = await database.select(database.doseLogEvents).get();
    expect(events.single.kind, DoseLogEventKind.doseTakenEarly.name);
    expect(events.single.marksDoseTaken, isTrue);
  });

  testWidgets('Today taken early decrements linked prescription inventory', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Taken early'));
    await tester.tap(find.text('Taken early'));
    await tester.pumpAndSettle();

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  testWidgets('Today taken late logs manual late dose as taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Taken late'));
    await tester.tap(find.text('Taken late'));
    await tester.pumpAndSettle();

    expect(find.text('Late dose logged.'), findsOneWidget);
    expect(find.text('Current dose'), findsNothing);

    final events = await database.select(database.doseLogEvents).get();
    expect(events.single.kind, DoseLogEventKind.doseTakenLate.name);
    expect(events.single.marksDoseTaken, isTrue);
  });

  testWidgets('Today taken late decrements linked prescription inventory', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Taken late'));
    await tester.tap(find.text('Taken late'));
    await tester.pumpAndSettle();

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  testWidgets('Today ask caregiver logs non-terminal help request', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ask caregiver'));
    await tester.tap(find.text('Ask caregiver'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Caregiver request noted locally. Contact your caregiver, pharmacist, or doctor if you are unsure what to do.',
      ),
      findsOneWidget,
    );
    expect(find.text('Caregiver asked'), findsWidgets);
    expect(find.text('Current dose'), findsOneWidget);

    final events = await database.select(database.doseLogEvents).get();
    expect(events.single.kind, DoseLogEventKind.caregiverHelpRequested.name);
    expect(events.single.marksDoseTaken, isFalse);
  });

  testWidgets('Today skip dose logs skipped without marking taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip dose'));
    await tester.tap(find.text('Skip dose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose skipped'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
  });

  testWidgets(
    'Today skip dose does not decrement linked prescription inventory',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await _addVitaminPrescription(database, remainingDoses: 2);
      await _addVitaminReminder(database);

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Skip dose'));
      await tester.tap(find.text('Skip dose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();

      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('vitamin-d'))).getSingle();
      expect(prescription.remainingDoses, 2);
    },
  );

  testWidgets('Today mark missed logs missed dose with safe guidance', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mark missed'));
    await tester.tap(find.text('Mark missed'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose missed'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
  });

  testWidgets('Today missed does not decrement linked prescription inventory', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mark missed'));
    await tester.tap(find.text('Mark missed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 2);
  });

  testWidgets('signed-out Personal Mode returns to account gate', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(
      database,
      role: AppDeviceRole.androidPersonal,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Controller'), findsNothing);
  });

  testWidgets('Today hero hides manual confirmation without current dose', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Confirm dose taken manually'), findsNothing);
    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  testWidgets('Today hero manual confirmation confirms the current dose', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm dose taken manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose taken confirmed'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
    expect(find.text('manual-confirmation'), findsNothing);
  });

  testWidgets('Today hero ignores duplicate rapid manual confirm callbacks', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database, remainingDoses: 2);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();

    final heroButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm dose taken manually'),
    );
    expect(heroButton.onPressed, isNotNull);

    await _runAsyncCallback(heroButton.onPressed!);
    await _runAsyncCallback(heroButton.onPressed!);
    await tester.pumpAndSettle();

    final events = await database.select(database.doseLogEvents).get();
    expect(
      events.where(
        (event) => event.kind == DoseLogEventKind.doseTakenConfirmed.name,
      ),
      hasLength(1),
    );

    final prescription = await (database.select(
      database.prescriptions,
    )..where((row) => row.id.equals('vitamin-d'))).getSingle();
    expect(prescription.remainingDoses, 1);
  });

  testWidgets('Log tab shows local audit summary', (WidgetTester tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    final doseLog = DriftDoseLogRepository(database);
    await doseLog.addEvent(
      DoseLogEvent.controllerDispenseSucceeded(
        doseId: 'vitamin-d:2026-01-01',
        occurredAt: DateTime.utc(2026, 1, 1, 8, 30),
      ),
    );
    await doseLog.addEvent(
      DoseLogEvent.doseTakenConfirmed(
        doseId: 'vitamin-d:2026-01-01',
        occurredAt: DateTime.utc(2026, 1, 1, 8, 32),
      ),
    );
    await doseLog.addEvent(
      DoseLogEvent.doseSkipped(
        doseId: 'allergy-pill:2026-01-01',
        occurredAt: DateTime.utc(2026, 1, 1, 12),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose history'), findsOneWidget);
    expect(find.text('3 local events'), findsOneWidget);
    expect(find.text('1 confirmed taken'), findsOneWidget);
    expect(find.text('2 movement or review'), findsOneWidget);
    expect(find.text('Manual confirmation only'), findsOneWidget);
    expect(find.text('Local audit trail'), findsOneWidget);
  });

  testWidgets('prescriptions tab adds edits and deletes prescriptions', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    expect(find.text('No prescriptions yet.'), findsOneWidget);
    expect(find.text('Add your first prescription.'), findsOneWidget);
    expect(
      find.text('Enter what is on your prescription label.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add prescription'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medication name'),
      'Vitamin D',
    );
    await tester.tap(find.text('Capsule'));
    await tester.tap(find.text('Save prescription'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Capsule'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit prescription'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medication name'),
      'Vitamin D3',
    );
    await tester.tap(find.text('Tablet'));
    await tester.tap(find.text('Save prescription'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsNothing);
    expect(find.text('Vitamin D3'), findsOneWidget);
    expect(find.text('Tablet'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete prescription'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D3'), findsNothing);
    expect(find.text('No prescriptions yet.'), findsOneWidget);
  });

  testWidgets('prescriptions tab saves and refills dose counts', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add prescription'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Medication name'),
      'Vitamin D',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Remaining doses'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Low warning at'),
      '5',
    );
    await tester.tap(find.text('Save prescription'));
    await tester.pumpAndSettle();

    expect(find.text('2 doses left'), findsOneWidget);
    expect(find.text('Refill soon'), findsOneWidget);

    await tester.tap(find.byTooltip('Add refill doses'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Doses added'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note'),
      'new bottle',
    );
    await tester.tap(find.text('Save refill'));
    await tester.pumpAndSettle();

    expect(find.text('32 doses left'), findsOneWidget);
    expect(find.text('Warn at 5'), findsOneWidget);
    final refillEvents = await database
        .select(database.prescriptionRefills)
        .get();
    expect(refillEvents.single.doseDelta, 30);
    expect(refillEvents.single.remainingAfter, 32);
    expect(refillEvents.single.note, 'new bottle');
  });

  testWidgets(
    'prescription edit does not silently save cleared inventory fields',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await _addVitaminPrescription(
        database,
        remainingDoses: 7,
        refillThreshold: 4,
      );

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prescriptions'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit prescription'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Remaining doses'),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low warning at'),
        '',
      );
      await tester.tap(find.text('Save prescription'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter zero or more doses for both refill tracking fields.'),
        findsOneWidget,
      );
      expect(find.text('Edit prescription'), findsOneWidget);

      final prescription = await (database.select(
        database.prescriptions,
      )..where((row) => row.id.equals('vitamin-d'))).getSingle();
      expect(prescription.remainingDoses, 7);
      expect(prescription.refillThreshold, 4);
    },
  );

  testWidgets('prescriptions tab shows medication cabinet summary', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    expect(find.text('Medication cabinet'), findsOneWidget);
    expect(find.text('2 entered'), findsOneWidget);
    expect(find.text('1 scheduled'), findsOneWidget);
    expect(find.text('Feeds schedule builder'), findsOneWidget);
    expect(find.text('Local label reference'), findsOneWidget);
    expect(
      find.text('Dosey does not verify prescriptions or identify pills.'),
      findsOneWidget,
    );
  });

  testWidgets('prescription card can start a schedule for that medication', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Schedule prescription'));
    await tester.pumpAndSettle();

    expect(find.text('Add schedule'), findsWidgets);
    expect(find.text('Which prescription?'), findsOneWidget);
    expect(find.text('Vitamin D'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Capsule'), findsOneWidget);
  });

  testWidgets('prescription cards summarize schedule coverage', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addAllergyPrescription(database);
    await _addVitaminReminder(database);
    await _addTravelProfile(database, setActive: false);
    await _addVitaminReminder(
      database,
      id: 'travel-vitamin-d',
      profileId: 'travel',
      hour: 20,
      minute: 0,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Active: 08:30'), findsOneWidget);
    expect(find.text('Used in 2 schedules'), findsOneWidget);
    expect(find.text('Allergy pill'), findsOneWidget);
    expect(find.text('No schedules yet'), findsOneWidget);
  });

  testWidgets('prescription cards show schedule profile details', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);
    await _addTravelProfile(database, setActive: false);
    await _addVitaminReminder(
      database,
      id: 'travel-vitamin-d',
      profileId: 'travel',
      hour: 20,
      minute: 0,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('View schedule details'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D schedules'), findsOneWidget);
    expect(find.text('Schedule 1'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(
      find.text('Only the active schedule is used by Today.'),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('Schedule tab asks for prescriptions before schedules', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a prescription before creating a schedule.'),
      findsOneWidget,
    );
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add schedule'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets(
    'Schedule tab shows legacy schedules before prescriptions exist',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _markOnboardingComplete(database);
      await LocalReminderRepository(database).upsertSchedule(
        ReminderSchedule(
          id: 'legacy-reminder',
          label: 'Legacy reminder',
          prescriptionId: 'missing-prescription',
          hour: 8,
          minute: 30,
          isEnabled: true,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Legacy reminder'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);
      expect(find.byTooltip('Edit schedule'), findsOneWidget);
      expect(find.byTooltip('Delete schedule'), findsOneWidget);
    },
  );

  testWidgets('Schedule tab creates schedules from prescriptions', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('No schedules yet.'), findsOneWidget);
    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Which prescription?'), findsOneWidget);
    expect(find.text('Vitamin D'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Capsule'), findsOneWidget);
  });

  testWidgets('Schedule tab saves when notification scheduling fails', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final scheduler = _RecordingReminderScheduler()
      ..scheduleError = Exception('notifications unavailable');

    await tester.pumpWidget(
      DoseyApp(database: database, reminderScheduler: scheduler),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsWidgets);
    expect(find.text('08:30'), findsOneWidget);
    expect(
      find.textContaining('Schedule saved, but notification'),
      findsOneWidget,
    );
  });

  testWidgets('Schedule tab warns when notification alerts are blocked', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.denied},
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts are blocked'), findsOneWidget);
    expect(
      find.text(
        'Schedules still save locally, but this phone may not show reminder alerts until notifications are allowed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Check notification permission'), findsOneWidget);
    expect(
      permissions.checkedPermissions,
      contains(AppPermission.notifications),
    );
  });

  testWidgets('Schedule tab handles notification permission check failure', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final permissions = _FakePermissionGateway(
      checkError: StateError('permission bridge unavailable'),
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alert status unknown'), findsOneWidget);
    expect(
      find.textContaining('Notification permission check failed'),
      findsOneWidget,
    );
  });

  testWidgets('Schedule tab can request blocked notification permission', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.denied},
      requestResponses: {
        AppPermission.notifications: AppPermissionState.granted,
      },
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts are blocked'), findsOneWidget);

    await tester.tap(find.text('Check notification permission'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts are blocked'), findsNothing);
    expect(permissions.requestedPermissions, [AppPermission.notifications]);
  });

  testWidgets('Schedule tab shows when notification alerts are allowed', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.granted},
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts look ready'), findsOneWidget);
    expect(
      find.text('Dosey can show local reminder alerts on this phone.'),
      findsOneWidget,
    );
    expect(find.text('Check notification permission'), findsNothing);
  });

  testWidgets('Schedule tab refreshes notification status after app resume', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final notificationStatus = {
      AppPermission.notifications: AppPermissionState.granted,
    };
    final permissions = _FakePermissionGateway(
      checkResponses: notificationStatus,
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts look ready'), findsOneWidget);
    expect(find.text('Check notification permission'), findsNothing);

    notificationStatus[AppPermission.notifications] = AppPermissionState.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts are blocked'), findsOneWidget);
    expect(find.text('Check notification permission'), findsOneWidget);
  });

  testWidgets('Schedule tab can refresh unknown notification status', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    final permissions = _FakePermissionGateway(
      checkResponses: {AppPermission.notifications: AppPermissionState.unknown},
      requestResponses: {
        AppPermission.notifications: AppPermissionState.granted,
      },
    );

    await tester.pumpWidget(
      DoseyApp(database: database, permissionGateway: permissions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alert status unknown'), findsOneWidget);

    await tester.tap(find.text('Check notification permission'));
    await tester.pumpAndSettle();

    expect(find.text('Notification alerts look ready'), findsOneWidget);
    expect(permissions.requestedPermissions, [AppPermission.notifications]);
  });

  testWidgets('notification tap opens Today without marking dose taken', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);
    final notificationTaps = ReminderNotificationTapController();
    addTearDown(notificationTaps.dispose);

    await tester.pumpWidget(
      DoseyApp(database: database, notificationTapController: notificationTaps),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    notificationTaps.handleTap('vitamin-d:2026-06-30');
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(await database.select(database.doseLogEvents).get(), isEmpty);
  });

  testWidgets('Schedule tab shows active routine summary for the timeline', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Routine builder'), findsOneWidget);
    expect(find.text('Active routine'), findsOneWidget);
    expect(find.text('Schedule 1'), findsWidgets);
    expect(find.text('1 enabled / 1 scheduled'), findsOneWidget);
    expect(find.text('Feeds Today timeline'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Vitamin D'), 220);
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
  });

  testWidgets('Schedule tab switches between saved schedule profiles', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Active schedule'), findsOneWidget);
    expect(find.text('Schedule 1'), findsWidgets);
    expect(find.text('Vitamin D'), findsOneWidget);

    await tester.tap(find.text('Add schedule profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Schedule name'),
      'Travel',
    );
    await tester.tap(find.text('Save schedule profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use Travel schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Active schedule'), findsOneWidget);
    expect(find.text('Travel'), findsWidgets);
    expect(find.text('No schedules yet.'), findsOneWidget);
    expect(find.text('Vitamin D'), findsNothing);
  });

  testWidgets('Schedule tab shows counts and renames schedule profiles', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await _addVitaminReminder(database);
    await _addTravelProfile(database, setActive: false);
    await _addVitaminReminder(
      database,
      id: 'travel-vitamin-d',
      profileId: 'travel',
      hour: 10,
      minute: 0,
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule 1 · 1 schedule'), findsOneWidget);
    expect(find.text('Travel · 1 schedule'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Travel schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Schedule name'),
      'Vacation',
    );
    await tester.tap(find.text('Save schedule profile'));
    await tester.pumpAndSettle();

    expect(find.text('Travel'), findsNothing);
    expect(find.text('Vacation'), findsWidgets);
    expect(find.text('Vacation · 1 schedule'), findsOneWidget);
    expect(find.byTooltip('Use Vacation schedule'), findsOneWidget);
  });

  testWidgets('Schedule tab blocks duplicate prescription times', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(
      find.text('A schedule already exists for this prescription at 08:30.'),
      findsOneWidget,
    );
  });

  testWidgets('controller tab keeps manual dispense disabled by default', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();

    expect(find.text('Controller disconnected'), findsOneWidget);
    expect(find.text('Manual dispense test'), findsOneWidget);
    expect(
      find.text(
        'Locked until Android robot mode and a controller connection are active.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Never mark a dose taken because the servo moved.'),
      findsOneWidget,
    );
    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Dispense disabled'),
    );
    expect(disabledButton.onPressed, isNull);
  });

  testWidgets('controller tab shows hardware bench summary', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controller'));
    await tester.pumpAndSettle();

    expect(find.text('Hardware bench'), findsOneWidget);
    expect(find.text('XIAO ESP32-C6'), findsOneWidget);
    expect(find.text('Robot phone'), findsOneWidget);
    expect(find.text('Controller offline'), findsOneWidget);
    expect(find.text('Manual safety lock'), findsOneWidget);
    expect(find.text('BLE protocol pending'), findsOneWidget);
    expect(find.text('Simulator bridge'), findsOneWidget);
  });

  testWidgets('settings only offers iOS personal role on iOS', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.iosPersonal);
    await _saveSignedInUser(database, provider: AuthProvider.apple);

    try {
      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('iOS personal phone'), findsOneWidget);
      expect(find.text('Android robot phone'), findsNothing);
      expect(find.text('Android personal phone'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS sign-out returns to Apple account gate', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database, role: AppDeviceRole.iosPersonal);
    await _saveSignedInUser(database, provider: AuthProvider.apple);

    try {
      await tester.pumpWidget(DoseyApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Schedule tab adds edits toggles and deletes schedules', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('No schedules yet.'), findsOneWidget);
    expect(find.text('Add schedule'), findsOneWidget);

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Capsule'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.ensureVisible(find.byTooltip('Edit schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '9');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '15');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Delete schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsNothing);
    expect(find.text('No schedules yet.'), findsOneWidget);
  });

  testWidgets('editing orphan schedule requires a prescription choice', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);
    await LocalReminderRepository(database).upsertSchedule(
      ReminderSchedule(
        id: 'legacy-reminder',
        label: 'Legacy reminder',
        prescriptionId: 'missing-prescription',
        hour: 8,
        minute: 30,
        isEnabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Legacy reminder'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a prescription.'), findsOneWidget);
  });

  testWidgets('schedule form validates time range', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Hour must be 0 through 23.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '24');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '60');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Hour must be 0 through 23.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Minute must be 0 through 59.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('No schedules yet.'), findsOneWidget);
  });

  testWidgets('schedule form is scrollable in the bottom sheet', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminPrescription(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Which prescription?'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Hour'), findsOneWidget);
    expect(find.text('Save schedule'), findsOneWidget);
  });
}

Future<void> _acceptMedicalNotice(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> _markOnboardingComplete(
  DoseyDatabase database, {
  AppDeviceRole role = AppDeviceRole.androidRobot,
}) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
  await settings.setOnboardingCompleted(true);
}

Future<void> _saveSignedInUser(
  DoseyDatabase database, {
  required AuthProvider provider,
}) {
  return LocalAuthRepository(database).saveUser(
    AuthUser(
      id: provider.name,
      email: '${provider.name}@example.com',
      displayName: 'Dosey Tester',
      photoUrl: null,
      provider: provider,
    ),
  );
}

Future<void> _addVitaminReminder(
  DoseyDatabase database, {
  String id = 'vitamin-d',
  String profileId = ReminderSchedule.defaultProfileId,
  int hour = 8,
  int minute = 30,
  bool isEnabled = true,
}) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: 'Vitamin D',
      prescriptionId: 'vitamin-d',
      profileId: profileId,
      hour: hour,
      minute: minute,
      isEnabled: isEnabled,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

Future<void> _addLoadedVitaminSlot(DoseyDatabase database) {
  return LocalCarouselSlotRepository(database).assignSlot(
    CarouselSlot(
      id: 'schedule-1-vitamin-d-morning',
      slotNumber: 1,
      prescriptionId: 'vitamin-d',
      scheduleId: 'vitamin-d-morning',
      profileId: ReminderSchedule.defaultProfileId,
      status: CarouselSlotStatus.loaded,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

Future<void> _addTravelProfile(
  DoseyDatabase database, {
  bool setActive = true,
}) async {
  final repository = LocalScheduleProfileRepository(database);
  await repository.upsertProfile(
    ScheduleProfile(
      id: 'travel',
      name: 'Travel',
      isActive: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
  if (setActive) {
    await repository.setActiveProfile('travel');
  }
}

Future<void> _addVitaminPrescription(
  DoseyDatabase database, {
  int remainingDoses = 0,
  int refillThreshold = 3,
}) {
  return LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: 'vitamin-d',
      name: 'Vitamin D',
      pillType: PillType.capsule,
      remainingDoses: remainingDoses,
      refillThreshold: refillThreshold,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

Future<void> _addAllergyPrescription(DoseyDatabase database) {
  return LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: 'allergy-pill',
      name: 'Allergy pill',
      pillType: PillType.tablet,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

String _todayDoseId(String scheduleId) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '$scheduleId:${now.year}-$month-$day';
}

Future<void> _runAsyncCallback(VoidCallback callback) async {
  final result = (callback as dynamic)();
  if (result is Future<void>) {
    await result;
  }
}

class DoseyApp extends StatelessWidget {
  const DoseyApp({
    super.key,
    this.database,
    this.permissionGateway,
    this.reminderScheduler,
    this.notificationTapController,
  });

  final DoseyDatabase? database;
  final AppPermissionGateway? permissionGateway;
  final ReminderScheduler? reminderScheduler;
  final ReminderNotificationTapController? notificationTapController;

  @override
  Widget build(BuildContext context) {
    return app.DoseyApp(
      database: database,
      reminderScheduler: reminderScheduler ?? const _NoopReminderScheduler(),
      permissionGateway: permissionGateway,
      notificationTapController: notificationTapController,
    );
  }
}

class _FakePermissionGateway implements AppPermissionGateway {
  _FakePermissionGateway({
    this.checkResponses = const {},
    this.requestResponses = const {},
    this.checkError,
  });

  final Map<AppPermission, AppPermissionState> checkResponses;
  final Map<AppPermission, AppPermissionState> requestResponses;
  final Object? checkError;
  final checkedPermissions = <AppPermission>[];
  final requestedPermissions = <AppPermission>[];

  @override
  Future<AppPermissionState> check(AppPermission permission) async {
    checkedPermissions.add(permission);
    final error = checkError;
    if (error != null) throw error;
    return checkResponses[permission] ?? AppPermissionState.unknown;
  }

  @override
  Future<AppPermissionState> request(AppPermission permission) async {
    requestedPermissions.add(permission);
    return requestResponses[permission] ?? AppPermissionState.denied;
  }
}

class _NoopReminderScheduler implements ReminderScheduler {
  const _NoopReminderScheduler();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {}

  @override
  Future<void> cancelDoseReminder(String doseId) async {}
}

class _RecordingReminderScheduler implements ReminderScheduler {
  int permissionRequests = 0;
  final scheduledReminders = <_ScheduledReminder>[];
  final cancelledDoseIds = <String>[];
  Object? scheduleError;
  Object? cancelError;

  @override
  Future<void> requestPermission() async {
    permissionRequests += 1;
  }

  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {
    final error = scheduleError;
    if (error != null) throw error;
    scheduledReminders.add(
      _ScheduledReminder(
        doseId: doseId,
        scheduledFor: scheduledFor,
        label: label,
        repeatsDaily: repeatsDaily,
      ),
    );
  }

  @override
  Future<void> cancelDoseReminder(String doseId) async {
    final error = cancelError;
    if (error != null) throw error;
    cancelledDoseIds.add(doseId);
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({
    required this.doseId,
    required this.scheduledFor,
    required this.label,
    required this.repeatsDaily,
  });

  final String doseId;
  final DateTime scheduledFor;
  final String label;
  final bool repeatsDaily;
}
