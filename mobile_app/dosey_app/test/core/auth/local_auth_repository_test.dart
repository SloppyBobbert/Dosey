import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local auth repository starts signed out', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAuthRepository(database);

    final session = await repository.watchSession().first;

    expect(session.isSignedIn, isFalse);
    expect(session.user, isNull);
  });

  test('local auth repository caches a Google user', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAuthRepository(database);
    const user = AuthUser(
      id: 'google-123',
      email: 'dosey@example.com',
      displayName: 'Dosey Tester',
      photoUrl: 'https://example.com/photo.png',
      provider: AuthProvider.google,
    );

    await repository.saveUser(user);

    final session = await repository.watchSession().first;
    expect(session.isSignedIn, isTrue);
    expect(session.user, user);
  });

  test('local auth repository caches an Apple user', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAuthRepository(database);
    const user = AuthUser(
      id: 'apple-123',
      email: 'dosey@privaterelay.appleid.com',
      displayName: 'Dosey Tester',
      photoUrl: null,
      provider: AuthProvider.apple,
    );

    await repository.saveUser(user);

    final session = await repository.watchSession().first;
    expect(session.isSignedIn, isTrue);
    expect(session.user, user);
  });

  test('local auth repository clears a cached user', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAuthRepository(database);

    await repository.saveUser(
      const AuthUser(
        id: 'google-123',
        email: 'dosey@example.com',
        displayName: 'Dosey Tester',
        photoUrl: null,
        provider: AuthProvider.google,
      ),
    );
    await repository.clearUser();

    final session = await repository.watchSession().first;
    expect(session.isSignedIn, isFalse);
    expect(session.user, isNull);
  });

  test('local auth repository watches only the current session row', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalAuthRepository(database);

    await database
        .into(database.authSessions)
        .insert(
          AuthSessionsCompanion.insert(
            id: 'stale',
            userId: 'old-user',
            email: 'old@example.com',
            provider: AuthProvider.google.name,
            updatedAt: DateTime.utc(2026, 6, 9),
          ),
        );
    await repository.saveUser(
      const AuthUser(
        id: 'current-user',
        email: 'current@example.com',
        displayName: null,
        photoUrl: null,
        provider: AuthProvider.google,
      ),
    );

    final session = await repository.watchSession().first;
    expect(session.user?.id, 'current-user');
    expect(session.user?.email, 'current@example.com');
  });

  test(
    'local auth repository preserves Apple email outside current session',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAuthRepository(database);

      await repository.saveUser(
        const AuthUser(
          id: 'apple-123',
          email: 'dosey@privaterelay.appleid.com',
          displayName: 'Dosey Tester',
          photoUrl: null,
          provider: AuthProvider.apple,
        ),
      );
      await repository.clearUser();

      expect(
        await repository.readAppleEmail('apple-123'),
        'dosey@privaterelay.appleid.com',
      );
      final session = await repository.watchSession().first;
      expect(session.isSignedIn, isFalse);
    },
  );
}
