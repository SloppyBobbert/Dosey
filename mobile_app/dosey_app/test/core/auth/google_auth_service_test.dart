import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign out clears local auth cache when Google sign out fails', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final service = GoogleAuthService(
      localAuth,
      googleAccountGateway: _FailingSignOutGoogleGateway(),
    );

    await localAuth.saveUser(
      const AuthUser(
        id: 'google-123',
        email: 'dosey@example.com',
        displayName: 'Dosey Tester',
        photoUrl: null,
        provider: AuthProvider.google,
      ),
    );

    await expectLater(service.signOut(), throwsStateError);

    final session = await localAuth.watchSession().first;
    expect(session.isSignedIn, isFalse);
    expect(session.user, isNull);
  });
}

class _FailingSignOutGoogleGateway implements GoogleAccountGateway {
  @override
  Future<void> initialize() async {}

  @override
  Future<GoogleAccountInfo?> attemptLightweightAuthentication() {
    throw UnimplementedError();
  }

  @override
  Future<GoogleAccountInfo> authenticate({required List<String> scopeHint}) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    throw StateError('Google sign out failed.');
  }
}
