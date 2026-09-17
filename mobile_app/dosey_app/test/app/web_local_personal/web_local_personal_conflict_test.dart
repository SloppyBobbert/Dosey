import 'dart:io';

import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final refill in [false, true]) {
    testWidgets(
      'root editor requires review after second connection ${refill ? 'refill' : 'Taken'} and reopens exact inventory',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('dosey-editor-'),
        ))!;
        final file = File('${directory.path}/fictional.sqlite');
        final first = DoseyDatabase(NativeDatabase(file));
        final second = DoseyDatabase(NativeDatabase(file));
        final repository = LocalPrescriptionRepository(second);
        final now = DateTime.utc(2026, 9, 15);
        await tester.runAsync(() async {
          await LocalPrescriptionRepository(first).upsertPrescription(
            Prescription(
              id: 'fictional',
              name: 'Fictional blue',
              pillType: PillType.pill,
              availableDoses: 10,
              createdAt: now,
              updatedAt: now,
            ),
          );
          await second.customSelect('SELECT 1').get();
        });
        final owner = WebLocalPersonalStartup(
          bootstrap: () async => WebStorageReady(
            database: first,
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
            await second.close();
            provider.dispose();
            await directory.delete(recursive: true);
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
        await tester.tap(find.byTooltip('Edit prescription'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Medication name'),
          'Fictional edited',
        );
        await tester.runAsync(() async {
          if (refill) {
            await repository.addRefill(
              prescriptionId: 'fictional',
              doseCount: 2,
              occurredAt: now,
            );
          } else {
            await PhoneDoseActionService(second).record(
              PhoneDoseActionRequest(
                occurrence: ReminderOccurrence(
                  scheduleId: 'fictional-schedule',
                  scheduleRevision: 1,
                  scheduledAtUtc: now,
                  localDate: '2026-09-15',
                  timezoneId: 'UTC',
                  medicationId: 'fictional',
                  profileId: 'schedule-1',
                ),
                kind: PhoneDoseActionKind.takenConfirmed,
                deviceId: 'fictional-device',
                occurredAt: now,
              ),
            );
          }
        });
        await tester.tap(find.text('Save prescription'));
        await tester.pumpAndSettle();
        final count = refill ? 12 : 9;
        expect(find.text('Fictional edited'), findsOneWidget);
        expect(
          find.textContaining('Current inventory: $count remaining'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save prescription'),
              )
              .onPressed,
          isNull,
        );
        await tester.runAsync(() async {
          final saved = (await repository.watchPrescriptions().first).single;
          expect(saved.name, 'Fictional blue');
          expect(saved.remainingDoses, count);
          expect(await first.select(first.adminAuditEvents).get(), isEmpty);
          expect(
            await second.select(second.phoneDoseActionEvents).get(),
            hasLength(refill ? 0 : 1),
          );
          expect(
            await second.select(second.doseLogEvents).get(),
            hasLength(refill ? 0 : 1),
          );
        });
        await tester.tap(find.text('Use reviewed inventory'));
        await tester.pumpAndSettle();
        expect(find.text('Fictional edited'), findsOneWidget);
        await tester.tap(find.text('Save prescription'));
        await tester.pumpAndSettle();
        expect(find.text('Save prescription'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          expect(
            (await first.select(first.adminAuditEvents).get()),
            hasLength(1),
          );
          await tester.pumpWidget(const SizedBox());
          await owner.shutdown();
          final reopened = DoseyDatabase(NativeDatabase(file));
          try {
            final saved = (await LocalPrescriptionRepository(
              reopened,
            ).watchPrescriptions().first).single;
            expect(saved.name, 'Fictional edited');
            expect(saved.remainingDoses, count);
            expect(saved.availableDoses, count);
            // The phone-only service spends available/remaining, not Robot used buckets.
            expect(saved.usedDoses, 0);
            expect(
              await reopened.select(reopened.phoneDoseActionEvents).get(),
              hasLength(refill ? 0 : 1),
            );
            expect(
              await reopened.select(reopened.doseLogEvents).get(),
              hasLength(refill ? 0 : 1),
            );
            final history = await reopened
                .select(reopened.phoneDoseActionEvents)
                .get();
            final logs = await reopened.select(reopened.doseLogEvents).get();
            await LocalPrescriptionRepository(
              reopened,
            ).deletePrescription(saved.id);
            expect(
              await reopened.select(reopened.phoneDoseActionEvents).get(),
              history,
            );
            expect(await reopened.select(reopened.doseLogEvents).get(), logs);
          } finally {
            await reopened.close();
          }
        });
      },
    );
  }
}
