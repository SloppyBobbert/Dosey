import 'package:dosey_app/main.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
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
    expect(find.text('Controller'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Prototype safety'), findsOneWidget);
    expect(
      find.text('Use candy, beads, dry beans, vitamins, or fake pills.'),
      findsOneWidget,
    );
  });

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
    expect(find.text('Vitamin D'), findsOneWidget);
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
    expect(find.text('Skip dose'), findsOneWidget);
    expect(find.text('Mark missed'), findsOneWidget);
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
    await tester.tap(find.text('Confirm taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose taken confirmed'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
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
    await tester.tap(find.text('Skip dose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose skipped'), findsOneWidget);
    expect(find.text(_todayDoseId('vitamin-d')), findsOneWidget);
  });

  testWidgets('Today mark missed logs missed dose with safe guidance', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);
    await _addVitaminReminder(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
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

  testWidgets('Today manual confirmation still writes dose log entry', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm dose taken manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Dose taken confirmed'), findsOneWidget);
    expect(find.text('manual-confirmation'), findsOneWidget);
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

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byTooltip('Edit schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '9');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '15');
    await tester.tap(find.text('Save schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);

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
}) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: id,
      label: 'Vitamin D',
      prescriptionId: 'vitamin-d',
      profileId: profileId,
      hour: hour,
      minute: minute,
      isEnabled: true,
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

Future<void> _addVitaminPrescription(DoseyDatabase database) {
  return LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: 'vitamin-d',
      name: 'Vitamin D',
      pillType: PillType.capsule,
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
