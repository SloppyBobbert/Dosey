import 'package:dosey_app/core/auth/apple_auth_service.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';

class AppAuthService implements AuthService {
  AppAuthService({
    required LocalAuthRepository localAuth,
    GoogleAuthService? googleAuthService,
    AppleAuthService? appleAuthService,
  }) : _localAuth = localAuth,
       _googleAuthService = googleAuthService ?? GoogleAuthService(localAuth),
       _appleAuthService = appleAuthService ?? AppleAuthService(localAuth);

  final LocalAuthRepository _localAuth;
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

    switch (provider) {
      case AuthProvider.google:
        await _googleAuthService.signOut();
      case AuthProvider.apple:
        await _appleAuthService.signOut();
      case null:
        await _localAuth.clearUser();
    }
  }
}
