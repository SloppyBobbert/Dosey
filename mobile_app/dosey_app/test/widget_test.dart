import 'package:dosey_app/main.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
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
    expect(find.text('Reminders'), findsOneWidget);
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
      find.text('Add your first reminder from the Reminders tab.'),
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

    expect(find.text('Next reminders'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Vitamin D'), findsOneWidget);
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
    await _markOnboardingComplete(database);

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

  testWidgets('reminders tab adds edits toggles and deletes reminders', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet.'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Label'),
      'Vitamin D',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '30');
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('08:30'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byTooltip('Edit reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Label'),
      'Morning vitamin',
    );
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Vitamin D'), findsNothing);
    expect(find.text('Morning vitamin'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Morning vitamin'), findsNothing);
    expect(find.text('No reminders yet.'), findsOneWidget);
  });

  testWidgets('reminder form validates required label and time range', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a reminder label.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Label'),
      'Vitamin D',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '24');
    await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '60');
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Hour must be 0 through 23.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Minute must be 0 through 59.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet.'), findsOneWidget);
  });

  testWidgets('reminder form is scrollable in the bottom sheet', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _markOnboardingComplete(database);

    await tester.pumpWidget(DoseyApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Label'), findsOneWidget);
    expect(find.text('Save reminder'), findsOneWidget);
  });
}

Future<void> _acceptMedicalNotice(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> _markOnboardingComplete(DoseyDatabase database) {
  return LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  ).setOnboardingCompleted(true);
}
