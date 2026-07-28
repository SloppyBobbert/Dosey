import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';

class FakeCloudIdentityGateway implements CloudIdentityGateway {
  FakeCloudIdentityGateway({
    this.identity = const CloudIdentity.signedOut(),
    this.signInResult = const CloudIdentity.signedIn(
      accountId: 'owner-1',
      email: 'owner@example.com',
    ),
  });

  final CloudIdentity identity;
  final CloudIdentity signInResult;
  var signInCount = 0;
  var signOutCount = 0;
  List<String>? lastScopes;

  @override
  Future<CloudIdentity> signInWithGoogle({
    List<String> scopes = const [],
    String? successUrl,
    String? failureUrl,
  }) async {
    signInCount += 1;
    lastScopes = scopes;
    return signInResult;
  }

  @override
  Future<String> requestEmailOtp(String email) =>
      Future.error(UnimplementedError());

  @override
  Future<CloudIdentity> completeEmailOtp({
    required String userId,
    required String secret,
  }) => Future.error(UnimplementedError());

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  Stream<CloudIdentity> watchIdentity() => Stream.value(identity);
}
