import 'dart:async';

import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService implements AuthService {
  GoogleAuthService(this._localAuth, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final LocalAuthRepository _localAuth;
  final GoogleSignIn _googleSignIn;

  Future<void>? _initialization;

  @override
  Stream<AuthSession> watchSession() => _localAuth.watchSession();

  Future<void> restorePreviousGoogleSession() async {
    await _ensureInitialized();
    final account = await _googleSignIn.attemptLightweightAuthentication();
    if (account != null) {
      await _localAuth.saveUser(_userFromAccount(account));
    }
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    await _ensureInitialized();
    final account = await _googleSignIn.authenticate(
      scopeHint: const ['email'],
    );
    final user = _userFromAccount(account);
    await _localAuth.saveUser(user);
    return AuthSession.signedIn(user);
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await _localAuth.clearUser();
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _googleSignIn.initialize();
  }

  static AuthUser _userFromAccount(GoogleSignInAccount account) {
    return AuthUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      provider: AuthProvider.google,
    );
  }
}
