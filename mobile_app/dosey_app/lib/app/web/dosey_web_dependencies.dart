import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';

import 'web_auth_configuration.dart';

class DoseyWebDependencies {
  const DoseyWebDependencies({required this.identity, required this.config});

  final CloudIdentityGateway identity;
  final WebAuthConfiguration config;
}
