import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Robot Mode shows the Robot Face tab', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsOneWidget);
    expect(find.byType(RobotFaceScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isFalse,
    );
  });

  testWidgets('Personal Mode does not show the Robot Face tab', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidPersonal);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Robot Face'), findsNothing);
    expect(find.byType(RobotFaceScreen), findsNothing);
  });

  testWidgets('Robot Face stays mounted and becomes inactive offscreen', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robot Face'));
    await tester.pump();

    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isTrue,
    );
    expect(find.text('Robot Face'), findsNWidgets(2));

    await tester.tap(find.text('Controller'));
    await tester.pump();

    expect(find.byType(RobotFaceScreen, skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<RobotFaceScreen>(
            find.byType(RobotFaceScreen, skipOffstage: false),
          )
          .isActive,
      isFalse,
    );
    expect(find.text('Controller'), findsWidgets);
  });

  testWidgets('selected index stays safe when role changes', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final shellContext = tester.element(find.byType(DoseyShell));
    await DoseyAppScope.of(
      shellContext,
    ).settings.setDeviceRole(AppDeviceRole.androidPersonal);
    await tester.pumpAndSettle();

    expect(find.byType(DoseyShell), findsOneWidget);
    expect(find.text('Robot Face'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings gear menu lists settings sections and opens safety', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    await _openSettingsMenu(tester);

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Device mode'), findsWidgets);
    expect(find.text('Robot Face'), findsWidgets);
    expect(find.text('Reminder notifications'), findsWidgets);
    expect(find.text('Prototype safety'), findsWidgets);
    expect(find.text('Help & About'), findsWidgets);
    expect(find.text('Start over setup'), findsWidgets);
    expect(find.text('All settings'), findsOneWidget);

    await tester.tap(find.text('Prototype safety').hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(find.text('Prototype safety').hitTestable(), findsOneWidget);
    expect(
      find.text('I understand prototype safety rules').hitTestable(),
      findsOneWidget,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Account').hitTestable(), findsWidgets);

    await _openSettingsMenu(tester);
    await tester.tap(find.text('Prototype safety').hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.text('I understand prototype safety rules').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('settings gear menu opens Help and About', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _setDeviceRole(database, AppDeviceRole.androidRobot);

    await tester.pumpWidget(_TestShellApp(database: database));
    await tester.pumpAndSettle();

    await _openSettingsMenu(tester);

    expect(find.text('Help & About'), findsOneWidget);

    await tester.tap(find.text('Help & About').hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(find.text('Help & About').hitTestable(), findsOneWidget);
    expect(find.text('Dosey 1.0.0+1').hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(
        SelectableText,
        'https://github.com/SloppyBobbert/Dosey',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This prototype is not a medical-grade device. Test only with fake pills, candy, beads, dry beans, or vitamins.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _setDeviceRole(DoseyDatabase database, AppDeviceRole role) async {
  final settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  await settings.setDeviceRole(role);
}

Future<void> _openSettingsMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open settings menu'));
  await tester.pumpAndSettle();
}

class _TestShellApp extends StatelessWidget {
  const _TestShellApp({required this.database});

  final DoseyDatabase database;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      reminderScheduler: const _NoopReminderScheduler(),
      child: const MaterialApp(home: DoseyShell()),
    );
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
