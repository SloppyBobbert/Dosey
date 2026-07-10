import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class LocalAuthRepository {
  const LocalAuthRepository(this._database);

  static const _currentSessionId = 'current';
  static const _appleUserIdPrefix = 'apple:';

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

  Future<AuthSession> readSession() async {
    final row = await _currentSessionRow();
    if (row == null) {
      return const AuthSession.signedOut();
    }

    return AuthSession.signedIn(_fromRow(row));
  }

  Future<AuthUser?> readCurrentUser() async {
    final row = await _currentSessionRow();
    return row == null ? null : _fromRow(row);
  }

  Future<String?> readAppleEmail(String userId) async {
    final query = _database.select(_database.authSessions)
      ..where((session) => session.id.equals(_appleSessionId(userId)));
    final row = await query.getSingleOrNull();
    if (row == null || row.provider != AuthProvider.apple.name) {
      return null;
    }

    return row.email;
  }

  Future<void> saveUser(AuthUser user) {
    return _database.transaction(() async {
      // The `current` row drives the app session regardless of provider.
      await _database
          .into(_database.authSessions)
          .insertOnConflictUpdate(
            _sessionCompanion(id: _currentSessionId, user: user),
          );

      if (user.provider == AuthProvider.apple) {
        // Apple may only return email on first sign-in; keep a provider-specific
        // row so later sign-ins can reuse the cached email.
        await _database
            .into(_database.authSessions)
            .insertOnConflictUpdate(
              _sessionCompanion(id: _appleSessionId(user.id), user: user),
            );
      }
    });
  }

  Future<void> clearUser() {
    return (_database.delete(
      _database.authSessions,
    )..where((session) => session.id.equals(_currentSessionId))).go();
  }

  Future<AuthSessionRow?> _currentSessionRow() {
    final query = _database.select(_database.authSessions)
      ..where((session) => session.id.equals(_currentSessionId));

    return query.getSingleOrNull();
  }

  AuthSessionsCompanion _sessionCompanion({
    required String id,
    required AuthUser user,
  }) {
    return AuthSessionsCompanion.insert(
      id: id,
      userId: user.id,
      email: user.email,
      displayName: Value(user.displayName),
      photoUrl: Value(user.photoUrl),
      provider: user.provider.name,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static String _appleSessionId(String userId) => '$_appleUserIdPrefix$userId';

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
