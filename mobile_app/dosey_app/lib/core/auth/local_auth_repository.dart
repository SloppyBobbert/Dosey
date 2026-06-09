import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class LocalAuthRepository {
  const LocalAuthRepository(this._database);

  static const _currentSessionId = 'current';

  final DoseyDatabase _database;

  Stream<AuthSession> watchSession() {
    final query = _database.select(_database.authSessions)
      ..where((session) => session.id.equals(_currentSessionId));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        return const AuthSession.signedOut();
      }
      return AuthSession.signedIn(_fromRow(rows.first));
    });
  }

  Future<void> saveUser(AuthUser user) {
    return _database
        .into(_database.authSessions)
        .insertOnConflictUpdate(
          AuthSessionsCompanion.insert(
            id: _currentSessionId,
            userId: user.id,
            email: user.email,
            displayName: Value(user.displayName),
            photoUrl: Value(user.photoUrl),
            provider: user.provider.name,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> clearUser() {
    return (_database.delete(
      _database.authSessions,
    )..where((session) => session.id.equals(_currentSessionId))).go();
  }

  static AuthUser _fromRow(AuthSessionRow row) {
    return AuthUser(
      id: row.userId,
      email: row.email,
      displayName: row.displayName,
      photoUrl: row.photoUrl,
      provider: AuthProvider.values.byName(row.provider),
    );
  }
}
