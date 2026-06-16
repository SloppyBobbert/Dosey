import 'package:dosey_app/core/auth/apple_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sign in with Apple caches the signed-in user', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final service = AppleAuthService(
      localAuth,
      appleAccountGateway: _SuccessfulAppleGateway(),
    );

    final session = await service.signInWithApple();

    expect(session.isSignedIn, isTrue);
    expect(
      session.user,
      _SuccessfulAppleGateway.user.toAuthUser(
        email: 'dosey@privaterelay.appleid.com',
      ),
    );
    final cachedSession = await localAuth.watchSession().first;
    expect(
      cachedSession.user,
      _SuccessfulAppleGateway.user.toAuthUser(
        email: 'dosey@privaterelay.appleid.com',
      ),
    );
  });

  test('sign out clears local auth cache when Apple sign out fails', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final service = AppleAuthService(
      localAuth,
      appleAccountGateway: _FailingSignOutAppleGateway(),
    );

    await localAuth.saveUser(
      const AuthUser(
        id: 'apple-123',
        email: 'dosey@privaterelay.appleid.com',
        displayName: 'Dosey Tester',
        photoUrl: null,
        provider: AuthProvider.apple,
      ),
    );

    await expectLater(service.signOut(), throwsStateError);

    final session = await localAuth.watchSession().first;
    expect(session.isSignedIn, isFalse);
    expect(session.user, isNull);
  });

  test(
    'sign in with Apple reuses cached email when provider omits it',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final localAuth = LocalAuthRepository(database);
      final service = AppleAuthService(
        localAuth,
        appleAccountGateway: _MissingEmailAppleGateway(),
      );

      await localAuth.saveUser(
        const AuthUser(
          id: 'apple-123',
          email: 'dosey@privaterelay.appleid.com',
          displayName: 'Dosey Tester',
          photoUrl: null,
          provider: AuthProvider.apple,
        ),
      );

      final session = await service.signInWithApple();

      expect(session.user?.email, 'dosey@privaterelay.appleid.com');
      expect(session.user?.provider, AuthProvider.apple);
    },
  );

  test('sign in with Apple fails safely when email is unavailable', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final service = AppleAuthService(
      localAuth,
      appleAccountGateway: _MissingEmailAppleGateway(),
    );

    await expectLater(service.signInWithApple(), throwsStateError);

    final session = await localAuth.watchSession().first;
    expect(session.isSignedIn, isFalse);
  });

  test('sign in with Apple reuses stored email after sign-out', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final localAuth = LocalAuthRepository(database);
    final initialService = AppleAuthService(
      localAuth,
      appleAccountGateway: _SuccessfulAppleGateway(),
    );
    final laterService = AppleAuthService(
      localAuth,
      appleAccountGateway: _MissingEmailAppleGateway(),
    );

    await initialService.signInWithApple();
    await initialService.signOut();

    final session = await laterService.signInWithApple();

    expect(session.user?.email, 'dosey@privaterelay.appleid.com');
    expect(session.user?.provider, AuthProvider.apple);
  });

  test(
    'Apple account gateway reads credentials from platform channel',
    () async {
      const channel = MethodChannel('com.sloppybobbert.dosey_app/apple_auth');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'signIn');
            return <String, Object?>{
              'id': 'apple-123',
              'email': 'dosey@privaterelay.appleid.com',
              'displayName': 'Dosey Tester',
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final account = await const AppleSignInAccountGateway(
        channel: channel,
      ).signIn();

      expect(account.id, 'apple-123');
      expect(account.email, 'dosey@privaterelay.appleid.com');
      expect(account.displayName, 'Dosey Tester');
    },
  );
}

class _SuccessfulAppleGateway implements AppleAccountGateway {
  static const user = AppleAccountInfo(
    id: 'apple-123',
    email: 'dosey@privaterelay.appleid.com',
    displayName: 'Dosey Tester',
  );

  @override
  Future<AppleAccountInfo> signIn() async => user;

  @override
  Future<void> signOut() async {}
}

class _FailingSignOutAppleGateway implements AppleAccountGateway {
  @override
  Future<AppleAccountInfo> signIn() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    throw StateError('Apple sign out failed.');
  }
}

class _MissingEmailAppleGateway implements AppleAccountGateway {
  @override
  Future<AppleAccountInfo> signIn() async {
    return const AppleAccountInfo(
      id: 'apple-123',
      email: null,
      displayName: 'Dosey Tester',
    );
  }

  @override
  Future<void> signOut() async {}
}
