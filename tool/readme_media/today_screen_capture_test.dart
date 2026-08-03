import 'dart:io';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/app/dosey_material_app.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mobile_app/dosey_app/test/support/fake_app_scope_dependencies.dart';

final _captureDate = DateTime.utc(2040, 1, 2, 9);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFlutterFonts);

  test('Confirmed taken uses Roboto w800 metrics', () {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'Confirmed taken',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);

    expect(painter.width, greaterThan(70));
    expect(painter.width, lessThan(160));
  });

  for (final capture in <_CaptureViewport>[
    _CaptureViewport('today_android_phone.png', Size(412, 915)),
    _CaptureViewport('today_iphone.png', Size(375, 812)),
    _CaptureViewport('today_desktop_wide.png', Size(1366, 768)),
  ]) {
    testWidgets(
      'captures Today at ${capture.size.width}x${capture.size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.binding.setSurfaceSize(capture.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final database = DoseyDatabase.inMemory();
        final clock = ControllableAppClock(_captureDate);
        addTearDown(database.close);
        addTearDown(clock.close);
        await _seedToday(database);

        await tester.pumpWidget(
          DoseyAppScope(
            database: database,
            appClock: clock,
            bleGateway: FakeBleGateway(),
            connectivityGateway: FakeConnectivityGateway(),
            missedDoseReconciliationService:
                FakeMissedDoseReconciliationService(),
            child: DoseyMaterialApp(
              home: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Theme(
                    data: theme.copyWith(
                      appBarTheme: theme.appBarTheme.copyWith(
                        titleTextStyle: theme.appBarTheme.titleTextStyle
                            ?.copyWith(fontFamily: 'Roboto'),
                      ),
                      filledButtonTheme: FilledButtonThemeData(
                        style: theme.filledButtonTheme.style?.copyWith(
                          textStyle: WidgetStatePropertyAll(
                            theme.textTheme.labelLarge!.copyWith(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const DoseyShell(forceTodayTab: true),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Today'), findsWidgets);
        final appBarToday = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Today'),
        );
        expect(tester.getSize(appBarToday).width, lessThan(80));
        expect(find.text('Medications'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Next dose'), findsOneWidget);
        expect(find.text('Example Vitamin'), findsWidgets);
        final markTaken = find.text('Mark dose as taken');
        expect(markTaken, findsOneWidget);
        final markTakenStyle = DefaultTextStyle.of(
          tester.element(markTaken),
        ).style;
        expect(markTakenStyle.fontFamily, 'Roboto');
        expect(markTakenStyle.fontWeight, FontWeight.w800);
        expect(tester.getSize(markTaken).width, lessThan(180));
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .debugShowCheckedModeBanner,
          isFalse,
        );
        expect(
          Theme.of(tester.element(find.byType(DoseyShell))).useMaterial3,
          isTrue,
        );
        expect(
          Theme.of(tester.element(find.byType(DoseyShell))).colorScheme.primary,
          const Color(0xFF00A8E8),
        );
        expect(
          Theme.of(tester.element(find.byType(DoseyShell))).brightness,
          Brightness.dark,
        );
        expect(
          Theme.of(tester.element(find.byType(DoseyShell))).colorScheme.surface,
          const Color(0xFF101923),
        );
        expect(
          Theme.of(
            tester.element(find.byType(DoseyShell)),
          ).textTheme.bodyMedium?.fontFamily,
          'Roboto',
        );
        expect(tester.takeException(), isNull);

        await expectLater(
          find.byType(DoseyMaterialApp),
          matchesGoldenFile('../../media/readme/raw/${capture.filename}'),
        );
      },
    );
  }
}

Future<void> _loadFlutterFonts() async {
  final roboto = FontLoader('Roboto')
    ..addFont(_readFlutterFont('Roboto-Regular.ttf'))
    ..addFont(_readFlutterFont('Roboto-Medium.ttf'))
    ..addFont(_readFlutterFont('Roboto-Bold.ttf'))
    ..addFont(_readFlutterFont('Roboto-Black.ttf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(_readFlutterFont('MaterialIcons-Regular.otf'));
  await roboto.load();
  await materialIcons.load();
}

Future<ByteData> _readFlutterFont(String filename) async {
  final executable = File(Platform.resolvedExecutable);
  var directory = executable.parent;
  while (true) {
    for (final path in <String>[
      'artifacts/material_fonts/$filename',
      'bin/cache/artifacts/material_fonts/$filename',
      'engine/src/flutter/txt/third_party/fonts/$filename',
    ]) {
      final font = File('${directory.path}/$path');
      if (await font.exists()) {
        return _readFontFile(font);
      }
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Unable to locate Flutter SDK font: $filename');
    }
    directory = parent;
  }
}

Future<ByteData> _readFontFile(File font) async {
  if (!await font.exists()) {
    throw StateError('Unable to locate Flutter SDK font: ${font.path}');
  }
  return ByteData.sublistView(await font.readAsBytes());
}

Future<void> _seedToday(DoseyDatabase database) async {
  await LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  ).setThemePreference(AppThemePreference.dark);
  await LocalScheduleProfileRepository(database).upsertProfile(
    ScheduleProfile(
      id: ScheduleProfile.defaultProfileId,
      name: 'Home',
      isActive: true,
      createdAt: _captureDate,
      updatedAt: _captureDate,
    ),
  );
  await LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: 'example-vitamin',
      name: 'Example Vitamin',
      pillType: PillType.tablet,
      availableDoses: 28,
      createdAt: _captureDate,
      updatedAt: _captureDate,
    ),
  );
  for (final schedule in <ReminderSchedule>[
    ReminderSchedule(
      id: 'morning-example-vitamin',
      prescriptionId: 'example-vitamin',
      profileId: ScheduleProfile.defaultProfileId,
      label: 'Example Vitamin',
      hour: 9,
      minute: 0,
      isEnabled: true,
      createdAt: _captureDate,
      updatedAt: _captureDate,
    ),
    ReminderSchedule(
      id: 'evening-example-vitamin',
      prescriptionId: 'example-vitamin',
      profileId: ScheduleProfile.defaultProfileId,
      label: 'Example Vitamin evening dose',
      hour: 20,
      minute: 0,
      isEnabled: true,
      createdAt: _captureDate,
      updatedAt: _captureDate,
    ),
  ]) {
    await LocalReminderRepository(database).upsertSchedule(schedule);
  }
  await DriftDoseLogRepository(database).addEvent(
    DoseLogEvent.doseTakenConfirmed(
      doseId: 'morning-example-vitamin:2040-01-02',
      occurredAt: _captureDate,
    ),
  );
}

class _CaptureViewport {
  const _CaptureViewport(this.filename, this.size);

  final String filename;
  final Size size;
}
