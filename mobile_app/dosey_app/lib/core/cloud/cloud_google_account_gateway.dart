import 'package:dosey_app/core/auth/google_auth_service.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';

class CloudGoogleAccountGateway implements GoogleAccountGateway {
  CloudGoogleAccountGateway(this._cloudIdentity);

  final CloudIdentityGateway _cloudIdentity;

  @override
  Future<void> initialize() async {}

  @override
  Future<GoogleAccountInfo?> attemptLightweightAuthentication() async {
    return _toGoogleAccountInfo(await _cloudIdentity.watchIdentity().first);
  }

  @override
  Future<GoogleAccountInfo> authenticate({
    required List<String> scopeHint,
  }) async {
    final identity = await _cloudIdentity.signInWithGoogle();
    return _toGoogleAccountInfo(identity) ??
        (throw StateError('Cloud sign-in returned a signed-out identity.'));
  }

  @override
  Future<void> signOut() => _cloudIdentity.signOut();

  // This is the only translation needed by the existing local auth cache. A
  // future provider adapter can return the same Dosey identity unchanged.
  static GoogleAccountInfo? _toGoogleAccountInfo(CloudIdentity identity) {
    if (!identity.isSignedIn) {
      return null;
    }
    return GoogleAccountInfo(
      id: identity.accountId!,
      email: identity.email!,
      displayName: identity.displayName,
      photoUrl: null,
    );
  }
}
