import 'dart:async';

import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService(
    this._localAuth, {
    GoogleAccountGateway? googleAccountGateway,
  }) : _googleAccountGateway =
           googleAccountGateway ?? GoogleSignInAccountGateway();

  final LocalAuthRepository _localAuth;
  final GoogleAccountGateway _googleAccountGateway;

  Future<void>? _initialization;

  Stream<AuthSession> watchSession() => _localAuth.watchSession();

  Future<void> restorePreviousGoogleSession() async {
    await _ensureInitialized();
    final account = await _googleAccountGateway
        .attemptLightweightAuthentication();
    if (account != null) {
      await _localAuth.saveUser(account.toAuthUser());
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    await _ensureInitialized();
    final account = await _googleAccountGateway.authenticate(
      scopeHint: const ['email'],
    );
    final user = account.toAuthUser();
    await _localAuth.saveUser(user);
    return AuthSession.signedIn(user);
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleAccountGateway.signOut();
    } finally {
      await _localAuth.clearUser();
    }
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _googleAccountGateway.initialize();
  }
}

class GoogleAccountInfo {
  const GoogleAccountInfo({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  AuthUser toAuthUser() {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      provider: AuthProvider.google,
    );
  }
}

abstract interface class GoogleAccountGateway {
  Future<void> initialize();

  Future<GoogleAccountInfo?> attemptLightweightAuthentication();

  Future<GoogleAccountInfo> authenticate({required List<String> scopeHint});

  Future<void> signOut();
}

class GoogleSignInAccountGateway implements GoogleAccountGateway {
  GoogleSignInAccountGateway({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  @override
  Future<void> initialize() => _googleSignIn.initialize();

  @override
  Future<GoogleAccountInfo?> attemptLightweightAuthentication() async {
    final account = await _googleSignIn.attemptLightweightAuthentication();
    return account == null ? null : _fromAccount(account);
  }

  @override
  Future<GoogleAccountInfo> authenticate({
    required List<String> scopeHint,
  }) async {
    final account = await _googleSignIn.authenticate(scopeHint: scopeHint);
    return _fromAccount(account);
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();

  static GoogleAccountInfo _fromAccount(GoogleSignInAccount account) {
    return GoogleAccountInfo(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }
}
