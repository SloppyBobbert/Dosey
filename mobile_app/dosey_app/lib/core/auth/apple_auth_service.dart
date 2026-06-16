import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:flutter/services.dart';

class AppleAuthService {
  AppleAuthService(this._localAuth, {AppleAccountGateway? appleAccountGateway})
    : _appleAccountGateway = appleAccountGateway ?? AppleSignInAccountGateway();

  final LocalAuthRepository _localAuth;
  final AppleAccountGateway _appleAccountGateway;

  Stream<AuthSession> watchSession() => _localAuth.watchSession();

  Future<AuthSession> signInWithApple() async {
    final account = await _appleAccountGateway.signIn();
    final user = await _toAuthUser(account);
    await _localAuth.saveUser(user);
    return AuthSession.signedIn(user);
  }

  Future<void> signOut() async {
    try {
      await _appleAccountGateway.signOut();
    } finally {
      await _localAuth.clearUser();
    }
  }

  Future<AuthUser> _toAuthUser(AppleAccountInfo account) async {
    final email = account.email ?? await _restoreCachedEmail(account.id);
    if (email == null) {
      throw StateError('Apple sign-in did not provide an email for this user.');
    }

    return account.toAuthUser(email: email);
  }

  Future<String?> _restoreCachedEmail(String userId) async {
    final cachedUser = await _localAuth.readCurrentUser();
    if (cachedUser?.provider != AuthProvider.apple ||
        cachedUser?.id != userId) {
      return _localAuth.readAppleEmail(userId);
    }

    return cachedUser?.email ?? _localAuth.readAppleEmail(userId);
  }
}

class AppleAccountInfo {
  const AppleAccountInfo({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;

  AuthUser toAuthUser({required String email}) {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: null,
      provider: AuthProvider.apple,
    );
  }
}

abstract interface class AppleAccountGateway {
  Future<AppleAccountInfo> signIn();

  Future<void> signOut();
}

class AppleSignInAccountGateway implements AppleAccountGateway {
  const AppleSignInAccountGateway({
    this.channel = const MethodChannel(_channelName),
  });

  static const _channelName = 'com.sloppybobbert.dosey_app/apple_auth';

  final MethodChannel channel;

  @override
  Future<AppleAccountInfo> signIn() async {
    final credential = await channel.invokeMapMethod<String, Object?>('signIn');
    if (credential == null) {
      throw StateError('Apple sign-in did not return credentials.');
    }

    final id = credential['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Apple sign-in did not return a user identifier.');
    }

    return AppleAccountInfo(
      id: id,
      email: credential['email'] as String?,
      displayName: credential['displayName'] as String?,
    );
  }

  @override
  Future<void> signOut() async {}
}
