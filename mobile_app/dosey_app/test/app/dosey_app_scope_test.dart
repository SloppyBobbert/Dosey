import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/bluetooth/flutter_blue_plus_ble_gateway.dart';
import 'package:dosey_app/core/connectivity/connectivity_plus_gateway.dart';
import 'package:dosey_app/core/notifications/flutter_local_notification_scheduler.dart';
import 'package:dosey_app/core/permissions/permission_handler_gateway.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app scope wires the combined auth service', (
    WidgetTester tester,
  ) async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    late final Object auth;
    late final DoseyAppDependencies dependencies;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DoseyAppScope(
          database: database,
          child: Builder(
            builder: (context) {
              dependencies = DoseyAppScope.of(context);
              auth = dependencies.auth;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(auth, isA<AppAuthService>());
    expect(dependencies.ble, isA<FlutterBluePlusBleGateway>());
    expect(dependencies.connectivity, isA<ConnectivityPlusGateway>());
    expect(
      dependencies.reminderScheduler,
      isA<FlutterLocalNotificationScheduler>(),
    );
    expect(dependencies.permissions, isA<PermissionHandlerGateway>());
    expect(dependencies.robotFaceSettings, isNotNull);
    expect(dependencies.robotFaceController, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });
}
