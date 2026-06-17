import 'package:dosey_app/core/auth/app_auth_service.dart';
import 'package:dosey_app/core/auth/apple_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app auth service supports Google sign-in through auth contract',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final localAuth = LocalAuthRepository(database);
      final service = AppAuthService(
        localAuth: localAuth,
        googleAuthService: GoogleAuthService(
          localAuth,
          googleAccountGateway: _SuccessfulGoogleGateway(),
        ),
        appleAuthService: AppleAuthService(
          localAuth,
          appleAccountGateway: _SuccessfulAppleGateway(),
        ),
      );

      final session = await service.signInWithGoogle();

      expect(session.user?.provider, AuthProvider.google);
      expect(session.user?.email, 'dosey@example.com');
    },
  );

  test(
    'app auth service supports Apple sign-in through auth contract',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final localAuth = LocalAuthRepository(database);
      final service = AppAuthService(
        localAuth: localAuth,
        googleAuthService: GoogleAuthService(
          localAuth,
          googleAccountGateway: _SuccessfulGoogleGateway(),
        ),
        appleAuthService: AppleAuthService(
          localAuth,
          appleAccountGateway: _SuccessfulAppleGateway(),
        ),
      );

      final session = await service.signInWithApple();

      expect(session.user?.provider, AuthProvider.apple);
      expect(session.user?.email, 'dosey@privaterelay.appleid.com');
    },
  );

  test('app auth service signs out through Google provider', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final googleGateway = _TrackingGoogleGateway();
    final appleGateway = _TrackingAppleGateway();
    final service = AppAuthService(
      localAuth: localAuth,
      googleAuthService: GoogleAuthService(
        localAuth,
        googleAccountGateway: googleGateway,
      ),
      appleAuthService: AppleAuthService(
        localAuth,
        appleAccountGateway: appleGateway,
      ),
    );

    await service.signInWithGoogle();
    await service.signOut();

    expect(googleGateway.signOutCallCount, 1);
    expect(appleGateway.signOutCallCount, 0);
  });

  test('app auth service signs out through Apple provider', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final googleGateway = _TrackingGoogleGateway();
    final appleGateway = _TrackingAppleGateway();
    final service = AppAuthService(
      localAuth: localAuth,
      googleAuthService: GoogleAuthService(
        localAuth,
        googleAccountGateway: googleGateway,
      ),
      appleAuthService: AppleAuthService(
        localAuth,
        appleAccountGateway: appleGateway,
      ),
    );

    await service.signInWithApple();
    await service.signOut();

    expect(googleGateway.signOutCallCount, 0);
    expect(appleGateway.signOutCallCount, 1);
  });
}

class _SuccessfulGoogleGateway implements GoogleAccountGateway {
  @override
  Future<GoogleAccountInfo?> attemptLightweightAuthentication() async => null;

  @override
  Future<GoogleAccountInfo> authenticate({
    required List<String> scopeHint,
  }) async {
    return const GoogleAccountInfo(
      id: 'google-123',
      email: 'dosey@example.com',
      displayName: 'Dosey Tester',
      photoUrl: null,
    );
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}

class _SuccessfulAppleGateway implements AppleAccountGateway {
  @override
  Future<AppleAccountInfo> signIn() async {
    return const AppleAccountInfo(
      id: 'apple-123',
      email: 'dosey@privaterelay.appleid.com',
      displayName: 'Dosey Tester',
    );
  }

  @override
  Future<void> signOut() async {}
}

class _TrackingGoogleGateway extends _SuccessfulGoogleGateway {
  int signOutCallCount = 0;

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
  }
}

class _TrackingAppleGateway extends _SuccessfulAppleGateway {
  int signOutCallCount = 0;

  @override
  Future<void> signOut() async {
    signOutCallCount += 1;
  }
}
