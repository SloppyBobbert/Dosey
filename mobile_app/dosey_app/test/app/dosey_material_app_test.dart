import 'package:dosey_app/app/dosey_app.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_scope_dependencies.dart';

void main() {
  testWidgets('uses dark theme on first launch', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      DoseyApp(
        database: database,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });

  testWidgets('follows persisted light and system preferences', (tester) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final settings = LocalAppSettingsRepository(
      database,
      defaultRole: AppDeviceRole.androidPersonal,
    );
    await settings.setThemePreference(AppThemePreference.light);

    await tester.pumpWidget(
      DoseyApp(
        database: database,
        bleGateway: FakeBleGateway(),
        connectivityGateway: FakeConnectivityGateway(),
        missedDoseReconciliationService: FakeMissedDoseReconciliationService(),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await settings.setThemePreference(AppThemePreference.system);
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });
}
