import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'protected admin action does not run when PIN prompt is canceled',
    () async {
      final fixture = _Fixture();
      await fixture.settings.setActionPin('1234');
      var actionRan = false;

      final result = await fixture.runner.run<void>(
        requestPin: () async => null,
        action: (_) async {
          actionRan = true;
        },
      );

      expect(result.status, ProtectedAdminActionStatus.cancelled);
      expect(actionRan, isFalse);
    },
  );

  test('protected admin action does not run when PIN is wrong', () async {
    final fixture = _Fixture();
    await fixture.settings.setActionPin('1234');
    var actionRan = false;

    final result = await fixture.runner.run<void>(
      requestPin: () async => '9999',
      action: (_) async {
        actionRan = true;
      },
    );

    expect(result.status, ProtectedAdminActionStatus.denied);
    expect(actionRan, isFalse);
  });

  test(
    'protected admin action uses display name before email fallback',
    () async {
      final fixture = _Fixture();
      await fixture.localAuth.saveUser(
        const AuthUser(
          id: 'user-1',
          email: 'admin@example.com',
          displayName: 'Dosey Admin',
          photoUrl: null,
          provider: AuthProvider.google,
        ),
      );

      final actor = await fixture.runner.resolveActor();

      expect(actor.actorUserId, 'google:user-1');
      expect(actor.actorLabel, 'Dosey Admin (google)');
      expect(actor.actorProviderLabel, 'google');
    },
  );

  test('protected admin action falls back to email then local admin', () async {
    final fixture = _Fixture();
    await fixture.localAuth.saveUser(
      const AuthUser(
        id: 'user-2',
        email: 'fallback@example.com',
        displayName: '   ',
        photoUrl: null,
        provider: AuthProvider.apple,
      ),
    );

    final signedInActor = await fixture.runner.resolveActor();
    expect(signedInActor.actorLabel, 'fallback@example.com (apple)');
    expect(signedInActor.actorUserId, 'apple:user-2');

    await fixture.localAuth.clearUser();

    final localActor = await fixture.runner.resolveActor();
    expect(localActor.actorLabel, 'local admin');
    expect(localActor.actorUserId, isNull);
  });
}

class _Fixture {
  _Fixture() {
    addTearDown(database.close);
  }

  final DoseyDatabase database = DoseyDatabase.inMemory();
  late final LocalAppSettingsRepository settings = LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
  late final LocalAuthRepository localAuth = LocalAuthRepository(database);
  late final ProtectedAdminActionRunner runner = ProtectedAdminActionRunner(
    pinGate: ActionPinGate(settings),
    localAuth: localAuth,
  );
}
