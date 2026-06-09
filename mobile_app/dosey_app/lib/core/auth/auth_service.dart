enum AuthProvider { google }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.provider,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final AuthProvider provider;

  @override
  bool operator ==(Object other) {
    return other is AuthUser &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.provider == provider;
  }

  @override
  int get hashCode => Object.hash(id, email, displayName, photoUrl, provider);
}

class AuthSession {
  const AuthSession._(this.user);

  const AuthSession.signedOut() : this._(null);

  const AuthSession.signedIn(AuthUser user) : this._(user);

  final AuthUser? user;

  bool get isSignedIn => user != null;
}

abstract interface class AuthService {
  Stream<AuthSession> watchSession();

  Future<AuthSession> signInWithGoogle();

  Future<void> signOut();
}
