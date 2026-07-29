import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:drift/drift.dart';
import 'package:dosey_app/core/bluetooth/ble_gateway.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/connectivity/connectivity_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'guided refill entry shows both top-off and full reload options',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);

      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Start refill/loading'), findsOneWidget);

      await tester.tap(find.text('Start refill/loading'));
      await tester.pumpAndSettle();

      expect(find.text('Top off empty slots'), findsOneWidget);
      expect(find.text('Empty and reload all'), findsOneWidget);
    },
  );

  testWidgets('full reload keeps reload confirmation gated until unload is saved', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 6);
    await _seedReminder(database);
    await _seedEveningReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-gated-reload',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _plan(now),
      startedAt: now,
      confirmedAt: now,
    );

    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start refill/loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty and reload all'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Full Reload requires a separate persisted physical unload transaction first. The new load cannot be confirmed until this unload step is saved.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Reload confirmation stays locked until the physical unload transaction is saved.',
      ),
      findsOneWidget,
    );
    expect(find.text('2. Confirm the new load'), findsNothing);
    expect(find.text('Confirm empty and reload all'), findsNothing);
  });

  testWidgets('stale active loads block top-off before the flow can proceed', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 6);
    await _seedReminder(database);
    await _seedEveningReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-stale',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _plan(now),
      startedAt: now,
      confirmedAt: now,
    );
    await (database.update(
      database.carouselLoadSessions,
    )..where((row) => row.id.equals('session-stale'))).write(
      CarouselLoadSessionsCompanion(
        status: const Value('stale'),
        staleAt: Value(now.add(const Duration(minutes: 1))),
        updatedAt: Value(now.add(const Duration(minutes: 1))),
      ),
    );

    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The saved load changed and now needs review before any top-off. Use Full Reload after you review the carousel.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Start refill/loading'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This saved load needs review or Full Reload before top-off can continue.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Top off empty slots'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a refill path'), findsOneWidget);
    expect(find.text('Top off empty slots'), findsOneWidget);
  });

  testWidgets(
    'top-off shows a stronger saved-position checkpoint before confirm',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-top-off',
        profileId: ReminderSchedule.defaultProfileId,
        plan: _plan(now),
        startedAt: now,
        confirmedAt: now,
      );
      await (database.update(database.carouselStates)..where(
            (row) => row.profileId.equals(ReminderSchedule.defaultProfileId),
          ))
          .write(CarouselStatesCompanion(currentPosition: const Value(5)));

      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start refill/loading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top off empty slots'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Start from START/home. Tap only the compartments this top-off will fill now. Then return the carousel to slot 5 before you confirm.',
        ),
        findsOneWidget,
      );
      expect(find.text('Return checkpoint'), findsOneWidget);
      expect(find.text('Current saved position slot 5'), findsOneWidget);
      expect(find.text('Return to preserved position slot 5'), findsOneWidget);
      expect(
        find.text(
          'Before you tap confirm, manually return the carousel to slot 5.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CheckboxListTile), findsNothing);

      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Return to slot 5 and confirm top-off',
        ),
      );
      expect(confirmButton.onPressed, equals(null));

      for (var slot = 2; slot <= 6; slot += 1) {
        await _tapCarouselSlot(tester, slot);
        await tester.pump();
      }

      final enabledConfirmButton = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Return to slot 5 and confirm top-off',
        ),
      );
      expect(enabledConfirmButton.onPressed, isNot(equals(null)));

      await _tapCarouselSlot(tester, 2);
      await tester.pump();

      final disabledConfirmButton = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Return to slot 5 and confirm top-off',
        ),
      );
      expect(disabledConfirmButton.onPressed, equals(null));
    },
  );

  testWidgets(
    'real persisted shortage sessions stay visible and route to full reload',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-1',
        profileId: ReminderSchedule.defaultProfileId,
        plan: _shortagePlan(now),
        startedAt: now,
        confirmedAt: now,
      );
      final alertRow = await (database.select(
        database.medicationShortageAlerts,
      )..where((row) => row.id.equals('shortage:session-1:2'))).getSingle();

      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();

      final scheduledLabel = _localTimeLabel(DateTime.utc(2026, 7, 23, 10));
      final medicationLabel =
          (jsonDecode(alertRow.prescriptionNamesJson) as List<dynamic>).first
              as String;

      expect(find.text('Urgent shortage'), findsOneWidget);
      expect(find.text(medicationLabel), findsOneWidget);
      expect(find.text('Scheduled $scheduledLabel'), findsOneWidget);
      expect(find.text('Slot 2'), findsOneWidget);
      expect(
        find.text(
          'Local-only alert on this phone. Dosey is not sending remote shortage updates yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'This shortage stays pinned in Robot Face until loading is handled here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resolve and continue loading'), findsNothing);
      expect(find.text('Use Full Reload instead'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );

  testWidgets('continuation top-off only targets the subset this plan can fill now', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 2);
    await _seedReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-partial-continuation',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _plan(now),
      startedAt: now,
      confirmedAt: now,
    );
    await database
        .into(database.medicationShortageAlerts)
        .insert(
          MedicationShortageAlertsCompanion.insert(
            id: 'shortage:session-partial-continuation:2',
            profileId: ReminderSchedule.defaultProfileId,
            loadSessionId: const Value('session-partial-continuation'),
            slotNumber: 2,
            bundleKey: 'bundle-partial',
            scheduledAt: DateTime.now().toUtc().add(const Duration(days: 1)),
            prescriptionIdsJson: '["vitamin-d"]',
            prescriptionNamesJson: '["Vitamin D"]',
            status: 'active',
            localDeliveryState: 'sent',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Resolve and continue loading'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Resolve and continue loading'),
      220,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve and continue loading'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This shortage can continue with a partial top-off. Start from START/home, fill only the compartments planned for this pass, then return to START/home before you confirm.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stops again at slot 3'), findsOneWidget);
    expect(find.text('11 later slots stay empty'), findsOneWidget);
    expect(
      find.text(
        'Selected 0 of 1 compartments planned for this pass. Later empty slots are not part of this continuation.',
      ),
      findsOneWidget,
    );

    final confirmBeforeSelection = tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        'Return to START/home and confirm top-off',
      ),
    );
    expect(confirmBeforeSelection.onPressed, equals(null));

    await _tapCarouselSlot(tester, 3);
    await tester.pump();

    expect(
      find.text(
        'Selected 0 of 1 compartments planned for this pass. Later empty slots are not part of this continuation.',
      ),
      findsOneWidget,
    );

    await _tapCarouselSlot(tester, 2);
    await tester.pump();

    expect(
      find.text(
        'Selected 1 of 1 compartments planned for this pass. Later empty slots are not part of this continuation.',
      ),
      findsOneWidget,
    );

    final confirmAfterSelection = tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        'Return to START/home and confirm top-off',
      ),
    );
    expect(confirmAfterSelection.onPressed, isNot(equals(null)));
  });

  testWidgets('past-due unresolved shortages stay visible on Carousel', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 6);
    await _seedReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);

    await repository.confirmFullLoad(
      sessionId: 'session-past-due',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _shortagePlan(now),
      startedAt: now,
      confirmedAt: now,
    );
    await (database.update(
      database.medicationShortageAlerts,
    )..where((row) => row.loadSessionId.equals('session-past-due'))).write(
      MedicationShortageAlertsCompanion(
        status: const Value('past_due'),
        updatedAt: Value(now.add(const Duration(hours: 3))),
      ),
    );

    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Urgent shortage'), findsOneWidget);
    expect(
      find.text(
        'This local-only shortage is still unresolved and past due on this phone. Dosey is not sending remote shortage updates yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Carousel prioritizes a past-due unresolved shortage for pinned display',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);

      await repository.confirmFullLoad(
        sessionId: 'session-priority',
        profileId: ReminderSchedule.defaultProfileId,
        plan: _shortagePlan(now),
        startedAt: now,
        confirmedAt: now,
      );
      await database
          .into(database.medicationShortageAlerts)
          .insert(
            MedicationShortageAlertsCompanion.insert(
              id: 'shortage:session-priority:1-active',
              profileId: ReminderSchedule.defaultProfileId,
              loadSessionId: const Value('session-priority'),
              slotNumber: 1,
              bundleKey: 'bundle-active',
              scheduledAt: DateTime.utc(2026, 7, 23, 9),
              prescriptionIdsJson: '["vitamin-d"]',
              prescriptionNamesJson: '["active alert"]',
              status: 'active',
              localDeliveryState: 'sent',
              createdAt: now.add(const Duration(minutes: 1)),
              updatedAt: now.add(const Duration(minutes: 1)),
            ),
          );
      await (database.update(
        database.medicationShortageAlerts,
      )..where((row) => row.id.equals('shortage:session-priority:2'))).write(
        MedicationShortageAlertsCompanion(
          status: const Value('past_due'),
          updatedAt: Value(now.add(const Duration(hours: 3))),
        ),
      );

      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();

      expect(find.text('Slot 2'), findsOneWidget);
      expect(find.text('Slot 1'), findsNothing);
      expect(
        find.text(
          'This local-only shortage is still unresolved and past due on this phone. Dosey is not sending remote shortage updates yet.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'carousel ring keeps circular controls unambiguous at 400 and 320dp',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);
      await repository.confirmFullLoad(
        sessionId: 'session-ring-layout',
        profileId: ReminderSchedule.defaultProfileId,
        plan: _plan(now),
        startedAt: now,
        confirmedAt: now,
      );

      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start refill/loading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top off empty slots'));
      await tester.pumpAndSettle();

      _expectCarouselRingGeometry(tester);

      final semantics = tester.ensureSemantics();
      final startMarker = tester.getSemantics(
        find.byKey(const ValueKey<String>('carousel-start-marker')),
      );
      expect(startMarker.label, 'START/home marker');
      expect(
        startMarker.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      final availableSlot = tester.getSemantics(_carouselSlot(2));
      expect(availableSlot.label, 'Slot 2, empty and available to load');
      expect(availableSlot.flagsCollection.isButton, isTrue);
      expect(
        availableSlot.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(availableSlot.flagsCollection.isToggled, Tristate.isFalse);

      await _tapSharedRectangleGap(tester, 1, 2);
      await tester.pump();
      expect(
        tester.getSemantics(_carouselSlot(2)).label,
        'Slot 2, empty and available to load',
      );

      await _tapCarouselSlot(tester, 2);
      await tester.pump();
      final selectedSlot = tester.getSemantics(_carouselSlot(2));
      expect(selectedSlot.label, 'Slot 2, selected to load');
      expect(selectedSlot.flagsCollection.isToggled, Tristate.isTrue);

      await tester.binding.setSurfaceSize(const Size(320, 900));
      await tester.pumpAndSettle();
      _expectCarouselRingGeometry(tester);
      await _tapSharedRectangleGap(tester, 1, 2);
      await tester.pump();
      expect(
        tester.getSemantics(_carouselSlot(2)).label,
        'Slot 2, selected to load',
      );
      semantics.dispose();
    },
  );

  testWidgets('top-off exposes controls only for fillable slots', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 1);
    await _seedReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);
    await repository.confirmFullLoad(
      sessionId: 'session-top-off-inert-slots',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _plan(now),
      startedAt: now,
      confirmedAt: now,
    );

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start refill/loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top off empty slots'));
    await tester.pumpAndSettle();

    for (final slot in [1, 2, 3]) {
      final node = tester.getSemantics(_carouselSlot(slot));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    }
    expect(tester.getSemantics(_carouselSlot(1)).label, 'Slot 1, loaded');
    expect(
      tester.getSemantics(_carouselSlot(2)).label,
      'Slot 2, blocked by a shortage',
    );
    expect(
      tester.getSemantics(_carouselSlot(3)).label,
      'Slot 3, empty for a later pass',
    );
    semantics.dispose();
  });

  testWidgets('full reload lets a recovered slot be unmarked', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 6);
    await _seedReminder(database);
    final repository = LocalGuidedCarouselLoadRepository(database);
    final now = DateTime.utc(2026, 7, 23, 8);
    await repository.confirmFullLoad(
      sessionId: 'session-unmark-recovered',
      profileId: ReminderSchedule.defaultProfileId,
      plan: _plan(now),
      startedAt: now,
      confirmedAt: now,
    );

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start refill/loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty and reload all'));
    await tester.pumpAndSettle();

    await _tapCarouselSlot(tester, 1);
    await tester.pump();
    expect(
      tester.getSemantics(_carouselSlot(1)).label,
      'Slot 1, recovered during unload',
    );

    await _tapCarouselSlot(tester, 1);
    await tester.pump();
    final unmarkedSlot = tester.getSemantics(_carouselSlot(1));
    expect(unmarkedSlot.label, 'Slot 1, loaded');
    expect(unmarkedSlot.flagsCollection.isToggled, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('display-only reload plans use inert namespaced rings', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    await _seedPrescription(database, availableDoses: 6);
    await _seedReminder(database);

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_TestApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start refill/loading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty and reload all'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('full-reload-current-ring')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('full-reload-next-ring')),
      findsOneWidget,
    );
    expect(find.text('Verify empty carousel'), findsOneWidget);
    expect(
      find.text(
        'Confirm the physical carousel is empty and aligned at START/home before you confirm the new load.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Confirm the physical carousel is empty and aligned at START/home.',
      ),
      findsOneWidget,
    );
    expect(find.text('Empty carousel confirmed'), findsNothing);
    expect(find.text('Unload saved'), findsNothing);
    expect(
      find.text(
        'Empty after the saved unload. Keep the carousel at START/home.',
      ),
      findsNothing,
    );
    final currentRing = tester.getSemantics(
      find.byKey(const ValueKey<String>('full-reload-current-ring')),
    );
    expect(
      currentRing.label,
      'Current physical carousel, verify empty and display only',
    );
    final slot = tester.getSemantics(_fullReloadCurrentSlot(1));
    expect(slot.label, 'Slot 1, expected empty, verify physical carousel');
    expect(slot.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    final nextSlot = tester.getSemantics(_fullReloadNextSlot(1));
    expect(nextSlot.label, 'Slot 1, planned to load');
    expect(nextSlot.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets(
    'post-unload reload separates current carousel from next plan at 320dp',
    (WidgetTester tester) async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _seedPrescription(database, availableDoses: 6);
      await _seedReminder(database);
      final repository = LocalGuidedCarouselLoadRepository(database);
      final now = DateTime.utc(2026, 7, 23, 8);
      await repository.confirmFullLoad(
        sessionId: 'session-current-next-plan',
        profileId: ReminderSchedule.defaultProfileId,
        plan: _plan(now),
        startedAt: now,
        confirmedAt: now,
      );

      await tester.binding.setSurfaceSize(const Size(400, 900));
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_TestApp(database: database));
      await tester.pumpAndSettle();
      final startLoading = find.text('Start refill/loading');
      await tester.tap(startLoading);
      await tester.pumpAndSettle();
      final fullReload = find.text('Empty and reload all');
      await tester.tap(fullReload);
      await tester.pumpAndSettle();
      await _tapCarouselSlot(tester, 1);
      await tester.pump();
      final confirmUnload = find.text('Confirm physical unload');
      await tester.ensureVisible(confirmUnload);
      await tester.tap(confirmUnload);
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(320, 900));
      await tester.pumpAndSettle();

      expect(find.text('Current physical carousel'), findsOneWidget);
      expect(find.text('Next load plan'), findsOneWidget);
      expect(find.text('Empty carousel confirmed'), findsOneWidget);
      expect(find.text('Unload saved'), findsOneWidget);
      expect(
        find.text(
          'Empty after the saved unload. Keep the carousel at START/home.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Display only. Check the planned compartments before confirming the reload at START/home.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '5 planned compartments · 1 shortage slot · 8 compartments not planned in this reload. Confirm the reload at START/home.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('full-reload-current-ring')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('full-reload-next-ring')),
        findsOneWidget,
      );

      final currentRing = tester.getSemantics(
        find.byKey(const ValueKey<String>('full-reload-current-ring')),
      );
      expect(
        currentRing.label,
        'Current physical carousel, confirmed empty and display only',
      );

      final currentStart = tester.getSemantics(
        find.byKey(const ValueKey<String>('full-reload-current-start-marker')),
      );
      final nextStart = tester.getSemantics(
        find.byKey(const ValueKey<String>('full-reload-next-start-marker')),
      );
      expect(currentStart.label, 'START/home marker');
      expect(nextStart.label, 'START/home marker');
      expect(
        currentStart.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        nextStart.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      final currentSlot = tester.getSemantics(_fullReloadCurrentSlot(1));
      final nextSlot = tester.getSemantics(_fullReloadNextSlot(1));
      expect(currentSlot.label, 'Slot 1, confirmed empty');
      expect(nextSlot.label, 'Slot 1, planned to load');
      expect(
        currentSlot.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        nextSlot.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    },
  );
}

Finder _carouselSlot(int slotNumber) =>
    find.byKey(ValueKey<String>('carousel-slot-$slotNumber'));

Finder _fullReloadCurrentSlot(int slotNumber) =>
    find.byKey(ValueKey<String>('full-reload-current-slot-$slotNumber'));

Finder _fullReloadNextSlot(int slotNumber) =>
    find.byKey(ValueKey<String>('full-reload-next-slot-$slotNumber'));

Future<void> _tapCarouselSlot(WidgetTester tester, int slotNumber) async {
  final slot = _carouselSlot(slotNumber);
  await tester.ensureVisible(slot);
  await tester.tap(slot);
}

void _expectCarouselRingGeometry(WidgetTester tester) {
  final ring = tester.getRect(
    find.byKey(const ValueKey<String>('carousel-plan-ring')),
  );
  final start = tester.getRect(
    find.byKey(const ValueKey<String>('carousel-start-marker')),
  );
  final slots = <Rect>[
    for (var slot = 1; slot <= 14; slot += 1)
      tester.getRect(_carouselSlot(slot)),
  ];
  final slotOne = slots.first;
  final slotFourteen = slots.last;

  expect(start.center.dy, greaterThan(slotOne.center.dy));
  expect(start.center.dy, greaterThan(slotFourteen.center.dy));
  expect(slotOne.center.dx, lessThan(start.center.dx));
  expect(slotOne.center.dy, lessThan(start.center.dy));
  expect(slotFourteen.center.dx, greaterThan(start.center.dx));
  expect(slotFourteen.center.dy, lessThan(start.center.dy));
  expect(start.width, greaterThan(47.9));
  expect(start.height, greaterThan(47.9));
  for (final slot in slots) {
    expect(slot.width, greaterThan(47.9));
    expect(slot.height, greaterThan(47.9));
  }

  final allItems = [start, ...slots];
  final center = ring.center;
  final radius = (start.center - center).distance;
  for (final item in allItems) {
    expect(ring.contains(item.topLeft), isTrue);
    expect(ring.contains(item.bottomRight), isTrue);
    expect(
      (item.center - center).distance,
      moreOrLessEquals(radius, epsilon: 0.1),
    );
    expect((item.center - center).distance - item.width / 2, greaterThan(80));
  }

  for (var index = 0; index < allItems.length; index += 1) {
    final angle = math.atan2(
      allItems[index].center.dy - center.dy,
      allItems[index].center.dx - center.dx,
    );
    final expected = math.pi / 2 + index * (2 * math.pi / 15);
    final delta = math.atan2(
      math.sin(angle - expected),
      math.cos(angle - expected),
    );
    expect(delta.abs(), lessThan(0.01));
  }

  for (var index = 0; index < allItems.length; index += 1) {
    for (var other = index + 1; other < allItems.length; other += 1) {
      final separation =
          (allItems[index].center - allItems[other].center).distance;
      final radii = (allItems[index].width + allItems[other].width) / 2;
      expect(separation, greaterThanOrEqualTo(radii));
    }
  }
}

Future<void> _tapSharedRectangleGap(
  WidgetTester tester,
  int firstSlot,
  int secondSlot,
) async {
  await tester.ensureVisible(_carouselSlot(firstSlot));
  await tester.ensureVisible(_carouselSlot(secondSlot));
  final first = tester.getRect(_carouselSlot(firstSlot));
  final second = tester.getRect(_carouselSlot(secondSlot));
  final overlap = first.intersect(second);
  expect(overlap.isEmpty, isFalse);
  final point = Offset(
    (first.center.dx + second.center.dx) / 2,
    (first.center.dy + second.center.dy) / 2,
  );
  expect(overlap.contains(point), isTrue);
  expect((point - first.center).distance, greaterThan(first.width / 2));
  expect((point - second.center).distance, greaterThan(second.width / 2));
  await tester.tapAt(point);
}

GuidedCarouselLoadPlan _plan(DateTime now) {
  return GuidedCarouselLoadPlan(
    createdAt: now,
    mode: GuidedCarouselLoadMode.fullReload,
    priorPosition: CarouselPosition.start,
    slots: List<CarouselLoadPlanSlotPreview>.generate(14, (index) {
      if (index == 0) {
        return CarouselLoadPlanSlotPreview.loaded(
          position: CarouselPosition(1),
          bundle: CarouselDoseBundle(
            bundleKey: 'bundle-1',
            scheduledAt: DateTime.utc(2026, 7, 23, 8, 30),
            scheduleIds: const ['vitamin-d-morning'],
            medications: [
              CarouselDoseBundleMedication(
                prescriptionId: 'vitamin-d',
                prescriptionName: 'Vitamin D',
                scheduleId: 'vitamin-d-morning',
                scheduledAt: DateTime.utc(2026, 7, 23, 8, 30),
                availableDoses: 6,
                guidedPillIcon: GuidedPillIcon.roundPill,
                doseCount: 1,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        );
      }
      return CarouselLoadPlanSlotPreview.empty(
        position: CarouselPosition(index + 1),
      );
    }),
    shortages: const [],
  );
}

GuidedCarouselLoadPlan _shortagePlan(DateTime now) {
  return GuidedCarouselLoadPlan(
    createdAt: now,
    mode: GuidedCarouselLoadMode.fullReload,
    priorPosition: CarouselPosition.start,
    slots: [
      CarouselLoadPlanSlotPreview.loaded(
        position: CarouselPosition(1),
        bundle: CarouselDoseBundle(
          bundleKey: 'bundle-1',
          scheduledAt: DateTime.utc(2026, 7, 23, 8, 30),
          scheduleIds: const ['vitamin-d-morning'],
          medications: [
            CarouselDoseBundleMedication(
              prescriptionId: 'vitamin-d',
              prescriptionName: 'Vitamin D',
              scheduleId: 'vitamin-d-morning',
              scheduledAt: DateTime.utc(2026, 7, 23, 8, 30),
              availableDoses: 6,
              guidedPillIcon: GuidedPillIcon.roundPill,
              doseCount: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
      CarouselLoadPlanSlotPreview.shortage(
        position: CarouselPosition(2),
        shortage: CarouselLoadPlanShortage(
          position: CarouselPosition(2),
          bundleKey: 'bundle-2',
          scheduledAt: DateTime.utc(2026, 7, 23, 10),
          scheduleIds: const ['vitamin-d-evening'],
        ),
      ),
      ...List<CarouselLoadPlanSlotPreview>.generate(
        12,
        (index) => CarouselLoadPlanSlotPreview.empty(
          position: CarouselPosition(index + 3),
        ),
      ),
    ],
    shortages: [
      CarouselLoadPlanShortage(
        position: CarouselPosition(2),
        bundleKey: 'bundle-2',
        scheduledAt: DateTime.utc(2026, 7, 23, 10),
        scheduleIds: const ['vitamin-d-evening'],
      ),
    ],
  );
}

Future<void> _seedPrescription(
  DoseyDatabase database, {
  int availableDoses = 0,
}) {
  return LocalPrescriptionRepository(database).upsertPrescription(
    Prescription(
      id: 'vitamin-d',
      name: 'Vitamin D',
      pillType: PillType.capsule,
      availableDoses: availableDoses,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

Future<void> _seedReminder(DoseyDatabase database) {
  return LocalReminderRepository(database).upsertSchedule(
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
}

Future<void> _seedEveningReminder(DoseyDatabase database) {
  return LocalReminderRepository(database).upsertSchedule(
    ReminderSchedule(
      id: 'vitamin-d-evening',
      label: 'Vitamin D',
      prescriptionId: 'vitamin-d',
      hour: 10,
      minute: 0,
      isEnabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}

String _localTimeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.database});

  final DoseyDatabase database;

  @override
  Widget build(BuildContext context) {
    return DoseyAppScope(
      database: database,
      bleGateway: _FakeBleGateway(),
      connectivityGateway: _FakeConnectivityGateway(),
      reminderScheduler: const _NoopReminderScheduler(),
      permissionGateway: _FakePermissionGateway(),
      missedDoseReconciliationService: _FakeMissedDoseReconciliationService(),
      child: MaterialApp(home: Scaffold(body: CarouselScreen())),
    );
  }
}

class _FakeMissedDoseReconciliationService
    extends MissedDoseReconciliationService {
  _FakeMissedDoseReconciliationService()
    : super(reminders: _FakeReminderRepository(), doseLog: _FakeDoseLog());

  @override
  Future<void> reconcile() async {}
}

class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<int> deleteSchedule(String id, {dynamic auditEvent}) async => 1;

  @override
  Future<void> upsertSchedule(
    ReminderSchedule schedule, {
    dynamic auditEvent,
  }) async {}

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    return Stream.value(const <ReminderSchedule>[]);
  }
}

class _FakeDoseLog implements DoseLogRepository {
  @override
  Future<void> addEvent(DoseLogEvent event) async {}

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    return Stream.value(const <DoseLogEvent>[]);
  }
}

class _FakeBleGateway implements BleGateway {
  @override
  Future<void> close() async {}

  @override
  Stream<BleAvailabilitySnapshot> watchAvailability() {
    return Stream.value(const BleAvailabilitySnapshot.available());
  }

  @override
  Stream<BleConnectionSnapshot> watchConnection() {
    return Stream.value(const BleConnectionSnapshot.disconnected());
  }

  @override
  Future<void> connect({required String deviceId, String? deviceName}) async {}

  @override
  Future<void> disconnect() async {}
}

class _FakeConnectivityGateway implements ConnectivityGateway {
  @override
  Future<ConnectivityState> currentConnectivity() async {
    return ConnectivityState.offline;
  }

  @override
  Stream<ConnectivityState> watchConnectivity() {
    return Stream.value(ConnectivityState.offline);
  }
}

class _FakePermissionGateway implements AppPermissionGateway {
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
