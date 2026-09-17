import 'dart:async';
import 'dart:io';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('DoseyLocalRoboto')
      ..addFont(
        File(
          'tool/local_personal/assets/local_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
  });
  for (final layout in [
    (width: 320.0, scale: 1.0, stacked: true),
    (width: 800.0, scale: 1.0, stacked: false),
    (width: 320.0, scale: 2.0, stacked: true),
    (width: 800.0, scale: 2.0, stacked: false),
  ]) {
    testWidgets(
      'prescription hero at ${layout.width}px and ${layout.scale}x text keeps heading and action usable',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(layout.width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = DoseyDatabase.inMemory();
        addTearDown(db.close);
        final setup = PersonalSetupDependencies.local(db);
        await tester.pumpWidget(
          PersonalSetupScope(
            dependencies: setup,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'DoseyLocalRoboto'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(child: PrescriptionsScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final heading = find.text('Prescriptions');
        final action = find.widgetWithText(FilledButton, 'Add prescription');
        final headingRect = tester.getRect(heading);
        final actionRect = tester.getRect(action);
        // A narrow row previously left only a few letters per heading line.
        expect(
          headingRect.width,
          greaterThanOrEqualTo(layout.scale == 2 ? 200 : 120),
        );
        expect(headingRect.height, lessThanOrEqualTo(60 * layout.scale));
        expect(headingRect.overlaps(actionRect), isFalse);
        if (layout.stacked) {
          expect(actionRect.top, greaterThan(headingRect.bottom));
        } else {
          expect(actionRect.left, greaterThan(headingRect.right));
        }
        expect(actionRect.height, greaterThanOrEqualTo(48));
        expect(actionRect.left, greaterThanOrEqualTo(0));
        expect(actionRect.right, lessThanOrEqualTo(layout.width));
        expect(
          find.text('Enter what is on your prescription label.'),
          findsOneWidget,
        );
        expect(
          find.text('Dosey does not verify prescriptions or identify pills.'),
          findsOneWidget,
        );
        for (final label in [
          '0 entered',
          '0 scheduled',
          'Feeds schedule builder',
          'Local label reference',
        ]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(layout.width));
        }
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
        await tester.tap(action);
        await tester.pumpAndSettle();
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        final save = find.widgetWithText(FilledButton, 'Save prescription');
        expect(save, findsOneWidget);
        final cancelRect = tester.getRect(cancel);
        final saveRect = tester.getRect(save);
        expect(cancelRect.overlaps(saveRect), isFalse);
        for (final button in [cancel, save]) {
          final rect = tester.getRect(button);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(layout.width));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await setup.drain();
      },
    );
  }

  testWidgets(
    'shared local prescription form validates, retains failure input, blocks double save and retries same ID',
    (tester) async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final original = PersonalSetupDependencies.local(db);
      final repository = FailingPrescriptions(db);
      final setup = PersonalSetupDependencies(
        database: db,
        prescriptions: repository,
        reminders: original.reminders,
        scheduleProfiles: original.scheduleProfiles,
        reminderSchedules: original.reminderSchedules,
        runner: original.runner,
        sourceRole: original.sourceRole,
        localWeb: true,
      );
      await tester.pumpWidget(host(setup, const PrescriptionsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add prescription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save prescription'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a medication name.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medication name'),
        'Fictional blue',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Remaining doses'),
        '12',
      );
      await tester.tap(find.text('Save prescription'));
      await tester.pump();
      await tester.tap(find.text('Save prescription'), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repository.ids.length, 1);
      repository.pending.completeError(StateError('fictional write failure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('fictional write failure'), findsOneWidget);
      expect(find.text('Fictional blue'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Save prescription'));
      await tester.pumpAndSettle();
      expect(repository.ids, [repository.ids.first, repository.ids.first]);
      expect(
        (await repository.watchPrescriptions().first).single.remainingDoses,
        12,
      );
      expect(find.text('Save prescription'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await setup.drain();
    },
  );

  testWidgets(
    'shared local schedule form persists, rejects duplicate, edits, disables and deletes',
    (tester) async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final setup = PersonalSetupDependencies.local(db);
      final now = DateTime.utc(2026, 9, 15);
      await tester.runAsync(
        () => setup.prescriptions.upsertPrescription(
          Prescription(
            id: 'fictional',
            name: 'Fictional blue',
            pillType: PillType.pill,
            availableDoses: 8,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
      await tester.pumpWidget(host(setup, const RemindersScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '25');
      await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '0');
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Hour must be 0 through 23.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      // Register real database stream reads so the binding resumes fake-async
      // microtasks before the next guarded widget interaction.
      expect(
        await tester.runAsync(() => setup.reminders.watchSchedules().first),
        hasLength(1),
      );
      await tester.tap(find.text('Add schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Hour'), '8');
      await tester.enterText(find.widgetWithText(TextFormField, 'Minute'), '0');
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Save schedule'), findsOneWidget);
      expect(
        await tester.runAsync(() => setup.reminders.watchSchedules().first),
        hasLength(1),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit schedule'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minute'),
        '15',
      );
      await tester.tap(find.text('Save schedule'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => setup.reminders.watchSchedules().first,
        ))!.single.minute,
        15,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => setup.reminders.watchSchedules().first,
        ))!.single.isEnabled,
        false,
      );
      await tester.tap(find.byTooltip('Delete schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => setup.reminders.watchSchedules().first),
        isEmpty,
      );
      expect(
        (await tester.runAsync(
          () => setup.prescriptions.watchPrescriptions().first,
        ))!.single.remainingDoses,
        8,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await setup.drain();
    },
  );
}

Widget host(PersonalSetupDependencies dependencies, Widget child) =>
    PersonalSetupScope(
      dependencies: dependencies,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

class FailingPrescriptions extends LocalPrescriptionRepository {
  FailingPrescriptions(super.database);
  final pending = Completer<void>();
  final ids = <String>[];
  bool fail = true;
  @override
  Future<void> upsertPrescription(
    Prescription prescription, {
    AdminAuditEvent? auditEvent,
    Prescription? expectedState,
  }) async {
    ids.add(prescription.id);
    if (fail) await pending.future;
    await super.upsertPrescription(
      prescription,
      auditEvent: auditEvent,
      expectedState: expectedState,
    );
  }
}
