import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'actual root Navigator creates edits refills schedules and confirms dependent deletion',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = DoseyDatabase.inMemory();
      final owner = WebLocalPersonalStartup(
        bootstrap: () async => WebStorageReady(
          database: db,
          classification: classifyWebStorage(
            WebStorageImplementation.opfsShared,
          ),
          missingFeatures: const {},
        ),
      );
      final provider = PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          uri: Uri(path: '/prescriptions'),
        ),
      );
      addTearDown(
        () => tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox());
          await owner.shutdown();
          provider.dispose();
        }),
      );
      await tester.pumpWidget(
        WebLocalPersonalStartupApp(
          startup: owner,
          routeInformationProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue locally'));
      await tester.pumpAndSettle();
      final settings = LocalAppSettingsRepository(
        db,
        defaultRole: AppDeviceRole.webPersonal,
      );
      await tester.runAsync(() => settings.setActionPin('1234'));
      await tester.tap(find.text('Add prescription'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Fictional amber',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Remaining doses'),
        '8',
      );
      for (final pin in <String?>[null, '9999', '1234']) {
        await tester.tap(find.text('Save prescription'));
        await tester.pumpAndSettle();
        expect(find.text('Enter Action PIN'), findsOneWidget);
        if (pin == null) {
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Cancel'),
            ),
          );
        } else {
          await tester.enterText(
            find.byKey(const Key('action-pin-field')),
            pin,
          );
          await tester.tap(find.text('Continue'));
        }
        await tester.pumpAndSettle();
        if (pin != '1234') {
          expect(find.text('Fictional amber'), findsOneWidget);
          await tester.runAsync(() async {
            expect(await db.select(db.prescriptions).get(), isEmpty);
            expect(await db.select(db.adminAuditEvents).get(), isEmpty);
          });
        }
      }
      expect(find.text('Save prescription'), findsNothing);
      await tester.runAsync(() => settings.clearActionPin());
      await tester.tap(find.byTooltip('Edit prescription'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Fictional edited',
      );
      await tester.tap(find.text('Save prescription'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add refill doses'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Doses added'),
        '3',
      );
      await tester.tap(find.text('Save refill'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Schedule prescription'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minute'),
        '15',
      );
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          (await db.select(db.prescriptions).get()).single.remainingDoses,
          11,
        );
        expect(await db.select(db.prescriptionRefills).get(), hasLength(1));
        expect(await db.select(db.reminderSchedules).get(), hasLength(1));
        expect(await db.select(db.adminAuditEvents).get(), hasLength(4));
      });
      await tester.tap(find.byTooltip('Delete prescription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async =>
            expect(await db.select(db.prescriptions).get(), hasLength(1)),
      );
      await tester.tap(find.byTooltip('Delete prescription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await db.select(db.prescriptions).get(), isEmpty);
        expect(await db.select(db.prescriptionRefills).get(), isEmpty);
        expect(await db.select(db.reminderSchedules).get(), isEmpty);
        expect(await db.select(db.adminAuditEvents).get(), hasLength(5));
      });
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await owner.shutdown();
      });
    },
  );
}
