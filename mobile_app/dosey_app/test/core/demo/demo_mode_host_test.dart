import 'package:dosey_app/core/demo/demo_mode_host.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/time/app_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'demo mode swaps databases and exits without changing production',
    (tester) async {
      final production = DoseyDatabase.inMemory();
      final demo = DoseyDatabase.inMemory(isDemo: true);
      final productionClock = ControllableAppClock(DateTime.utc(2039));
      addTearDown(() async {
        await productionClock.close();
        await production.close();
        await demo.close();
      });
      await production
          .into(production.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'production-only',
              value: 'preserved',
              updatedAt: DateTime.utc(2039),
            ),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: DemoModeHost(
            productionDatabase: production,
            productionClock: productionClock,
            demoDatabaseFactory: () => demo,
            devicePlatform: AppDevicePlatform.android,
            builder: (context, session) => Scaffold(
              body: Column(
                children: [
                  Text(
                    session.database.isDemo
                        ? 'demo database'
                        : 'production database',
                  ),
                  FilledButton(
                    onPressed: DemoModeHost.of(context).enter,
                    child: const Text('Enter demo'),
                  ),
                  FilledButton(
                    onPressed: DemoModeHost.of(context).exit,
                    child: const Text('Exit demo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('production database'), findsOneWidget);
      expect(find.text('GUIDED TRIAL - FAKE DATA'), findsNothing);

      await tester.tap(find.text('Enter demo'));
      await tester.pumpAndSettle();

      expect(find.text('demo database'), findsOneWidget);
      expect(find.text('GUIDED TRIAL - FAKE DATA'), findsOneWidget);
      final role = await LocalAppSettingsRepository(
        demo,
        defaultRole: AppDeviceRole.androidPersonal,
      ).getDeviceRole();
      expect(role, AppDeviceRole.androidRobot);

      await tester.tap(find.text('Exit demo'));
      await tester.pumpAndSettle();

      expect(find.text('production database'), findsOneWidget);
      expect(find.text('GUIDED TRIAL - FAKE DATA'), findsNothing);
      expect(
        await (production.select(production.appSettings)
              ..where((row) => row.key.equals('production-only')))
            .getSingle()
            .then((row) => row.value),
        'preserved',
      );
    },
  );

  testWidgets('iOS demo mode remains personal-only', (tester) async {
    final production = DoseyDatabase.inMemory();
    final demo = DoseyDatabase.inMemory(isDemo: true);
    addTearDown(production.close);
    addTearDown(demo.close);

    await tester.pumpWidget(
      MaterialApp(
        home: DemoModeHost(
          productionDatabase: production,
          productionClock: ControllableAppClock(DateTime.utc(2039)),
          demoDatabaseFactory: () => demo,
          devicePlatform: AppDevicePlatform.ios,
          builder: (context, session) => FilledButton(
            onPressed: DemoModeHost.of(context).enter,
            child: const Text('Enter demo'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enter demo'));
    await tester.pumpAndSettle();

    final role = await LocalAppSettingsRepository(
      demo,
      defaultRole: AppDeviceRole.androidRobot,
    ).getDeviceRole();
    expect(role, AppDeviceRole.iosPersonal);
  });

  testWidgets('trial completion writes metadata only to production settings', (
    tester,
  ) async {
    final production = DoseyDatabase.inMemory();
    final demo = DoseyDatabase.inMemory(isDemo: true);
    final completedAt = DateTime.utc(2041, 2, 3, 4, 5);
    addTearDown(production.close);
    addTearDown(demo.close);

    await tester.pumpWidget(
      MaterialApp(
        home: DemoModeHost(
          productionDatabase: production,
          productionClock: ControllableAppClock(DateTime.utc(2039)),
          demoDatabaseFactory: () => demo,
          devicePlatform: AppDevicePlatform.android,
          appVersionResolver: () async => '1.2.3+4',
          now: () => completedAt,
          builder: (context, session) => Column(
            children: [
              FilledButton(
                onPressed: DemoModeHost.of(context).startGuidedTrial,
                child: const Text('Start trial'),
              ),
              FilledButton(
                onPressed: DemoModeHost.of(context).completeGuidedTrial,
                child: const Text('Complete trial'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start trial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete trial'));
    await tester.pumpAndSettle();

    final productionCompletion = await LocalAppSettingsRepository(
      production,
      defaultRole: AppDeviceRole.androidRobot,
    ).getGuidedTrialCompletion();
    final demoCompletion = await LocalAppSettingsRepository(
      demo,
      defaultRole: AppDeviceRole.androidRobot,
    ).getGuidedTrialCompletion();
    expect(
      productionCompletion,
      GuidedTrialCompletion(completedAt: completedAt, appVersion: '1.2.3+4'),
    );
    expect(demoCompletion, isNull);
  });
}
