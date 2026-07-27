import 'package:dosey_app/app/web/dosey_web_app.dart';
import 'package:dosey_app/app/web/dosey_web_dependencies.dart';
import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = WebAuthConfiguration.fromEnvironment;
  final cloudConfiguration = CloudConfiguration.fromValues(
    endpoint: config.endpoint,
    projectId: config.projectId,
  );
  final identity = createWebCloudIdentityGateway(cloudConfiguration);
  runApp(
    DoseyWebApp(
      dependencies: DoseyWebDependencies(identity: identity, config: config),
    ),
  );
}
