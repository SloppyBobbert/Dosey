class CloudIdentity {
  const CloudIdentity._({this.accountId, this.email, this.displayName});

  const CloudIdentity.signedOut() : this._();

  const CloudIdentity.signedIn({
    required String accountId,
    required String email,
    String? displayName,
  }) : this._(accountId: accountId, email: email, displayName: displayName);

  final String? accountId;
  final String? email;
  final String? displayName;

  bool get isSignedIn => accountId != null;

  @override
  bool operator ==(Object other) {
    return other is CloudIdentity &&
        other.accountId == accountId &&
        other.email == email &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(accountId, email, displayName);
}

class CloudNotConfiguredException implements Exception {
  const CloudNotConfiguredException();

  @override
  String toString() =>
      'CloudNotConfiguredException: Appwrite is not configured.';
}

abstract interface class CloudIdentityGateway {
  // Keep account consumers on this provider-neutral contract. A backend switch
  // should replace its adapter rather than leak SDK account models into UI code.
  Stream<CloudIdentity> watchIdentity();

  Future<CloudIdentity> signInWithGoogle({List<String> scopes = const []});

  Future<void> signOut();
}

class DisabledCloudIdentityGateway implements CloudIdentityGateway {
  const DisabledCloudIdentityGateway();

  @override
  Stream<CloudIdentity> watchIdentity() =>
      Stream.value(const CloudIdentity.signedOut());

  @override
  Future<CloudIdentity> signInWithGoogle({List<String> scopes = const []}) =>
      Future.error(const CloudNotConfiguredException());

  @override
  Future<void> signOut() async {}
}
