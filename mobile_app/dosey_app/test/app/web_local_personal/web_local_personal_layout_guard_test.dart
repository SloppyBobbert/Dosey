import 'dart:io';

import 'package:dosey_app/app/web_local_personal/web_local_personal_app.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_pages.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Real glyphs: the default test font is square and would wrap the medication
  // name even in a correctly sized row.
  setUpAll(() async {
    final font = FontLoader('DoseyLocalRoboto')
      ..addFont(
        File(
          'tool/local_personal/assets/local_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
  });

  // Layout guard only: proves the name keeps a usable column at 320px and the
  // compact rail label stays on one line at 800px.
  testWidgets(
    'medication rows keep a readable name and compact rail labels stay on one line',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final setup = PersonalSetupDependencies.local(db);
      final now = DateTime.utc(2026, 9, 15);
      await tester.runAsync(
        () => setup.prescriptions.upsertPrescription(
          Prescription(
            id: 'fictional',
            name: 'Example Vitamin',
            pillType: PillType.pill,
            availableDoses: 8,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
      await tester.pumpWidget(
        PersonalSetupScope(
          dependencies: setup,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'DoseyLocalRoboto'),
            home: const Scaffold(
              body: SingleChildScrollView(child: PrescriptionsScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The five row actions used to take every pixel, collapsing the name to
      // a one-character column (measured 0x336 before the fix).
      final name = find.text('Example Vitamin');
      expect(name, findsOneWidget);
      final nameSize = tester.getSize(name);
      expect(
        nameSize.width,
        greaterThanOrEqualTo(40),
        reason: 'medication name column collapsed at 320px',
      );
      expect(
        nameSize.height,
        lessThan(30),
        reason: 'medication name wrapped past one 16px line at 320px',
      );
      await tester.pumpWidget(const SizedBox());
      await setup.drain();

      tester.view.physicalSize = const Size(800, 900);
      final controller = WebLocalPersonalRouteController(
        initialPath: '/prescriptions',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view),
          child: WebLocalPersonalApp(
            storage: WebStorageDemoOnly(
              classification: classifyWebStorage(
                WebStorageImplementation.inMemory,
              ),
              missingFeatures: const {},
            ),
            routeController: controller,
            routeInformationProvider: _FakeRouteInformationProvider(
              controller.currentPath,
            ),
            pageBuilder: buildWebLocalPersonalFoundationPage,
          ),
        ),
      );
      await tester.pump();
      // The 64px compact rail destination used to break "Prescriptions"
      // mid-word; the compact form must stay one legible line. The rail shows
      // the short form while assistive tech keeps the full name.
      final railLabel = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Meds'),
      );
      expect(railLabel, findsOneWidget);
      final label = tester.widget<Text>(railLabel);
      expect(label.maxLines, 1);
      expect(label.softWrap, isFalse);
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Prescriptions'),
        ),
        findsNothing,
        reason: 'the compact rail must not render the long label',
      );
      expect(
        tester.getSize(railLabel).height,
        lessThan(30),
        reason: 'compact rail label wrapped past one line at 800px',
      );
      final fitted = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byType(FittedBox),
      );
      expect(fitted, findsWidgets);
      for (final element in fitted.evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(box.size.width, lessThanOrEqualTo(104.5));
        // A shrink-to-fit long label rendered about 5px tall, which is not
        // legible; the rail must fit without collapsing the glyphs.
        expect(
          box.size.height,
          greaterThanOrEqualTo(10),
          reason: 'compact rail label shrank below a legible size',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  // Layout guard only: proves the schedule profile section keeps its heading
  // and profile names readable at 320px inside the narrow demo window.
  testWidgets('320px keeps schedule profile rows readable', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = DoseyDatabase.inMemory();
    addTearDown(db.close);
    final setup = PersonalSetupDependencies.local(db);
    final stamp = DateTime.utc(2026, 9, 15);
    await tester.runAsync(() async {
      await setup.prescriptions.upsertPrescription(
        Prescription(
          id: 'fictional',
          name: 'Example Vitamin',
          pillType: PillType.pill,
          availableDoses: 8,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
      await setup.scheduleProfiles.upsertProfile(
        ScheduleProfile(
          id: 'profile-1',
          name: 'Fictional blue',
          isActive: true,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
      await setup.scheduleProfiles.upsertProfile(
        ScheduleProfile(
          id: 'profile-2',
          name: 'Evening routine',
          isActive: false,
          createdAt: stamp.add(const Duration(minutes: 1)),
          updatedAt: stamp,
        ),
      );
      await setup.reminders.upsertSchedule(
        ReminderSchedule(
          id: 'schedule-1',
          label: 'Example Vitamin',
          prescriptionId: 'fictional',
          profileId: 'profile-1',
          hour: 8,
          minute: 0,
          isEnabled: true,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    });
    await tester.pumpWidget(
      PersonalSetupScope(
        dependencies: setup,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'DoseyLocalRoboto'),
          home: const Scaffold(
            body: SingleChildScrollView(child: RemindersScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The heading used to be squeezed to 64px beside "Add schedule profile"
    // (measured 64.5x72.0, three lines) and the inactive profile name with its
    // "Use <name>" action to 27px (measured 27.4x144.0).
    final heading = find.text('Active schedule');
    expect(heading, findsOneWidget);
    expect(
      tester.getSize(heading).height,
      lessThan(30),
      reason: 'profile section heading wrapped at 320px',
    );
    final profileName = find.text('Evening routine');
    expect(profileName, findsOneWidget);
    final profileNameSize = tester.getSize(profileName);
    expect(
      profileNameSize.width,
      greaterThanOrEqualTo(40),
      reason: 'profile name column collapsed at 320px',
    );
    expect(
      profileNameSize.height,
      lessThan(30),
      reason: 'profile name wrapped past one line at 320px',
    );
    final useProfile = find.byTooltip('Use Evening routine schedule');
    expect(useProfile, findsOneWidget);
    expect(useProfile.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await setup.drain();
  });

  // Switching tabs must not shift the content column: the Settings page is the
  // foundation copy while the other tabs render their own cards.
  for (final width in <double>[320, 800]) {
    testWidgets('settings content lines up with the other tabs at ${width}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final setup = PersonalSetupDependencies.local(database);
      final controller = WebLocalPersonalRouteController(
        initialPath: WebLocalPersonalDestination.settings.path,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(() => setup.initializeLocalProfile());

      await tester.pumpWidget(
        PersonalSetupScope(
          dependencies: setup,
          child: WebLocalPersonalApp(
            storage: WebStorageReady(
              database: database,
              classification: classifyWebStorage(
                WebStorageImplementation.opfsShared,
              ),
              missingFeatures: const {},
            ),
            routeController: controller,
            routeInformationProvider: _FakeRouteInformationProvider(
              WebLocalPersonalDestination.settings.path,
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 8; attempt++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
      }
      await tester.pump(const Duration(milliseconds: 40));

      final page = find.byKey(
        const ValueKey('web-local-personal-page-scroll-view'),
      );
      final settingsLeft = tester
          .getTopLeft(
            find.descendant(of: page, matching: find.text('Settings')).first,
          )
          .dx;

      controller.goTo(WebLocalPersonalDestination.prescriptions);
      for (var attempt = 0; attempt < 8; attempt++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
      }
      await tester.pump(const Duration(milliseconds: 40));

      final cardLeft = tester
          .getTopLeft(
            find.descendant(of: page, matching: find.byType(Card)).first,
          )
          .dx;
      expect(
        (settingsLeft - cardLeft).abs(),
        lessThanOrEqualTo(8),
        reason:
            'settings content starts at $settingsLeft but the prescriptions '
            'card starts at $cardLeft; switching tabs must not shift the page',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => setup.drain());
    });
  }
}

class _FakeRouteInformationProvider extends ValueNotifier<RouteInformation>
    implements RouteInformationProvider {
  _FakeRouteInformationProvider(String path)
    : super(RouteInformation(uri: Uri(path: path)));

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {}
}
