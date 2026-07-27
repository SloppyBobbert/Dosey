import 'package:dosey_app/core/auth/apple_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/household/local_household_cache_repository.dart';

class AppAuthService implements AuthService {
  AppAuthService({
    required LocalAuthRepository localAuth,
    LocalHouseholdCacheRepository? householdCache,
    GoogleAuthService? googleAuthService,
    AppleAuthService? appleAuthService,
  }) : _localAuth = localAuth,
       _clearHouseholdCache =
           householdCache?.clearForAccount ?? _keepHouseholdCache,
       _googleAuthService = googleAuthService ?? GoogleAuthService(localAuth),
       _appleAuthService = appleAuthService ?? AppleAuthService(localAuth);

  final LocalAuthRepository _localAuth;
  final Future<void> Function(String accountId) _clearHouseholdCache;
  final GoogleAuthService _googleAuthService;
  final AppleAuthService _appleAuthService;

  @override
  Stream<AuthSession> watchSession() => _localAuth.watchSession();

  @override
  Future<AuthSession> signInWithGoogle() =>
      _googleAuthService.signInWithGoogle();

  @override
  Future<AuthSession> signInWithApple() => _appleAuthService.signInWithApple();

  @override
  Future<void> signOut() async {
    final session = await _localAuth.readSession();
    final provider = session.user?.provider;
    final accountId = session.user?.id;

    try {
      // Sign out through the provider that created the cached session, then let
      // that service clear the local auth row.
      switch (provider) {
        case AuthProvider.google:
          await _googleAuthService.signOut();
        case AuthProvider.apple:
          await _appleAuthService.signOut();
        case null:
          await _localAuth.clearUser();
      }
    } finally {
      if (accountId != null) {
        await _clearHouseholdCache(accountId);
      }
    }
  }

  static Future<void> _keepHouseholdCache(String accountId) async {}
}
