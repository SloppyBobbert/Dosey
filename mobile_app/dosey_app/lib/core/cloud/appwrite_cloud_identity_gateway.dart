import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';

abstract interface class AppwriteAccountApi {
  // This narrow SDK-facing seam keeps Appwrite models and exceptions contained
  // in this file and makes the Dosey gateway testable without network calls.
  Future<CloudIdentity?> getCurrentIdentity();

  Future<void> signInWithGoogle({
    required List<String> scopes,
    String? successUrl,
    String? failureUrl,
  });

  Future<String> requestEmailOtp(String email) =>
      Future.error(UnimplementedError());

  Future<void> completeEmailOtp({
    required String userId,
    required String secret,
  }) => Future.error(UnimplementedError());

  Future<void> signOutCurrentSession();
}

class AppwriteAccountApiAdapter implements AppwriteAccountApi {
  AppwriteAccountApiAdapter(Account account) : _account = account;

  final Account _account;

  @override
  Future<CloudIdentity?> getCurrentIdentity() async {
    try {
      return _toCloudIdentity(await _account.get());
    } on AppwriteException catch (error) {
      if (error.code == 401) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithGoogle({
    required List<String> scopes,
    String? successUrl,
    String? failureUrl,
  }) => _account.createOAuth2Session(
    provider: OAuthProvider.google,
    scopes: scopes,
    success: successUrl,
    failure: failureUrl,
  );

  @override
  Future<String> requestEmailOtp(String email) async {
    final token = await _account.createEmailToken(
      userId: ID.unique(),
      email: email,
      phrase: false,
    );
    return token.userId;
  }

  @override
  Future<void> completeEmailOtp({
    required String userId,
    required String secret,
  }) async {
    await _account.createSession(userId: userId, secret: secret);
  }

  @override
  Future<void> signOutCurrentSession() =>
      _account.deleteSession(sessionId: 'current');

  static CloudIdentity _toCloudIdentity(models.User user) {
    return CloudIdentity.signedIn(
      accountId: user.$id,
      email: user.email,
      displayName: user.name.trim().isEmpty ? null : user.name.trim(),
    );
  }
}

class AppwriteCloudIdentityGateway implements CloudIdentityGateway {
  AppwriteCloudIdentityGateway(this._account);

  final AppwriteAccountApi _account;
  final StreamController<CloudIdentity> _changes =
      StreamController<CloudIdentity>.broadcast();
  var _revision = 0;

  @override
  Stream<CloudIdentity> watchIdentity() {
    return Stream.multi((listener) {
      final startingRevision = _revision;
      final subscription = _changes.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = subscription.cancel;

      unawaited(() async {
        try {
          final restored =
              await _account.getCurrentIdentity() ??
              const CloudIdentity.signedOut();
          // A sign-in or sign-out that finished during restoration is newer.
          if (_revision == startingRevision) {
            listener.add(restored);
          }
        } catch (error, stackTrace) {
          if (_revision == startingRevision) {
            listener.addError(error, stackTrace);
          }
        }
      }());
    });
  }

  @override
  Future<CloudIdentity> signInWithGoogle({
    List<String> scopes = const [],
    String? successUrl,
    String? failureUrl,
  }) async {
    await _account.signInWithGoogle(
      scopes: scopes,
      successUrl: successUrl,
      failureUrl: failureUrl,
    );
    return _publishCurrentIdentity(
      'Appwrite Google sign-in did not create a session.',
    );
  }

  @override
  Future<String> requestEmailOtp(String email) =>
      _account.requestEmailOtp(email.trim().toLowerCase());

  @override
  Future<CloudIdentity> completeEmailOtp({
    required String userId,
    required String secret,
  }) async {
    await _account.completeEmailOtp(userId: userId, secret: secret);
    return _publishCurrentIdentity(
      'Appwrite email OTP sign-in did not create a session.',
    );
  }

  Future<CloudIdentity> _publishCurrentIdentity(String errorMessage) async {
    final identity = await _account.getCurrentIdentity();
    if (identity == null) {
      throw StateError(errorMessage);
    }
    _publish(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    await _account.signOutCurrentSession();
    _publish(const CloudIdentity.signedOut());
  }

  void _publish(CloudIdentity identity) {
    _revision += 1;
    _changes.add(identity);
  }
}
